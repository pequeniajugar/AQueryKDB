#!/bin/bash
# Run retrieve-needed-columns experiments for PostgreSQL using base_postgres.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

database_name="tpch10_7"                             # change if needed
output_csv_name="postgres_big_retrieve_needed_columns.csv"  # change if needed

# Fetch all columns
bash "${SCRIPT_DIR}/../base_postgres.sh" \
  "$database_name" \
  "SELECT * FROM lineitem;" \
  "All Columns" \
  "$output_csv_name"
