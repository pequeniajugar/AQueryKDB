#!/bin/bash
# Benchmark: scan-can-win indexed columns vs scan columns on AQuery.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load_script="$SCRIPT_DIR/load_employees.q"
output_csv_name="aquery_scancanwin.csv"

bash "$SCRIPT_DIR/../base_aquery.sh" \
  "$load_script" \
  "$output_csv_name" \
  "$SCRIPT_DIR/aquery/onepercent_index.q:onepercent_index" \
  "$SCRIPT_DIR/aquery/onepercent_scan.q:onepercent_scan" \
  "$SCRIPT_DIR/aquery/fivepercent_index.q:fivepercent_index" \
  "$SCRIPT_DIR/aquery/fivepercent_scan.q:fivepercent_scan" \
  "$SCRIPT_DIR/aquery/tenpercent_index.q:tenpercent_index" \
  "$SCRIPT_DIR/aquery/tenpercent_scan.q:tenpercent_scan" \
  "$SCRIPT_DIR/aquery/twentypercent_index.q:twentypercent_index" \
  "$SCRIPT_DIR/aquery/twentypercent_scan.q:twentypercent_scan"
