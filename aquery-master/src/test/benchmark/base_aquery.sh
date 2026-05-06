#!/bin/bash
# Run one or more pre-translated AQuery q scripts, including table-load time, 11 repetitions each.
# Uses `script` to allocate a pseudo-tty for q, which is more reliable on this environment.
# Usage:
#   bash base_aquery.sh load_script.q output_csv query1.q[:label1] [query2.q[:label2] ...]
# Example:
#   bash base_aquery.sh ./load_tpch_small.q aquery_results.csv \
#     ../function_support/retrieve_need_col/retrieve_a.q:"All Columns"

set -euo pipefail
TIMEFORMAT='%R %U %S'
ITERATIONS=11

if [[ $# -lt 3 ]]; then
  echo "Usage: bash base_aquery.sh load_script.q output_csv query1.q[:label1] [query2.q[:label2] ...]"
  exit 1
fi

LOAD_SCRIPT="$1"      # q script that loads .tbl/.csv data into the same q session
OUT_CSV="$2"          # CSV output file name
shift 2
Q_BIN="${Q_BIN:-q}"   # q executable, can be overridden with env var
SCRIPT_BIN="${SCRIPT_BIN:-script}"

pad0() {
  local val="$1"
  if [[ "$val" =~ ^\.[0-9] ]]; then
    echo "0$val"
  else
    echo "$val"
  fi
}

RESULTS_DIR="./results"
mkdir -p "$RESULTS_DIR"
RESULTS_FILE="$RESULTS_DIR/$OUT_CSV"

if [[ ! -f "$RESULTS_FILE" ]]; then
  echo "dbms,label,iteration,execution_time,response_time" > "$RESULTS_FILE"
fi

if [[ ! -f "$LOAD_SCRIPT" ]]; then
  echo "Error: load script not found: $LOAD_SCRIPT"
  exit 1
fi

if ! command -v "$Q_BIN" >/dev/null 2>&1; then
  echo "Error: q executable not found: $Q_BIN"
  exit 1
fi

if ! command -v "$SCRIPT_BIN" >/dev/null 2>&1; then
  echo "Error: script executable not found: $SCRIPT_BIN"
  exit 1
fi

run_query_file() {
  local query_script="$1"
  local label="$2"

  if [[ ! -f "$query_script" ]]; then
    echo "Error: query script not found: $query_script"
    exit 1
  fi

  echo "AQUERY QUERY STARTED"
  echo "Load Script: $LOAD_SCRIPT"
  echo "Query Script: $query_script"
  echo "Label: $label"
  echo "Execution Time      Response Time"

  for i in $(seq 1 "$ITERATIONS"); do
    RUNNER_FILE="$(mktemp "/tmp/aquery_bench_${i}_XXXXXX")"
    RUNNER_Q_FILE="${RUNNER_FILE}.q"
    mv "$RUNNER_FILE" "$RUNNER_Q_FILE"
    RUNNER_FILE="$RUNNER_Q_FILE"
    STDOUT_LOG="${RUNNER_FILE}.stdout.log"
    STDERR_LOG="${RUNNER_FILE}.stderr.log"

    cleanup() {
      rm -f "$RUNNER_FILE" "$STDOUT_LOG" "$STDERR_LOG"
    }
    trap cleanup EXIT

    printf '\\l %s\n\\l %s\nexit 0\n' "$LOAD_SCRIPT" "$query_script" > "$RUNNER_FILE"

    { time "$SCRIPT_BIN" -q /dev/null "$Q_BIN" < "$RUNNER_FILE" > "$STDOUT_LOG"; } 2> "$STDERR_LOG"

    if [ $? -ne 0 ]; then
      echo "Error: q execution failed."
      echo "--- q stdout ---"
      cat "$STDOUT_LOG" || true
      echo "--- q stderr ---"
      cat "$STDERR_LOG" || true
      exit 1
    fi

    TIME_LINE=$(grep -E '^[0-9.]+ +[0-9.]+ +[0-9.]+' "$STDERR_LOG" | tail -n 1 || true)
    if [ -z "$TIME_LINE" ]; then
      echo "Error: no timing information found in stderr log"
      echo "--- q stdout ---"
      cat "$STDOUT_LOG" || true
      echo "--- q stderr ---"
      cat "$STDERR_LOG" || true
      exit 1
    fi

    read REAL_TIME USER_TIME SYS_TIME <<< "$TIME_LINE"

    REAL_TIME=$(printf "%.6f" "$REAL_TIME")
    USER_TIME=$(printf "%.6f" "$USER_TIME")
    SYS_TIME=$(printf "%.6f" "$SYS_TIME")
    EXECUTION_TIME=$(echo "scale=6; $USER_TIME + $SYS_TIME" | bc)

    REAL_TIME=$(pad0 "$REAL_TIME")
    EXECUTION_TIME=$(pad0 "$EXECUTION_TIME")

    echo "ran aquery ${i}"
    echo "${EXECUTION_TIME}            ${REAL_TIME}"
    echo "aquery,${label},${i},${EXECUTION_TIME},${REAL_TIME}" >> "$RESULTS_FILE"

    cleanup
    trap - EXIT
  done

  echo "AQUERY QUERY DONE"
}

for spec in "$@"; do
  if [[ "$spec" == *:* ]]; then
    query_path="${spec%%:*}"
    query_label="${spec#*:}"
  else
    query_path="$spec"
    query_label="$(basename "$spec")"
  fi
  run_query_file "$query_path" "$query_label"
done

echo "Results saved to: $RESULTS_FILE"
