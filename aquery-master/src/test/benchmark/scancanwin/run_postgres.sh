#!/bin/bash
# Benchmark: Multipoint queries with non-clustered index vs no index on PostgreSQL.
# Output goes into a CSV file via base_postgres.sh with labels.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

database_name="employeesmulti10_5"  # change if needed
output_csv_name="postgres_fraction_scan_win_multipoint.csv"
output_csv="./results/$output_csv_name"

mkdir -p "$(dirname "$output_csv")"
echo "dbms,label,iteration,execution_time,response_time" > "$output_csv"

values=(2)

run_fraction() {
  local column_indexed="$1"
  local column_scan="$2"
  local pct_label="$3"

  for val in "${values[@]}"; do
    # Non-clustered index query. Force the planner away from sequential scans
    # immediately before the timed query in the same PostgreSQL session.
    bash "$SCRIPT_DIR/../base_postgres.sh" \
      "$database_name" \
      "SET enable_seqscan TO off; SELECT * FROM scanwin_multipoint WHERE ${column_indexed} = ${val};" \
      "non-clustered_${pct_label}_${val}" \
      "$output_csv_name"

    # Scan query with no index.
    bash "$SCRIPT_DIR/../base_postgres.sh" \
      "$database_name" \
      "SET enable_seqscan TO on;SELECT * FROM scanwin_multipoint WHERE ${column_scan} = ${val};" \
      "noindex_${pct_label}_${val}" \
      "$output_csv_name"
  done
}

run_fraction "onepercent1" "onepercent2" "1pct"
run_fraction "fivepercent1" "fivepercent2" "5pct"
run_fraction "tenpercent1" "tenpercent2" "10pct"
run_fraction "twentypercent1" "twentypercent2" "20pct"

echo "PostgreSQL multipoint fraction-scan benchmark finished. Results saved to: $output_csv"
