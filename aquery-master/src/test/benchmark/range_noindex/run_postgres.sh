#!/bin/bash
# Benchmark: Range query without index on PostgreSQL.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

database_name="employeesindex10_7"   # Change if needed
output_csv="$SCRIPT_DIR/results/postgres_range_noindex.csv"

mkdir -p "$(dirname "$output_csv")"
echo "dbms,label,iteration,execution_time,response_time" > "$output_csv"

echo "===== RANGE NO INDEX BENCHMARK ====="
bash "$SCRIPT_DIR/../base_postgres.sh" \
  "$database_name" \
  "SELECT * FROM employees WHERE lat BETWEEN {v1} AND {v2};" \
  "range_no_index" \
  "$(basename "$output_csv")" \
  "SET enable_seqscan = on; "

echo "Benchmark finished. Results saved to: $output_csv"
