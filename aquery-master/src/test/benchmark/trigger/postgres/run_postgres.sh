#!/bin/bash
# Benchmark: simplified aggregate maintenance triggers on PostgreSQL.
# - With triggers: AFTER INSERT on orders maintains vendorOutstanding/storeOutstanding.
# - Without triggers: queries compute SUM(quantity * price) directly from orders.
#
# Expected orders CSV columns:
#   ordernum,itemnum,quantity,price,storeid,vendorid

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

database_name="${PGDATABASE:-store10_5}"
tbl_file_path="${TRIGGER_INPUT_CSV:-/Users/tianxin/projects/nyu/ms1/research/dbtunning_experiements/data_generation/store/triggers_input.csv}"

query_output_csv_name="postgres_aggregate_triggers_queries.csv"
query_output_csv="./results/$query_output_csv_name"

mkdir -p "$(dirname "$query_output_csv")"
rm -f "$query_output_csv"

PG_USER="${PGUSER:-postgres}"
PG_PASSWORD="${PGPASSWORD:-pwd}"
PG_HOST="${PGHOST:-localhost}"
PG_PORT="${PGPORT:-5432}"
export PGUSER="$PG_USER"
export PGPASSWORD="$PG_PASSWORD"
export PGHOST="$PG_HOST"
export PGPORT="$PG_PORT"
export PGDATABASE="$database_name"

initial_max_ordernum=$(
  psql \
    -U "$PG_USER" \
    -h "$PG_HOST" \
    -p "$PG_PORT" \
    -d "$database_name" \
    -t -A \
    -c "SELECT COALESCE(MAX(ordernum), 0) FROM orders;" \
  2>/dev/null || echo 0
)

echo "=== Simplified Aggregate Maintenance experiment on PostgreSQL ==="
echo "Database: $database_name"
echo "Input CSV: $tbl_file_path"

###############################################################################
# 1. WITH TRIGGERS
###############################################################################

echo ">>> Setting up simplified triggers (WITH triggers)..."

read -r -d '' TRIGGER_SQL <<'SQL' || true
ALTER TABLE orders ADD COLUMN IF NOT EXISTS price NUMERIC(10,2);

CREATE OR REPLACE FUNCTION update_vendor_outstanding()
RETURNS trigger AS $$
BEGIN
    UPDATE vendorOutstanding
    SET amount = amount + (NEW.quantity * NEW.price)
    WHERE vendorid = NEW.vendorid;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_store_outstanding()
RETURNS trigger AS $$
BEGIN
    UPDATE storeOutstanding
    SET amount = amount + (NEW.quantity * NEW.price)
    WHERE storeid = NEW.storeid;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS updateVendorOutstanding ON orders;
CREATE TRIGGER updateVendorOutstanding
AFTER INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION update_vendor_outstanding();

DROP TRIGGER IF EXISTS updateStoreOutstanding ON orders;
CREATE TRIGGER updateStoreOutstanding
AFTER INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION update_store_outstanding();
SQL

bash "$SCRIPT_DIR/../../configure_postgres.sh" \
  "$database_name" \
  "$TRIGGER_SQL"

echo ">>> Inserting data row-by-row with triggers..."

python "$SCRIPT_DIR/trigger_data_insert.py" \
  --mode with_trigger \
  --file "$tbl_file_path"

echo ">>> Measuring query performance WITH triggers..."

bash "$SCRIPT_DIR/../../base_postgres.sh" \
  "$database_name" \
  "SELECT amount FROM vendorOutstanding WHERE vendorid = '10';" \
  "with_trigger_vendor" \
  "$query_output_csv_name"

bash "$SCRIPT_DIR/../../base_postgres.sh" \
  "$database_name" \
  "SELECT amount FROM storeOutstanding WHERE storeid = '10';" \
  "with_trigger_store" \
  "$query_output_csv_name"

echo ">>> Restoring orders table to pre-insertion state after WITH-triggers experiment..."

bash "$SCRIPT_DIR/../../configure_postgres.sh" \
  "$database_name" \
  "DELETE FROM orders WHERE ordernum > ${initial_max_ordernum};"

###############################################################################
# 2. WITHOUT TRIGGERS
###############################################################################

echo ">>> Dropping triggers and functions (WITHOUT triggers)..."

read -r -d '' DROP_TRIGGERS_SQL <<'SQL' || true
DROP TRIGGER IF EXISTS updateVendorOutstanding ON orders;
DROP TRIGGER IF EXISTS updateStoreOutstanding ON orders;
DROP FUNCTION IF EXISTS update_vendor_outstanding();
DROP FUNCTION IF EXISTS update_store_outstanding();
SQL

bash "$SCRIPT_DIR/../../configure_postgres.sh" \
  "$database_name" \
  "$DROP_TRIGGERS_SQL"

echo ">>> Inserting data row-by-row WITHOUT triggers..."

python "$SCRIPT_DIR/trigger_data_insert.py" \
  --mode without_trigger \
  --file "$tbl_file_path"

echo ">>> Measuring query performance WITHOUT triggers..."

bash "$SCRIPT_DIR/../../base_postgres.sh" \
  "$database_name" \
  "SELECT SUM(quantity * price) FROM orders WHERE vendorid = '10';" \
  "without_trigger_vendor" \
  "$query_output_csv_name"

bash "$SCRIPT_DIR/../../base_postgres.sh" \
  "$database_name" \
  "SELECT SUM(quantity * price) FROM orders WHERE storeid = '10';" \
  "without_trigger_store" \
  "$query_output_csv_name"

echo ">>> Restoring orders table to pre-insertion state after WITHOUT-triggers experiment..."

bash "$SCRIPT_DIR/../../configure_postgres.sh" \
  "$database_name" \
  "DELETE FROM orders WHERE ordernum > ${initial_max_ordernum};"

echo "Simplified Aggregate Maintenance experiment finished."
echo "Query results: $query_output_csv"
echo "Insert results: ./results/postgres_aggregate_triggers_insert.csv"
