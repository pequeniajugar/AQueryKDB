#!/bin/bash
# Run a single SQL query against PostgreSQL, 11 repetitions with timing
# Usage:   bash base_postgres.sh database_name "query with {v1} and/or {v2}" [optional_label] [optional_output_csv] [optional_session_setup_sql]
# Example: bash base_postgres.sh account_new_7 \
#   "SELECT * FROM account1 WHERE hundreds1 BETWEEN {v1} AND {v2};" label1 postgres_output.csv

set -euo pipefail
TIMEFORMAT='%R %U %S'

# --- PostgreSQL Connection settings ---
PGUSER="${PGUSER:-tianxin}"
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PSQL_BIN="${PSQL_BIN:-$(command -v psql)}"

# --------------------------------------

PG_DB="$1"         # PostgreSQL database name
QUERY="$2"         # SQL query template (may include {v1}, {v2})
LABEL="${3-}"      # Optional label for CSV output
OUT_CSV="${4-}"    # Optional CSV file name
SESSION_SETUP="${5-}"  # Optional SQL to run in the same session before each timed query

# Function: prepend 0 if value starts with a dot (e.g., .123456 -> 0.123456)
pad0() {
  local val="$1"
  if [[ "$val" =~ ^\.[0-9] ]]; then
    echo "0$val"
  else
    echo "$val"
  fi
}

# Prepare output directory and result CSV
RESULTS_DIR="./results"
mkdir -p "$RESULTS_DIR"
if [[ -n "$OUT_CSV" ]]; then
  RESULTS_FILE="$RESULTS_DIR/$OUT_CSV"
else
  RESULTS_FILE="$RESULTS_DIR/postgres_results.csv"
fi

# Write CSV header if needed
if [[ ! -f "$RESULTS_FILE" ]]; then
  echo "dbms,label,iteration,execution_time,response_time" > "$RESULTS_FILE"
fi

if [[ -z "${PSQL_BIN:-}" || ! -x "$PSQL_BIN" ]]; then
  echo "Error: psql executable not found. Set PSQL_BIN or ensure psql is on PATH."
  exit 1
fi

echo "POSTGRES QUERY STARTED"
echo "PostgreSQL database: $PG_DB"
if [[ -n "$LABEL" ]]; then
  echo "Query File: $LABEL"
else
  echo "Query Template: $QUERY"
fi
echo "Execution Time      Response Time"

# Initial value for v1
value1=800

for i in $(seq 1 11); do
  value2=$((value1 + 1000))

  # Replace placeholders {v1} and {v2}
  CURRENT_QUERY="${QUERY//\{v1\}/$value1}"
  CURRENT_QUERY="${CURRENT_QUERY//\{v2\}/$value2}"
  SESSION_QUERY="${SESSION_SETUP}${CURRENT_QUERY}"

  # Time the execution
  set +e
  { time "$PSQL_BIN" \
      -U "$PGUSER" \
      -h "$PGHOST" \
      -p "$PGPORT" \
      -d "$PG_DB" \
      -c "$SESSION_QUERY" > /dev/null; } 2> postgres_time_output.log
  status=$?
  set -e

  # Error check
  if [ $status -ne 0 ]; then
    echo "Error: psql execution failed"
    cat postgres_time_output.log || true
    rm -f postgres_time_output.log
    exit 1
  fi

  # Parse time
  TIME_LINE=$(grep -E '^[0-9.]+ +[0-9.]+ +[0-9.]+' postgres_time_output.log | tail -n 1 || true)
  if [ -z "$TIME_LINE" ]; then
    echo "Error: no timing info found"
    rm -f postgres_time_output.log
    exit 1
  fi

  read REAL_TIME USER_TIME SYS_TIME <<< "$TIME_LINE"

  REAL_TIME=$(printf "%.6f" "$REAL_TIME")
  USER_TIME=$(printf "%.6f" "$USER_TIME")
  SYS_TIME=$(printf "%.6f" "$SYS_TIME")
  EXECUTION_TIME=$(echo "scale=6; $USER_TIME + $SYS_TIME" | bc)

  REAL_TIME=$(pad0 "$REAL_TIME")
  EXECUTION_TIME=$(pad0 "$EXECUTION_TIME")

  echo "ran postgres ${i}"
  echo "${EXECUTION_TIME}            ${REAL_TIME}"

  # Append to CSV
  if [[ -n "$LABEL" ]]; then
    echo "postgres,${LABEL},${i},${EXECUTION_TIME},${REAL_TIME}" >> "$RESULTS_FILE"
  else
    echo "postgres,${CURRENT_QUERY},${i},${EXECUTION_TIME},${REAL_TIME}" >> "$RESULTS_FILE"
  fi

  rm -f postgres_time_output.log

  # Increment values
  value1=$((value1 + 1))
done

echo "POSTGRES QUERY DONE"
echo "Results saved to: $RESULTS_FILE"
