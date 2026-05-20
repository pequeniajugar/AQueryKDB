#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   AQUERY_CONTAINER=aquery2_bench bash base_aquery2_docker.sh \
#     <load_script.a> <output_csv> <query_script.a:Label> [query_script.a:Label ...]
#
# Example:
#   AQUERY_CONTAINER=aquery2_bench bash base_aquery2_docker.sh \
#     src/test/benchmark/select_all/load_tpch_small.a \
#     aquery_small_select_all.csv \
#     src/test/benchmark/select_all/aquery/all.a:AllColumns

if [ "$#" -lt 3 ]; then
  echo "Usage: AQUERY_CONTAINER=<container> bash $0 <load_script> <output_csv> <query_script:label> [query_script:label ...]"
  exit 1
fi

AQUERY_CONTAINER="${AQUERY_CONTAINER:-aquery2_bench}"
AQUERY_DIR="${AQUERY_DIR:-/AQuery2}"
RUNS="${RUNS:-11}"
AQUERY2_DATA_FILE="${AQUERY2_DATA_FILE:-}"

require_container_running() {
  local state
  if ! state="$(docker inspect -f '{{.State.Running}}' "$AQUERY_CONTAINER" 2>/dev/null)"; then
    echo "Error: Docker container '$AQUERY_CONTAINER' does not exist or Docker is not reachable."
    echo "Start the AQuery2 container, then rerun this benchmark."
    exit 1
  fi

  if [[ "$state" != "true" ]]; then
    echo "Error: Docker container '$AQUERY_CONTAINER' is not running."
    echo "Start it with: docker start $AQUERY_CONTAINER"
    exit 1
  fi
}

load_script="$1"
output_csv_name="$2"
shift 2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_DIR="${SCRIPT_DIR}/results"
mkdir -p "$RESULT_DIR"

output_csv="${RESULT_DIR}/${output_csv_name}"
log_dir="${RESULT_DIR}/aquery2_logs"
mkdir -p "$log_dir"

echo "label,run,response_time" > "$output_csv"

echo "AQUERY2 BENCHMARK STARTED"
echo "Container: $AQUERY_CONTAINER"
echo "AQuery dir in container: $AQUERY_DIR"
echo "Load Script: $load_script"
if [[ -n "$AQUERY2_DATA_FILE" ]]; then
  echo "Data File: $AQUERY2_DATA_FILE"
fi
echo "Output CSV: $output_csv"
echo

require_container_running

container_data_file=""
load_rewrite_args=()
if [[ -n "$AQUERY2_DATA_FILE" ]]; then
  if [[ ! -f "$AQUERY2_DATA_FILE" ]]; then
    echo "Error: AQUERY2_DATA_FILE not found: $AQUERY2_DATA_FILE"
    exit 1
  fi
  container_data_file="/tmp/$(basename "$AQUERY2_DATA_FILE")"
  docker cp "$AQUERY2_DATA_FILE" "${AQUERY_CONTAINER}:${container_data_file}"
else
  while IFS= read -r data_file; do
    if [[ -z "$data_file" ]]; then
      continue
    fi
    if [[ ! -f "$data_file" ]]; then
      echo "Error: LOAD DATA file not found: $data_file"
      exit 1
    fi
    container_path="/tmp/$(basename "$data_file")"
    echo "Data File: $data_file"
    docker cp "$data_file" "${AQUERY_CONTAINER}:${container_path}"
    load_rewrite_args+=("$data_file" "$container_path")
  done < <(python3 - "$load_script" <<'PY'
import re
import sys
from pathlib import Path

src = Path(sys.argv[1]).read_text()
for path in re.findall(r'LOAD DATA INFILE\s+"([^"]+)"', src):
    print(path)
PY
  )
fi

for spec in "$@"; do
  query_script="${spec%%:*}"
  label="${spec#*:}"

  echo "AQUERY QUERY STARTED"
  echo "Query Script: $query_script"
  echo "Label: $label"
  echo "Response Time"

  for i in $(seq 1 "$RUNS"); do
    tmp_host="$(mktemp "/tmp/aquery2_${label}_${i}_XXXXXX")"
    tmp_load_host="$(mktemp "/tmp/aquery2_${label}_${i}_load_XXXXXX")"
    tmp_container="/tmp/aquery2_${label}_${i}"
    log_file="${log_dir}/${label}_run_${i}.log"

    # Combine load script and query script.
    # Both files should contain exec after each AQuery statement.
    if [[ -n "$container_data_file" ]]; then
      python3 - "$load_script" "$tmp_load_host" "$container_data_file" <<'PY'
import re
import sys
from pathlib import Path

src = Path(sys.argv[1]).read_text()
dst = Path(sys.argv[2])
container_path = sys.argv[3]
src = re.sub(r'LOAD DATA INFILE\s+"[^"]+"', f'LOAD DATA INFILE "{container_path}"', src)
dst.write_text(src)
PY
      cat "$tmp_load_host" "$query_script" > "$tmp_host"
    elif [[ "${#load_rewrite_args[@]}" -gt 0 ]]; then
      python3 - "$load_script" "$tmp_load_host" "${load_rewrite_args[@]}" <<'PY'
import sys
from pathlib import Path

src = Path(sys.argv[1]).read_text()
dst = Path(sys.argv[2])
args = sys.argv[3:]

for host_path, container_path in zip(args[0::2], args[1::2]):
    src = src.replace(
        f'LOAD DATA INFILE "{host_path}"',
        f'LOAD DATA INFILE "{container_path}"',
    )

dst.write_text(src)
PY
      cat "$tmp_load_host" "$query_script" > "$tmp_host"
    else
      cat "$load_script" "$query_script" > "$tmp_host"
    fi

    docker cp "$tmp_host" "${AQUERY_CONTAINER}:${tmp_container}"

    echo "ran aquery $i"

    # Run AQuery2 inside Docker and measure only inside the container.
    # Output is saved to a log file for debugging.
    if ! docker exec "$AQUERY_CONTAINER" bash -lc \
      "cd '$AQUERY_DIR' && python3 - '$tmp_container' <<'PY'
import subprocess
import sys
import time

script = sys.argv[1]
start = time.perf_counter()
proc = subprocess.run(
    ['python3', 'prompt.py'],
    stdin=open(script),
    text=True,
)
end = time.perf_counter()
print(f'AQUERY2_TIME|{end - start:.6f}')
sys.exit(proc.returncode)
PY" \
      > "$log_file" 2>&1; then
      echo "Error: AQuery2 run failed for label '$label', run $i."
      echo "Log: $log_file"
      cat "$log_file"
      exit 1
    fi

    response_time="$(grep -a 'AQUERY2_TIME|' "$log_file" | tail -n 1 | sed 's/^.*AQUERY2_TIME|//')"
    if [[ -z "$response_time" ]]; then
      echo "Error: did not find in-container timing marker in $log_file"
      cat "$log_file"
      exit 1
    fi

    echo "$response_time"
    echo "${label},${i},${response_time}" >> "$output_csv"

    rm -f "$tmp_host" "$tmp_load_host"
    docker exec "$AQUERY_CONTAINER" rm -f "$tmp_container" >/dev/null 2>&1 || true
  done

  echo "AQUERY QUERY DONE"
  echo
done

echo "Results saved to: $output_csv"
echo

echo "Median response time excluding first run:"
python3 - <<PY
import csv
from statistics import median
from collections import defaultdict

path = "$output_csv"
vals = defaultdict(list)

with open(path, newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        run = int(row["run"])
        if run == 1:
            continue
        vals[row["label"]].append(float(row["response_time"]))

for label, xs in vals.items():
    print(f"{label}: {median(xs):.6f}")
PY
