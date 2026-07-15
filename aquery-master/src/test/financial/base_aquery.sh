#!/bin/bash
# Run financial AQuery q scripts after loading data, or measure load-only time.
#
# Usage from aquery-master:
#   bash src/test/financial/base_aquery.sh
#   bash src/test/financial/base_aquery.sh src/test/financial/Q0.q:Q0 src/test/financial/Q1.q:Q1
#
# Environment:
#   Q_BIN=/path/to/q              Override q executable.
#   SCRIPT_BIN=/usr/bin/script    Override script executable.
#   ITERATIONS=11                 Override repetitions.

set -euo pipefail
TIMEFORMAT='%R %U %S'

ITERATIONS="${ITERATIONS:-11}"
Q_BIN="${Q_BIN:-q}"
SCRIPT_BIN="${SCRIPT_BIN:-script}"
RESULTS_DIR="./results"
LOAD_SCRIPT="load.q"
OUT_CSV="financial_aquery.csv"

if [[ $# -eq 0 ]]; then
  QUERY_SPECS=()
  QUERY_SPECS=("$@")
else
  QUERY_SPECS=("$@")
fi

pad0() {
  local val="$1"
  if [[ "$val" =~ ^\.[0-9] ]]; then
    echo "0$val"
  else
    echo "$val"
  fi
}

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

mkdir -p "$RESULTS_DIR"
RESULTS_FILE="$RESULTS_DIR/$OUT_CSV"

if [[ ! -f "$RESULTS_FILE" ]]; then
  echo "dbms,label,iteration,execution_time,response_time" > "$RESULTS_FILE"
fi

run_once() {
  local label="$1"
  local query_script="${2:-}"
  local iteration="$3"

  local runner_base runner_file stdout_log stderr_log
  runner_base="$(mktemp "/tmp/financial_aquery_${iteration}_XXXXXX")"
  runner_file="${runner_base}.q"
  mv "$runner_base" "$runner_file"
  stdout_log="${runner_file}.stdout.log"
  stderr_log="${runner_file}.stderr.log"

  cleanup() {
    rm -f "$runner_file" "$stdout_log" "$stderr_log"
  }
  trap cleanup EXIT

  if [[ -n "$query_script" ]]; then
    printf '\\l %s\n\\l %s\nexit 0\n' "$LOAD_SCRIPT" "$query_script" > "$runner_file"
  else
    printf '\\l %s\nexit 0\n' "$LOAD_SCRIPT" > "$runner_file"
  fi

  set +e
  { time "$SCRIPT_BIN" -q /dev/null "$Q_BIN" < "$runner_file" > "$stdout_log"; } 2> "$stderr_log"
  local q_status=$?
  set -e

  if [[ $q_status -ne 0 ]]; then
    echo "Error: q execution failed."
    echo "--- q stdout ---"
    cat "$stdout_log" || true
    echo "--- q stderr ---"
    cat "$stderr_log" || true
    exit 1
  fi

  local time_line real_time user_time sys_time execution_time
  time_line=$(grep -E '^[0-9.]+ +[0-9.]+ +[0-9.]+' "$stderr_log" | tail -n 1 || true)
  if [[ -z "$time_line" ]]; then
    echo "Error: no timing information found in stderr log"
    echo "--- q stdout ---"
    cat "$stdout_log" || true
    echo "--- q stderr ---"
    cat "$stderr_log" || true
    exit 1
  fi

  read real_time user_time sys_time <<< "$time_line"

  real_time=$(printf "%.6f" "$real_time")
  user_time=$(printf "%.6f" "$user_time")
  sys_time=$(printf "%.6f" "$sys_time")
  execution_time=$(echo "scale=6; $user_time + $sys_time" | bc)

  real_time=$(pad0 "$real_time")
  execution_time=$(pad0 "$execution_time")

  echo "ran aquery ${label} ${iteration}"
  echo "${execution_time}            ${real_time}"
  echo "aquery,${label},${iteration},${execution_time},${real_time}" >> "$RESULTS_FILE"

  cleanup
  trap - EXIT
}

run_label() {
  local label="$1"
  local query_script="${2:-}"

  echo "AQUERY FINANCIAL RUN STARTED"
  echo "Load Script: $LOAD_SCRIPT"
  if [[ -n "$query_script" ]]; then
    echo "Query Script: $query_script"
  else
    echo "Query Script: <load only>"
  fi
  echo "Label: $label"
  echo "Execution Time      Response Time"

  for i in $(seq 1 "$ITERATIONS"); do
    run_once "$label" "$query_script" "$i"
  done

  echo "AQUERY FINANCIAL RUN DONE"
}

if [[ ${#QUERY_SPECS[@]} -eq 0 ]]; then
  run_label "load_only"
else
  for spec in "${QUERY_SPECS[@]}"; do
    if [[ "$spec" == *:* ]]; then
      query_path="${spec%%:*}"
      query_label="${spec#*:}"
    else
      query_path="$spec"
      query_label="$(basename "$spec")"
    fi

    if [[ ! -f "$query_path" ]]; then
      echo "Error: query script not found: $query_path"
      exit 1
    fi

    run_label "$query_label" "$query_path"
  done
fi

echo "Results saved to: $RESULTS_FILE"
