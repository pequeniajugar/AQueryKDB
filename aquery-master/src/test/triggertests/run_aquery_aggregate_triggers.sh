#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

Q_BIN="${Q_BIN:-/Users/tianxin/q/m64/q}"
TBL_FILE_PATH="${1:-/Users/tianxin/projects/nyu/ms1/research/dbtunning_experiements/data_generation/store/triggers_input.csv}"
ITEM_FILE_PATH="${ITEM_FILE_PATH:-/Users/tianxin/projects/nyu/ms1/research/dbtunning_experiements/data_generation/store/item_10_8.csv}"
STORE_FILE_PATH="${STORE_FILE_PATH:-/Users/tianxin/projects/nyu/ms1/research/dbtunning_experiements/data_generation/store/store_10_8.csv}"
STORE_OUT_FILE_PATH="${STORE_OUT_FILE_PATH:-/Users/tianxin/projects/nyu/ms1/research/dbtunning_experiements/data_generation/store/storeOutstanding_10_8.csv}"
VENDOR_OUT_FILE_PATH="${VENDOR_OUT_FILE_PATH:-/Users/tianxin/projects/nyu/ms1/research/dbtunning_experiements/data_generation/store/vendorOutstanding_10_8.csv}"
RUNS="${RUNS:-11}"

INSERT_RESULTS_CSV="$REPO_ROOT/results/aquery_aggregate_triggers_insert.csv"
QUERY_RESULTS_CSV="$REPO_ROOT/results/aquery_aggregate_triggers_queries.csv"

TMP_DIR="$(mktemp -d /tmp/aquery_aggregate_triggers.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

SETUP_A="$TMP_DIR/aggregate_setup.a"
SETUP_Q="$TMP_DIR/aggregate_setup.q"
COMMON_Q="$TMP_DIR/aggregate_common.q"
QUERY_Q="$TMP_DIR/query_run.q"

mkdir -p "$REPO_ROOT/results"
rm -f "$QUERY_RESULTS_CSV"
printf 'dbms,label,iteration,execution_time,response_time\n' > "$QUERY_RESULTS_CSV"

cat > "$SETUP_A" <<EOF
CREATE TABLE orders(ordernum INT, itemnum INT, quantity INT, storeid STRING, vendorid STRING)
CREATE TABLE store(storeid STRING, name STRING)
CREATE TABLE item(itemnum INT, price INT)
CREATE TABLE vendorOutstanding(vendorid STRING, amount INT)
CREATE TABLE storeOutstanding(storeid STRING, amount INT)

<q>
.bench.asSym:{[x] \$[-11h=type x; x; \`\$string x]};
.bench.pickIds:{[ids;n]
  m:count ids;
  if[0=m; :\`symbol\$()];
  ids[mod[til n;m]]
  };

inputFile:"$TBL_FILE_PATH";
itemFile:"$ITEM_FILE_PATH";
storeFile:"$STORE_FILE_PATH";
storeOutstandingFile:"$STORE_OUT_FILE_PATH";
vendorOutstandingFile:"$VENDOR_OUT_FILE_PATH";
rawLines:1_ read0 \`\$inputFile;
parsed:"," vs' rawLines;

ordersInput:flip \`ordernum\`itemnum\`quantity\`storeid\`vendorid!(
  "J"\$ first each parsed;
  "J"\$ parsed[;1];
  "J"\$ parsed[;2];
  .bench.asSym each parsed[;3];
  .bench.asSym each parsed[;4]
  );

itemLines:1_ read0 \`\$itemFile;
itemParsed:"," vs' itemLines;
item set flip \`itemnum\`price!(
  "J"\$ first each itemParsed;
  "J"\$ itemParsed[;1]
  );

storeLines:1_ read0 \`\$storeFile;
storeParsed:"," vs' storeLines;
store set flip \`storeid\`name!(
  .bench.asSym each first each storeParsed;
  \`\$ storeParsed[;1]
  );

vendorOutstandingLines:1_ read0 \`\$vendorOutstandingFile;
vendorOutstandingParsed:"," vs' vendorOutstandingLines;
vendorOutstanding set flip \`vendorid\`amount!(
  .bench.asSym each first each vendorOutstandingParsed;
  "J"\$ vendorOutstandingParsed[;1]
  );

storeOutstandingLines:1_ read0 \`\$storeOutstandingFile;
storeOutstandingParsed:"," vs' storeOutstandingLines;
storeOutstanding set flip \`storeid\`amount!(
  .bench.asSym each first each storeOutstandingParsed;
  "J"\$ storeOutstandingParsed[;1]
  );

orders set 0#orders;
itemPriceByNum:item\`itemnum!item\`price;
vendorIdsForBench:.bench.pickIds[asc distinct ordersInput\`vendorid;$RUNS];
storeIdsForBench:.bench.pickIds[asc distinct ordersInput\`storeid;$RUNS];
</q>
EOF

cat > "$COMMON_Q" <<'EOF'
.bench.vendorDeltaTrigger:{[tbl;evt;ctx]
  rows:.trg.rows ctx;
  if[98h<>type rows; :ctx];
  if[0=count rows; :ctx];
  i:0;
  while[i<count rows;
    r:rows i;
    delta:(r`quantity) * itemPriceByNum r`itemnum;
    vendorOutstanding:update amount:amount + delta from vendorOutstanding where vendorid=r`vendorid;
    i+:1
    ];
  ctx
  };

.bench.storeDeltaTrigger:{[tbl;evt;ctx]
  rows:.trg.rows ctx;
  if[98h<>type rows; :ctx];
  if[0=count rows; :ctx];
  i:0;
  while[i<count rows;
    r:rows i;
    delta:(r`quantity) * itemPriceByNum r`itemnum;
    storeOutstanding:update amount:amount + delta from storeOutstanding where storeid=r`storeid;
    i+:1
    ];
  ctx
  };

.bench.configureMode:{[mode]
  .trg.reset[];
  if[mode=`with_trigger;
    .trg.register[`orders;`insert;`after;`bench_vendor_outstanding;100;`.bench.vendorDeltaTrigger];
    .trg.register[`orders;`insert;`after;`bench_store_outstanding;110;`.bench.storeDeltaTrigger]
    ];
  };

.bench.queryWithTriggerVendor:{[idx]
  vid:vendorIdsForBench idx;
  select amount from vendorOutstanding where vendorid=vid
  };

.bench.queryWithTriggerStore:{[idx]
  sid:storeIdsForBench idx;
  select amount from storeOutstanding where storeid=sid
  };

.bench.queryWithoutTriggerVendor:{[idx]
  vid:vendorIdsForBench idx;
  rows:select from orders where vendorid=vid;
  if[0=count rows; :([] amount:enlist 0Nj)];
  ([] amount:enlist sum rows`quantity * itemPriceByNum rows`itemnum)
  };

.bench.queryWithoutTriggerStore:{[idx]
  sid:storeIdsForBench idx;
  rows:select from orders where storeid=sid;
  if[0=count rows; :([] amount:enlist 0Nj)];
  ([] amount:enlist sum rows`quantity * itemPriceByNum rows`itemnum)
  };
EOF

compile_aquery() {
  local src_a="$1"
  local out_q="$2"
  (cd "$REPO_ROOT" && sbt "run -c -o $out_q $src_a")
}

run_query_timer() {
  local mode="$1"
  local query_kind="$2"
  local label="$3"
  local iteration="$4"

  cat > "$QUERY_Q" <<EOF
system "l $SETUP_Q";
system "l $COMMON_Q";
.bench.configureMode[\`$mode];
system "l $INSERT_Q";
wall0:.z.p;
stats:\\ts \$[("$query_kind"~"with_trigger_vendor"); .bench.queryWithTriggerVendor[$((iteration-1))];
  ("$query_kind"~"with_trigger_store"); .bench.queryWithTriggerStore[$((iteration-1))];
  ("$query_kind"~"without_trigger_vendor"); .bench.queryWithoutTriggerVendor[$((iteration-1))];
  .bench.queryWithoutTriggerStore[$((iteration-1))]];
wall1:.z.p;
resp:("f"\$(wall1-wall0))%1000000000f;
exec:("f"\$first stats)%1000f;
-1 "RESULT|",string resp,"|",string exec;
exit 0;
EOF

  local output
  output="$("$Q_BIN" "$QUERY_Q")"
  local result_line
  result_line="$(printf '%s\n' "$output" | awk -F'|' '/^RESULT\|/ {print $0}')"
  local resp_time exec_time
  resp_time="$(printf '%s' "$result_line" | awk -F'|' '{print $2}')"
  exec_time="$(printf '%s' "$result_line" | awk -F'|' '{print $3}')"
  printf 'aquery,%s,%s,%s,%s\n' "$label" "$iteration" "$exec_time" "$resp_time" >> "$QUERY_RESULTS_CSV"
}

echo "=== Aggregate Maintenance experiment on AQuery ==="
echo ">>> Compiling AQuery setup..."
compile_aquery "$SETUP_A" "$SETUP_Q"

echo ">>> Building insert benchmark source and measuring row-by-row inserts..."
python "$SCRIPT_DIR/aquery_trigger_data_insert.py" \
  --mode with_trigger \
  --file "$TBL_FILE_PATH" \
  --repo-root "$REPO_ROOT" \
  --setup-q "$SETUP_Q" \
  --common-q "$COMMON_Q" \
  --q-bin "$Q_BIN" \
  --runs "$RUNS" \
  --results-csv "results/$(basename "$INSERT_RESULTS_CSV")"

INSERT_A="$TMP_DIR/orders_insert.a"
INSERT_Q="$TMP_DIR/orders_insert.q"

python - "$TBL_FILE_PATH" "$INSERT_A" <<'PY'
import csv
import sys
from pathlib import Path

csv_path = Path(sys.argv[1])
out_a = Path(sys.argv[2])

def lit(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

lines = []
with csv_path.open("r", newline="") as f:
    reader = csv.reader(f)
    next(reader, None)
    for row in reader:
        if len(row) < 5:
            continue
        ordernum, itemnum, quantity, storeid, vendorid = row[:5]
        lines.append(
            f'INSERT INTO orders VALUES({int(ordernum)}, {int(itemnum)}, {int(quantity)}, {lit(storeid)}, {lit(vendorid)})'
        )
out_a.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

compile_aquery "$INSERT_A" "$INSERT_Q"

echo ">>> Measuring query performance WITH triggers..."
for i in $(seq 1 "$RUNS"); do
  run_query_timer "with_trigger" "with_trigger_vendor" "with_trigger_vendor" "$i"
done
for i in $(seq 1 "$RUNS"); do
  run_query_timer "with_trigger" "with_trigger_store" "with_trigger_store" "$i"
done

echo ">>> Measuring row-by-row inserts WITHOUT triggers..."
python "$SCRIPT_DIR/aquery_trigger_data_insert.py" \
  --mode without_trigger \
  --file "$TBL_FILE_PATH" \
  --repo-root "$REPO_ROOT" \
  --setup-q "$SETUP_Q" \
  --common-q "$COMMON_Q" \
  --q-bin "$Q_BIN" \
  --runs "$RUNS" \
  --results-csv "results/$(basename "$INSERT_RESULTS_CSV")"

echo ">>> Measuring query performance WITHOUT triggers..."
for i in $(seq 1 "$RUNS"); do
  run_query_timer "without_trigger" "without_trigger_vendor" "without_trigger_vendor" "$i"
done
for i in $(seq 1 "$RUNS"); do
  run_query_timer "without_trigger" "without_trigger_store" "without_trigger_store" "$i"
done

echo "Aggregate Maintenance (triggers vs no triggers) experiment finished."
