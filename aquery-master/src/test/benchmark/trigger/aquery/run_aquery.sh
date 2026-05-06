#!/bin/bash
# Benchmark: simplified aggregate maintenance triggers on AQuery.
# Query sources are written in .a and compiled to .q before execution.
#
# Expected orders CSV columns:
#   ordernum,itemnum,quantity,price,storeid,vendorid

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

tbl_file_path="${TRIGGER_INPUT_CSV:-/Users/tianxin/projects/nyu/ms1/research/dbtunning_experiements/data_generation/store/triggers_input.csv}"
Q_BIN="${Q_BIN:-/Users/tianxin/q/m64/q}"
RUNS="${RUNS:-11}"

generated_dir="$SCRIPT_DIR/generated"
mkdir -p "$generated_dir" "$REPO_ROOT/results"

insert_results_csv="results/aquery_aggregate_triggers_insert.csv"
query_output_csv_name="aquery_aggregate_triggers_queries.csv"
rm -f "$REPO_ROOT/results/$query_output_csv_name"

compile_aquery() {
  local src_a="$1"
  local out_q="$2"
  (cd "$REPO_ROOT" && sbt "run -c -o $out_q $src_a")
}

require_generated_q() {
  local out_q="$1"
  if [[ ! -s "$out_q" ]]; then
    echo "Error: expected generated q file is missing or empty: $out_q"
    exit 1
  fi
}

build_insert_q() {
  local input_csv="$1"
  local out_q="$2"
  python - "$input_csv" "$out_q" <<'PY'
import csv
import sys
from pathlib import Path

csv_path = Path(sys.argv[1])
out_q = Path(sys.argv[2])

def qsym(value: str) -> str:
    return '`$"' + value.strip().replace("\\", "\\\\").replace('"', '\\"') + '"'

lines = []
with csv_path.open("r", newline="") as f:
    reader = csv.reader(f)
    next(reader, None)
    for line_no, row in enumerate(reader, start=2):
        fields = [field.strip() for field in row]
        if len(fields) < 6:
            raise ValueError(
                f"line {line_no}: expected 6 columns "
                "(ordernum,itemnum,quantity,price,storeid,vendorid)"
            )
        ordernum, itemnum, quantity, price, storeid, vendorid = fields[:6]
        lines.append(
            ".aq.insert[`orders;orders;();([]"
            f"ordernum:enlist {int(ordernum)};"
            f"itemnum:enlist {int(itemnum)};"
            f"quantity:enlist {int(quantity)};"
            f"price:enlist {float(price)};"
            f"storeid:enlist {qsym(storeid)};"
            f"vendorid:enlist {qsym(vendorid)})];"
        )

out_q.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

build_workload_q() {
  local setup_q="$1"
  local insert_q="$2"
  local out_q="$3"
  printf 'system "l %s";\n' "$setup_q" > "$out_q"
  printf 'system "l %s";\n' "$insert_q" >> "$out_q"
}

echo "=== Simplified Aggregate Maintenance experiment on AQuery ==="
echo "Input CSV: $tbl_file_path"

setup_with_q="$generated_dir/setup_with_trigger.q"
setup_without_q="$generated_dir/setup_without_trigger.q"
insert_q="$generated_dir/orders_insert.q"
with_workload_q="$generated_dir/workload_with_trigger.q"
without_workload_q="$generated_dir/workload_without_trigger.q"
with_trigger_vendor_q="$generated_dir/with_trigger_vendor.q"
with_trigger_store_q="$generated_dir/with_trigger_store.q"
without_trigger_vendor_q="$generated_dir/without_trigger_vendor.q"
without_trigger_store_q="$generated_dir/without_trigger_store.q"

echo ">>> Compiling all .a files before benchmark measurement..."
compile_aquery "$SCRIPT_DIR/setup_with_trigger.a" "$setup_with_q"
compile_aquery "$SCRIPT_DIR/setup_without_trigger.a" "$setup_without_q"
compile_aquery "$SCRIPT_DIR/queries/with_trigger_vendor.a" "$with_trigger_vendor_q"
compile_aquery "$SCRIPT_DIR/queries/with_trigger_store.a" "$with_trigger_store_q"
compile_aquery "$SCRIPT_DIR/queries/without_trigger_vendor.a" "$without_trigger_vendor_q"
compile_aquery "$SCRIPT_DIR/queries/without_trigger_store.a" "$without_trigger_store_q"

require_generated_q "$setup_with_q"
require_generated_q "$setup_without_q"
require_generated_q "$with_trigger_vendor_q"
require_generated_q "$with_trigger_store_q"
require_generated_q "$without_trigger_vendor_q"
require_generated_q "$without_trigger_store_q"

echo ">>> Building insert workload q from CSV..."
build_insert_q "$tbl_file_path" "$insert_q"

echo ">>> Measuring inserts WITH triggers..."
python "$SCRIPT_DIR/trigger_data_insert.py" \
  --mode with_trigger \
  --file "$tbl_file_path" \
  --repo-root "$REPO_ROOT" \
  --setup-q "$setup_with_q" \
  --q-bin "$Q_BIN" \
  --runs "$RUNS" \
  --results-csv "$insert_results_csv"

echo ">>> Measuring inserts WITHOUT triggers..."
python "$SCRIPT_DIR/trigger_data_insert.py" \
  --mode without_trigger \
  --file "$tbl_file_path" \
  --repo-root "$REPO_ROOT" \
  --setup-q "$setup_without_q" \
  --q-bin "$Q_BIN" \
  --runs "$RUNS" \
  --results-csv "$insert_results_csv"

echo ">>> Building query workloads..."
build_workload_q "$setup_with_q" "$insert_q" "$with_workload_q"
build_workload_q "$setup_without_q" "$insert_q" "$without_workload_q"
require_generated_q "$with_workload_q"
require_generated_q "$without_workload_q"

echo ">>> Measuring query performance WITH triggers..."
Q_BIN="$Q_BIN" bash "$SCRIPT_DIR/../../base_aquery.sh" \
  "$with_workload_q" \
  "$query_output_csv_name" \
  "$with_trigger_vendor_q:with_trigger_vendor" \
  "$with_trigger_store_q:with_trigger_store"

echo ">>> Measuring query performance WITHOUT triggers..."
Q_BIN="$Q_BIN" bash "$SCRIPT_DIR/../../base_aquery.sh" \
  "$without_workload_q" \
  "$query_output_csv_name" \
  "$without_trigger_vendor_q:without_trigger_vendor" \
  "$without_trigger_store_q:without_trigger_store"

echo "Simplified Aggregate Maintenance AQuery experiment finished."
echo "Query results: ./results/$query_output_csv_name"
echo "Insert results: ./$insert_results_csv"
