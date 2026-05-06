#!/bin/bash
# Run select-all benchmark for AQuery using one or more pre-translated q files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Update these paths for your environment.
load_script="${SCRIPT_DIR}/load_tpch_small.q"
query_script="${SCRIPT_DIR}/../../function_support/retrieve_need_col/retrieve_a.q"
output_csv_name="aquery_small_select_all.csv"

bash "${SCRIPT_DIR}/../base_aquery.sh" \
  "$load_script" \
  "$output_csv_name" \
  "${query_script}:All Columns"
