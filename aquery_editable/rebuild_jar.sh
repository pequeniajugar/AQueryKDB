#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_JAR="${1:-$SCRIPT_DIR/aquery-editable.jar}"
cd "$SCRIPT_DIR/unpacked"
jar cfm "$OUT_JAR" META-INF/MANIFEST.MF .
echo "Built: $OUT_JAR"
