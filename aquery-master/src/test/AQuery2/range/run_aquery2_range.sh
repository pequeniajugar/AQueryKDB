#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load_script="${SCRIPT_DIR}/load_employees.a"
query_script="${SCRIPT_DIR}/range.a"
output_csv_name="aquery2_range_noindex.csv"

AQUERY_CONTAINER="${AQUERY_CONTAINER:-aquery2_bench}"
AQUERY_DIR="${AQUERY_DIR:-/AQuery2}"
RUNS="${RUNS:-11}"

AQUERY_CONTAINER="$AQUERY_CONTAINER" \
AQUERY_DIR="$AQUERY_DIR" \
RUNS="$RUNS" \
bash "${SCRIPT_DIR}/../base_aquery2_docker.sh" \
  "$load_script" \
  "$output_csv_name" \
  "${query_script}:RangeNoIndex"
