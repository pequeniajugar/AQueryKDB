#!/bin/bash
# Run retrieve-needed-columns experiments for DuckDB (small TPCH) using base_duckdb.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to DuckDB database file (change if needed)
duckdb_db="/Users/tianxin/projects/nyu/ms2/independent_study/duckdb/tpch10_7.duckdb"

# Output CSV file name (change if needed)
output_csv_name="duckdb_small_retrieve_needed_columns.csv"

# Fetch all columns
bash "${SCRIPT_DIR}/../base_duckdb.sh" \
  "$duckdb_db" \
  "SELECT * FROM lineitem;" \
  "All Columns" \
  "$output_csv_name"
