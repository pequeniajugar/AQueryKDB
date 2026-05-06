#!/bin/bash
# Run select-all benchmark for AQuery version 2 using pre-materialized local q data.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

local_load_script="${SCRIPT_DIR}/load_aqueryver2_local.q"
query_script="${SCRIPT_DIR}/../aquery/all.q"
output_csv_name="aqueryver2_small_select_all.csv"

bash "${SCRIPT_DIR}/../../base_aqueryver2.sh" \
  "$local_load_script" \
  "$output_csv_name" \
  "${query_script}:All Columns"
