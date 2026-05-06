#!/bin/bash
# Benchmark: Multipoint queries with non-clustered index vs no index on DuckDB.
# Output goes into a CSV file via base_duckdb.sh with labels.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

duckdb_path="/Users/tianxin/projects/nyu/ms2/independent_study/duckdb/employeesmulti10_7.duckdb"  # change or set DUCKDB_DB
output_csv_name="duckdb_fraction_scan_win_multipoint.csv"
output_csv="./results/$output_csv_name"

mkdir -p "$(dirname "$output_csv")"
echo "dbms,label,iteration,execution_time,response_time" > "$output_csv"

values=(2)

run_fraction() {
  local column_indexed="$1"
  local column_scan="$2"
  local pct_label="$3"

  for val in "${values[@]}"; do
    # Non-clustered index query.
    bash "$SCRIPT_DIR/../base_duckdb.sh" \
      "$duckdb_path" \
      "SET index_scan_percentage = 1; SET index_scan_max_count = 15000000; SELECT * FROM scanwin_multipoint WHERE ${column_indexed} = ${val};" \
      "non-clustered_${pct_label}_${val}" \
      "$output_csv_name"

    # Scan query with no index.
    bash "$SCRIPT_DIR/../base_duckdb.sh" \
      "$duckdb_path" \
      "SELECT * FROM scanwin_multipoint WHERE ${column_scan} = ${val};" \
      "noindex_${pct_label}_${val}" \
      "$output_csv_name"
  done
}

run_fraction "onepercent1" "onepercent2" "1pct"
run_fraction "fivepercent1" "fivepercent2" "5pct"
run_fraction "tenpercent1" "tenpercent2" "10pct"
run_fraction "twentypercent1" "twentypercent2" "20pct"

echo "DuckDB multipoint fraction-scan benchmark finished. Results saved to: $output_csv"
