#!/bin/bash
# Benchmark: Range query without index on DuckDB.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

duckdb_db="${DUCKDB_DB:-/Users/tianxin/projects/nyu/ms2/independent_study/duckdb/employeesindex10_7.duckdb}"
output_csv_name="duckdb_range_noindex.csv"

if [[ ! -f "$duckdb_db" ]]; then
  echo "DuckDB database not found: $duckdb_db"
  echo "Set DUCKDB_DB to your prepared DuckDB database path."
  exit 1
fi

echo "===== RANGE NO INDEX BENCHMARK ====="
bash "$SCRIPT_DIR/../base_duckdb.sh" \
  "$duckdb_db" \
  "SELECT * FROM employees WHERE lat BETWEEN {v1} AND {v2};" \
  "range_no_index" \
  "$output_csv_name"

echo "Benchmark finished. Results saved to: ./results/$output_csv_name"
