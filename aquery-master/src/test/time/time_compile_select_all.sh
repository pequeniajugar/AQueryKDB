#!/usr/bin/env bash
# Measure the time needed to compile select_all/aquery/all.a into all.q.
#
# Usage:
#   bash src/test/time/time_compile_select_all.sh
#
# Optional environment variables:
#   AQUERY_JAR=/path/to/aquery.jar
#   RUNS=5

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AQUERY_MASTER="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$AQUERY_MASTER/.." && pwd)"

INPUT_A="$AQUERY_MASTER/src/test/benchmark/range_noindex/aquery/noindex.a"
OUTPUT_Q="$AQUERY_MASTER/src/test/benchmark/range_noindex/aquery/noindex2.q"
RUNS="${RUNS:-1}"

if [[ -n "${AQUERY_JAR:-}" ]]; then
  JAR="$AQUERY_JAR"
elif [[ -f "$WORKSPACE_ROOT/aquery.jar" ]]; then
  JAR="$WORKSPACE_ROOT/aquery.jar"
elif [[ -f "$AQUERY_MASTER/target/scala-2.11/aquery.jar" ]]; then
  JAR="$AQUERY_MASTER/target/scala-2.11/aquery.jar"
else
  echo "Error: aquery.jar not found."
  echo "Set AQUERY_JAR=/path/to/aquery.jar and rerun this script."
  exit 1
fi

if [[ ! "$RUNS" =~ ^[0-9]+$ ]] || [[ "$RUNS" -lt 1 ]]; then
  echo "Error: RUNS must be a positive integer."
  exit 1
fi

if [[ ! -f "$INPUT_A" ]]; then
  echo "Error: input file not found: $INPUT_A"
  exit 1
fi

if ! command -v java >/dev/null 2>&1; then
  echo "Error: java executable not found in PATH."
  exit 1
fi

if ! perl -MTime::HiRes=time -e 'exit 0' >/dev/null 2>&1; then
  echo "Error: perl Time::HiRes is required for millisecond timing."
  exit 1
fi

now_ms() {
  perl -MTime::HiRes=time -e 'printf "%.0f\n", time() * 1000'
}

echo "AQuery compile timing"
echo "Jar:    $JAR"
echo "Input:  $INPUT_A"
echo "Output: $OUTPUT_Q"
echo "Runs:   $RUNS"
echo

total_ms=0

for i in $(seq 1 "$RUNS"); do
  start_ms="$(now_ms)"

  java -cp "$JAR" edu.nyu.aquery.Aquery \
    -c \
    -o "$OUTPUT_Q" \
    "$INPUT_A"

  end_ms="$(now_ms)"
  elapsed_ms="$(( end_ms - start_ms ))"
  total_ms="$(( total_ms + elapsed_ms ))"

  printf "run %d: %d ms\n" "$i" "$elapsed_ms"
done

avg_ms="$(( total_ms / RUNS ))"
printf "\naverage: %d ms over %d run(s)\n" "$avg_ms" "$RUNS"
