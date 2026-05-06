#!/bin/bash
# Benchmark: denormalized TPCH lineitem-region lookup on AQuery.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

Q_BIN="${Q_BIN:-/Users/tianxin/q/m64/q}"
output_csv_name="aquery_big_denormalization.csv"
denorm_tbl="${DENORM_TBL:-${DENORM_CSV:-/Users/tianxin/projects/nyu/ms2/independent_study/data/tpch/data_10_7/lineitemdenormalized.tbl}}"

mkdir -p "$REPO_ROOT/results"
rm -f "$REPO_ROOT/results/$output_csv_name"

require_file() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    echo "Error: required file is missing or empty: $path"
    exit 1
  fi
}

load_q="$SCRIPT_DIR/load_tpch_denormalization.q"
denorm_load_q="$SCRIPT_DIR/load_lineitemdenormalized.q"
aquery_src_dir="$SCRIPT_DIR/aquery"
without_query_q="$aquery_src_dir/without_denormalization.q"
with_query_q="$aquery_src_dir/with_denormalization.q"

echo "=== AQuery Denormalization Benchmark ==="
echo "Load script: $load_q"
echo "Denormalized table file: $denorm_tbl"

require_file "$load_q"
require_file "$denorm_load_q"
require_file "$without_query_q"
require_file "$with_query_q"

if [[ ! -s "$denorm_tbl" ]]; then
  echo ">>> Denormalized table file not found; building it once with q foreign-key projection..."
  mkdir -p "$(dirname "$denorm_tbl")"
  build_runner="$(mktemp "/tmp/aquery_build_denorm_XXXXXX").q"
  cat > "$build_runner" <<Q
\\l $load_q
lineitemdenormalized:select l_orderkey,l_partkey,l_suppkey,l_linenumber,l_quantity,l_extendedprice,l_discount,l_tax,l_returnflag,l_linestatus,l_shipdate,l_commitdate,l_receiptdate,l_shipinstruct,l_shipmode,l_comment,r_region:l_suppkey.s_nationkey.n_regionkey.r_name from lineitem;
lineitemdenormalized:update l_orderkey:`$string l_orderkey,l_partkey:`$string l_partkey,l_suppkey:`$string l_suppkey,l_linenumber:`$string l_linenumber,l_returnflag:`$string l_returnflag,l_linestatus:`$string l_linestatus,l_shipdate:`$string l_shipdate,l_commitdate:`$string l_commitdate,l_receiptdate:`$string l_receiptdate,l_shipinstruct:`$string l_shipinstruct,l_shipmode:`$string l_shipmode,l_comment:`$string l_comment,r_region:`$string r_region from lineitemdenormalized;
\`:$denorm_tbl 0: "|" 0: lineitemdenormalized;
exit 0
Q
  "$Q_BIN" "$build_runner"
  rm -f "$build_runner"
fi

require_file "$denorm_tbl"

echo ">>> Measuring normalized foreign-key/join query..."
Q_BIN="$Q_BIN" bash "$SCRIPT_DIR/../base_aquery.sh" \
  "$load_q" \
  "$output_csv_name" \
  "$without_query_q:without_denormalization"

echo ">>> Measuring denormalized query..."
DENORM_TBL="$denorm_tbl" Q_BIN="$Q_BIN" bash "$SCRIPT_DIR/../base_aquery.sh" \
  "$denorm_load_q" \
  "$output_csv_name" \
  "$with_query_q:with_denormalization"

echo "AQuery denormalization benchmark finished. Results saved to: ./results/$output_csv_name"
