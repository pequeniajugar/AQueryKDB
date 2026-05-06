#!/bin/bash
# Run a single SQL query against DuckDB, 11 repetitions with timing
# Usage:   bash base_duckdb.sh database_path "query with {v1} and/or {v2}" [optional_label] [optional_output_csv]
# Example: bash base_duckdb.sh /data/tw3090/duckdb/account_new_7 \
#   "SELECT * FROM account1 WHERE ssnum BETWEEN {v1} AND {v2};" label1 duckdb_output.csv

set -euo pipefail
TIMEFORMAT='%R %U %S'

DUCKDB_DB="$1"         # DuckDB database file path
QUERY="$2"             # SQL query template (may include {v1}, {v2})
LABEL="${3-}"          # Optional label for CSV output
OUT_CSV="${4-}"        # Optional CSV output file name

# Function: prepend 0 if the number starts with a dot (e.g. .123456 -> 0.123456)
pad0() {
  local val="$1"
  if [[ "$val" =~ ^\.[0-9] ]]; then
    echo "0$val"
  else
    echo "$val"
  fi
}

# Prepare output directory and CSV file
RESULTS_DIR="./results"
mkdir -p "$RESULTS_DIR"
if [[ -n "$OUT_CSV" ]]; then
  RESULTS_FILE="$RESULTS_DIR/$OUT_CSV"
else
  RESULTS_FILE="$RESULTS_DIR/duckdb_results.csv"
fi

# Write CSV header if the file does not exist yet
if [[ ! -f "$RESULTS_FILE" ]]; then
  echo "dbms,label,iteration,execution_time,response_time" > "$RESULTS_FILE"
fi

echo "DUCKDB QUERY STARTED"
echo "DuckDB database: $DUCKDB_DB"
if [[ -n "$LABEL" ]]; then
  echo "Query File: $LABEL"
else
  echo "Query Template: $QUERY"
fi
echo "Execution Time      Response Time"

# --- Initial value for v1 ---
value1=150

for i in $(seq 1 11); do
  value2=$((value1 + 1000))

  # Replace placeholders {v1} and {v2}
  CURRENT_QUERY="${QUERY//\{v1\}/$value1}"
  CURRENT_QUERY="${CURRENT_QUERY//\{v2\}/$value2}"

  # Use built-in `time` to capture real/user/sys time
  { time duckdb "$DUCKDB_DB" -c "$CURRENT_QUERY" > /dev/null; } 2> duckdb_time_output.log
  #{ time duckdb "$DUCKDB_DB" -c "$CURRENT_QUERY" ; } 2> duckdb_time_output.log

  # If DuckDB failed, print error and exit
  if [ $? -ne 0 ]; then
    echo "Error: DuckDB command failed."
    cat duckdb_time_output.log
    rm -f duckdb_time_output.log
    exit 1
  fi

  # Extract timing information
  TIME_LINE=$(grep -E '^[0-9.]+ +[0-9.]+ +[0-9.]+' duckdb_time_output.log | tail -n 1)
  if [ -z "$TIME_LINE" ]; then
    echo "Error: no timing information found in duckdb_time_output.log"
    rm -f duckdb_time_output.log
    exit 1
  fi

  read REAL_TIME USER_TIME SYS_TIME <<< "$TIME_LINE"

  # Format numbers to 6 decimal places
  REAL_TIME=$(printf "%.6f" "$REAL_TIME")
  USER_TIME=$(printf "%.6f" "$USER_TIME")
  SYS_TIME=$(printf "%.6f" "$SYS_TIME")

  # Calculate execution time as user+sys
  EXECUTION_TIME=$(echo "scale=6; $USER_TIME + $SYS_TIME" | bc)

  # Add leading zero if missing
  REAL_TIME=$(pad0 "$REAL_TIME")
  EXECUTION_TIME=$(pad0 "$EXECUTION_TIME")

  echo "ran duckdb ${i}"
  echo "${EXECUTION_TIME}            ${REAL_TIME}"

  # Append result to CSV
  if [[ -n "$LABEL" ]]; then
    echo "duckdb,${LABEL},${i},${EXECUTION_TIME},${REAL_TIME}" >> "$RESULTS_FILE"
  else
    echo "duckdb,${CURRENT_QUERY},${i},${EXECUTION_TIME},${REAL_TIME}" >> "$RESULTS_FILE"
  fi

  rm -f duckdb_time_output.log

  # Increment v1 for next run
  value1=$((value1 + 1))
done

echo "DUCKDB QUERY DONE"
echo "Results saved to: $RESULTS_FILE"