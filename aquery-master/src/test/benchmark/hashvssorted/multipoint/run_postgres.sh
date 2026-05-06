#!/bin/bash
# Benchmark: Hash vs B+Tree vs No Index on PostgreSQL
# Output goes directly into a CSV file (using base_postgres.sh)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

database_name="employeesindex10_5"   # Change if needed
#change file name to postgres_small_hash_vs_btree_multipoint.csv
output_csv="$SCRIPT_DIR/../results/postgres_big_hash_vs_btree_multipoint.csv"

# Ensure results directory exists
mkdir -p "$(dirname "$output_csv")"

# Recreate CSV header
echo "dbms,label,iteration,execution_time,response_time" > "$output_csv"

# --- No Index ---
echo "===== NO INDEX BENCHMARK ====="
bash "$SCRIPT_DIR/../../base_postgres.sh" \
  "$database_name" \
  "SELECT * FROM employees WHERE hundreds1 = {v1};" \
  "no_index" \
  "$(basename "$output_csv")" \
  "SET enable_seqscan = on; "

# --- Hash Index ---
echo "===== HASH INDEX BENCHMARK ====="
bash "$SCRIPT_DIR/../../configure_postgres.sh" "$database_name" \
  "CREATE INDEX idx_hundreds1_hash ON employees USING HASH (hundreds1);"

bash "$SCRIPT_DIR/../../base_postgres.sh" \
  "$database_name" \
  "SELECT * FROM employees WHERE hundreds1 = {v1};" \
  "hash_index" \
  "$(basename "$output_csv")" \
  "SET enable_seqscan = off; "

bash "$SCRIPT_DIR/../../configure_postgres.sh" "$database_name" \
  "DROP INDEX IF EXISTS idx_hundreds1_hash;"

# --- B+ Tree Index ---
echo "===== BTREE INDEX BENCHMARK ====="
bash "$SCRIPT_DIR/../../configure_postgres.sh" "$database_name" \
  "CREATE INDEX idx_hundreds1_btree ON employees USING BTREE (hundreds1);"

bash "$SCRIPT_DIR/../../base_postgres.sh" \
  "$database_name" \
  "SELECT * FROM employees WHERE hundreds1 = {v1};" \
  "btree_index" \
  "$(basename "$output_csv")" \
  "SET enable_seqscan = off; "

bash "$SCRIPT_DIR/../../configure_postgres.sh" "$database_name" \
  "DROP INDEX IF EXISTS idx_hundreds1_btree;"

echo "Benchmark finished. Results saved to: $output_csv"
