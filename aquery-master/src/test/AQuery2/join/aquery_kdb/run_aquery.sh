#!/bin/bash
# Benchmark: two-way TPCH join on AQuery/kdb+.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

Q_BIN="${Q_BIN:-/Users/tianxin/q/m64/q}"
output_csv_name="aquery_kdb_two_way_join.csv"

load_q="$SCRIPT_DIR/load_tpch_join.q"
query_q="$SCRIPT_DIR/two_way_join.q"
base_runner="$REPO_ROOT/src/test/benchmark/base_aquery.sh"

require_file() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    echo "Error: required file is missing or empty: $path"
    exit 1
  fi
}

echo "=== AQuery/kdb+ Two-Way Join Benchmark ==="
echo "Load script: $load_q"
echo "Query script: $query_q"
echo "Output CSV: $REPO_ROOT/results/$output_csv_name"

require_file "$load_q"
require_file "$query_q"
require_file "$base_runner"

mkdir -p "$REPO_ROOT/results"
rm -f "$REPO_ROOT/results/$output_csv_name"

cd "$REPO_ROOT"

Q_BIN="$Q_BIN" bash "$base_runner" \
  "$load_q" \
  "$output_csv_name" \
  "$query_q:two_way_join"

echo "AQuery/kdb+ two-way join benchmark finished. Results saved to: ./results/$output_csv_name"
