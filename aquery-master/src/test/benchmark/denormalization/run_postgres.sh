#!/bin/bash
# Benchmark: denormalized TPCH lineitem-region lookup on PostgreSQL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

database_name="${PGDATABASE:-tpch10_5}"
output_csv_name="postgres_big_denormalization.csv"
output_csv="./results/$output_csv_name"

mkdir -p "$(dirname "$output_csv")"
echo "dbms,label,iteration,execution_time,response_time" > "$output_csv"

echo "=== PostgreSQL Denormalization Benchmark ==="
echo "Database: $database_name"

echo ">>> Measuring normalized join query..."
bash "$SCRIPT_DIR/../base_postgres.sh" \
  "$database_name" \
  "SELECT L.L_ORDERKEY, L.L_PARTKEY, L.L_SUPPKEY, L.L_LINENUMBER, L.L_QUANTITY, L.L_EXTENDEDPRICE, L.L_DISCOUNT, L.L_TAX, L.L_RETURNFLAG, L.L_LINESTATUS, L.L_SHIPDATE, L.L_COMMITDATE, L.L_RECEIPTDATE, L.L_SHIPINSTRUCT, L.L_SHIPMODE, L.L_COMMENT, R.R_NAME FROM lineitem AS L JOIN supplier AS S ON L.L_SUPPKEY = S.S_SUPPKEY JOIN nation AS N ON S.S_NATIONKEY = N.N_NATIONKEY JOIN region AS R ON N.N_REGIONKEY = R.R_REGIONKEY WHERE R.R_NAME = 'EUROPE';" \
  "without_denormalization" \
  "$output_csv_name"

echo ">>> Ensuring denormalized table exists..."
bash "$SCRIPT_DIR/../configure_postgres.sh" \
  "$database_name" \
  "CREATE TABLE IF NOT EXISTS lineitemdenormalized AS
   SELECT L.L_ORDERKEY, L.L_PARTKEY, L.L_SUPPKEY, L.L_LINENUMBER, L.L_QUANTITY, L.L_EXTENDEDPRICE, L.L_DISCOUNT, L.L_TAX, L.L_RETURNFLAG, L.L_LINESTATUS, L.L_SHIPDATE, L.L_COMMITDATE, L.L_RECEIPTDATE, L.L_SHIPINSTRUCT, L.L_SHIPMODE, L.L_COMMENT, R.R_NAME AS R_REGION
   FROM lineitem AS L
   JOIN supplier AS S ON L.L_SUPPKEY = S.S_SUPPKEY
   JOIN nation AS N ON S.S_NATIONKEY = N.N_NATIONKEY
   JOIN region AS R ON N.N_REGIONKEY = R.R_REGIONKEY;"

echo ">>> Measuring denormalized query..."
bash "$SCRIPT_DIR/../base_postgres.sh" \
  "$database_name" \
  "SELECT L_ORDERKEY, L_PARTKEY, L_SUPPKEY, L_LINENUMBER, L_QUANTITY, L_EXTENDEDPRICE, L_DISCOUNT, L_TAX, L_RETURNFLAG, L_LINESTATUS, L_SHIPDATE, L_COMMITDATE, L_RECEIPTDATE, L_SHIPINSTRUCT, L_SHIPMODE, L_COMMENT, R_REGION FROM lineitemdenormalized WHERE R_REGION = 'EUROPE';" \
  "with_denormalization" \
  "$output_csv_name"

echo "PostgreSQL denormalization benchmark finished. Results saved to: $output_csv"
