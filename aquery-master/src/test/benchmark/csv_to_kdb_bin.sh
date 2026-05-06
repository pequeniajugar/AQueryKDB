#!/bin/bash
# Convert a CSV file to a q/kdb+ binary table file in the same directory.
#
# Usage:
#   bash csv_to_kdb_bin.sh /path/to/file.csv [type_spec]
#
# Examples:
#   bash csv_to_kdb_bin.sh /tmp/employees.csv "ISIIII"
#   bash csv_to_kdb_bin.sh /tmp/lineitem.csv "JJIIFFFFSSSSSSSS"
#
# If type_spec is omitted, every column is loaded as symbol according to the first row's field count.

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: bash csv_to_kdb_bin.sh /path/to/file.csv [type_spec]"
  exit 1
fi

CSV_PATH="$1"
TYPE_SPEC="${2-}"
Q_BIN="${Q_BIN:-q}"

if [[ ! -f "$CSV_PATH" ]]; then
  echo "Error: CSV file not found: $CSV_PATH"
  exit 1
fi

case "$CSV_PATH" in
  *.csv) BIN_PATH="${CSV_PATH%.csv}.bin" ;;
  *) BIN_PATH="${CSV_PATH}.bin" ;;
esac

if ! command -v "$Q_BIN" >/dev/null 2>&1; then
  echo "Error: q executable not found: $Q_BIN"
  exit 1
fi

RUNNER_FILE="$(mktemp "/tmp/csv_to_kdb_bin_XXXXXX").q"
cleanup() {
  rm -f "$RUNNER_FILE"
}
trap cleanup EXIT

cat > "$RUNNER_FILE" <<'QEOF'
csvPath:.z.x 0;
binPath:.z.x 1;
typeSpec:.z.x 2;

csvLine:hsym `$csvPath;

if[0=count typeSpec;
  firstLine:first read0 csvLine;
  typeSpec:(count "," vs firstLine)#"S";
 ];

tbl:(typeSpec;enlist ",") 0:csvLine;

binHandle:hsym `$binPath;
binHandle set tbl;
show "wrote ",binPath;
QEOF

"$Q_BIN" "$RUNNER_FILE" "$CSV_PATH" "$BIN_PATH" "$TYPE_SPEC"

echo "Saved q binary table: $BIN_PATH"
