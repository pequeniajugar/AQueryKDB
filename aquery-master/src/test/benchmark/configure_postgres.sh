#!/bin/bash
# Run one PostgreSQL configuration statement for benchmarks.
# Usage: bash configure_postgres.sh database_name "SQL statement"

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: bash configure_postgres.sh database_name \"SQL statement\""
  exit 1
fi

PGUSER="${PGUSER:-tianxin}"
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PSQL_BIN="${PSQL_BIN:-$(command -v psql)}"

PG_DB="$1"
SQL="$2"

if [[ -z "${PSQL_BIN:-}" || ! -x "$PSQL_BIN" ]]; then
  echo "Error: psql executable not found. Set PSQL_BIN or ensure psql is on PATH."
  exit 1
fi

"$PSQL_BIN" \
  -v ON_ERROR_STOP=1 \
  -U "$PGUSER" \
  -h "$PGHOST" \
  -p "$PGPORT" \
  -d "$PG_DB" \
  -c "$SQL"
