#!/bin/bash
# Benchmark: Range query without index on AQuery.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load_script="$SCRIPT_DIR/load_employees.q"
query_script="$SCRIPT_DIR/aquery/noindex.q"
output_csv_name="aquery_range_noindex.csv"

bash "$SCRIPT_DIR/../base_aquery.sh" \
  "$load_script" \
  "$output_csv_name" \
  "${query_script}:range_no_index"
