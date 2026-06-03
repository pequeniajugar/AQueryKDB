# AQuery jar and kdb+ quick start

This directory contains the packaged AQuery jar:

```text
aquery.jar
```

## Install kdb+

Official references:

- kdb+ Personal Edition download: https://kx.com/kdb-personal-edition-download
- kdb+ install guide: https://code.kx.com/q/learn/install/

For non-commercial use, sign up for kdb+ Personal Edition on the KX download page. KX provides the platform zip and a license file, usually `kc.lic`.

---

### macOS kdb+ Installation

The downloaded macOS x86-64 platform zip is usually `m64.zip`.

```bash
cd ~/Downloads
unzip m64.zip -d "$HOME/q"
cp /path/to/kc.lic "$HOME/q/kc.lic"
```

Authorize and run q from Terminal:

```bash
cd "$HOME"
spctl --add q/m64/q
xattr -d com.apple.quarantine q/m64/q
q/m64/q
```

Optional shell setup:

```bash
export QHOME="$HOME/q"
export PATH="$QHOME/m64:$PATH"
q
```

Exit q:

```q
\\
```

---

### Linux kdb+ Installation

The downloaded Linux x86-64 platform zip is usually `l64.zip`.

```bash
cd ~/Downloads
unzip l64.zip -d "$HOME/q"
cp /path/to/kc.lic "$HOME/q/kc.lic"
chmod +x "$HOME/q/l64/q"
$HOME/q/l64/q
```

Optional shell setup:

```bash
export QHOME="$HOME/q"
export PATH="$QHOME/l64:$PATH"
q
```

Exit q:

```q
\\
```

---

### Windows kdb+ Installation

The downloaded Windows x86-64 platform zip is usually `w64.zip`.

In PowerShell:

```powershell
Expand-Archive .\w64.zip -DestinationPath $HOME\q
Copy-Item .\kc.lic $HOME\q\kc.lic
& $HOME\q\w64\q.exe
```

Optional PowerShell setup for the current session:

```powershell
$env:QHOME="$HOME\q"
$env:Path="$env:QHOME\w64;$env:Path"
q
```

Exit q:

```q
\\
```

---

## AQuery Query Syntax Overview

AQuery source files under `aquery-master` usually use the `.a` suffix. The compiler translates them into `.q` files that can be executed by kdb+. The syntax is SQL-like, with additional support for kdb+/array-oriented operations, `ASSUMING` ordering hints, triggers, and embedded q code.

A minimal query:

```sql
SELECT l_orderkey, l_partkey, l_quantity
FROM lineitem
WHERE l_quantity > 10 AND l_shipdate < '01/01/1998'
```

A more complete query shape:

```sql
WITH recent_orders AS (
  SELECT ordernum, itemnum, quantity
  FROM orders
  WHERE quantity > 0
)
SELECT storeid, SUM(quantity) AS total_quantity
FROM recent_orders
ASSUMING ASC storeid
WHERE storeid != "UNKNOWN"
GROUP BY storeid
HAVING SUM(quantity) > 100
```

Main syntax points:

- `SELECT ... FROM ... WHERE ... GROUP BY ... HAVING ...` is similar to SQL. Multiple `WHERE` or `HAVING` conditions are joined with `AND`.
- `WITH name AS (SELECT ...)` defines a local query. You can also write `WITH name(col1, col2) AS (...)` to provide explicit output column names.
- `FROM` supports plain tables, aliases, comma joins, `INNER JOIN ... USING (...)`, and `FULL OUTER JOIN ... USING (...)`. For a single join key, `USING key` can omit parentheses.
- `ASSUMING ASC col` or `ASSUMING DESC col` declares that the input relation is already ordered by a column. The optimizer and code generator can use this information.
- Expressions support `+ - * / ^`, comparison operators, boolean operators `&`/`|`/`!`, `CASE WHEN ... THEN ... ELSE ... END`, `table.column`, `ROWID`, and array indexes `[EVEN]`, `[ODD]`, `[EVERY n]`.
- Common built-in functions include `SUM`, `AVG`, `COUNT`, `MIN`, `MAX`, `FIRST`, `LAST`, `DISTINCT`, `ABS`, `SQRT`, `PREV`, `NEXT`, `MOVING`, `FILL`, and `SHOW`.
- Strings use double quotes, for example `"EUROPE"`. Dates and timestamps use single quotes, with formats `'MM/dd/yyyy'` and `'MM/dd/yyyyDHH:mm:ss'`. Timestamps may include a nanosecond suffix.
- Type names must be uppercase: `INT`, `FLOAT`, `STRING`, `BOOLEAN`, `DATE`, `TIMESTAMP`.
- Use `<q> ... </q>` to embed native q code directly inside a `.a` file.

Basic `.a` query examples adapted from `aquery-master/src/test/benchmark`:

Full table scan:

```sql
SELECT * FROM lineitem
```

Range predicate:

```sql
SELECT *
FROM employees
WHERE lat BETWEEN 150 AND 1150
```

Point lookup on an indexed or pre-sorted table prepared with embedded q:

```sql
<q>
emp_sorted_ssnum:`ssnum xasc employees;
emp_sorted_ssnum:update ssnum:`s#ssnum from emp_sorted_ssnum;
</q>

SELECT *
FROM emp_sorted_ssnum
WHERE ssnum = 150
```

Multi-table join with aliases and filters:

```sql
SELECT
  L.l_orderkey,
  L.l_partkey,
  L.l_quantity,
  R.r_name
FROM lineitem AS L, supplier AS S, nation AS N, region AS R
WHERE L.l_suppkey = S.s_suppkey
  AND S.s_nationkey = N.n_nationkey
  AND N.n_regionkey = R.r_regionkey
  AND R.r_name = "EUROPE"
```

Create a denormalized table from a query:

```sql
CREATE TABLE lineitemdenormalized
SELECT
  L.l_orderkey,
  L.l_partkey,
  L.l_quantity,
  R.r_name AS r_region
FROM lineitem AS L, supplier AS S, nation AS N, region AS R
WHERE L.l_suppkey = S.s_suppkey
  AND S.s_nationkey = N.n_nationkey
  AND N.n_regionkey = R.r_regionkey
```

Query the denormalized table:

```sql
SELECT l_orderkey, l_partkey, l_quantity, r_region
FROM lineitemdenormalized
WHERE r_region = "EUROPE"
```

Read a value maintained by triggers:

```sql
SELECT amount
FROM storeOutstanding
WHERE storeid = "10"
```

AQuery also supports DDL/DML and triggers:

```sql
CREATE TABLE orders (ordernum INT, itemnum INT, quantity INT, storeid STRING)

INSERT INTO orders (ordernum, itemnum, quantity, storeid)
VALUES (1, 10, 5, "s1")

UPDATE orders SET quantity = quantity + 1 WHERE ordernum = 1

DELETE FROM orders WHERE quantity <= 0

CREATE TRIGGER update_totals
AFTER INSERT ON orders
REFERENCING NEW TABLE AS new_orders
DO INSERT INTO totals
SELECT storeid, SUM(quantity) AS total_quantity
FROM new_orders
GROUP BY storeid
```

For more examples, see `aquery-master/src/test/benchmark/**/aquery/*.a`, `aquery-master/src/test/resources/*.a`, and `aquery-master/src/test/triggertests/*.a`.

## Translate `.a` files to `.q`

Run these commands from the repository root unless stated otherwise.

### Without Optimization

Translate `input.a` to `output.q` without optimizer rewrites:

```bash
java -cp target/scala-2.11/aquery.jar edu.nyu.aquery.Aquery -c -o output.q input.a
```

If your current directory is `target/scala-2.11`, use:

```bash
java -cp aquery.jar edu.nyu.aquery.Aquery -c -o output.q input.a
```

Example:

```bash
java -cp target/scala-2.11/aquery.jar edu.nyu.aquery.Aquery \
  -c \
  -o src/test/benchmark/denormalization/aquery/with_denormalization.q \
  src/test/benchmark/denormalization/aquery/with_denormalization.a
```

### With Optimization

Translate `input.a` to `output.q` with all available optimizer rewrites enabled:

```bash
java -cp target/scala-2.11/aquery.jar edu.nyu.aquery.Aquery -c -a 1 -o output.q input.a
```

If your current directory is `target/scala-2.11`, use:

```bash
java -cp aquery.jar edu.nyu.aquery.Aquery -c -a 1 -o output.q input.a
```

Example:

```bash
java -cp target/scala-2.11/aquery.jar edu.nyu.aquery.Aquery \
  -c \
  -a 1 \
  -o src/test/benchmark/denormalization/aquery/with_denormalization.q \
  src/test/benchmark/denormalization/aquery/with_denormalization.a
```

## Run generated q

After translation, load the generated `.q` file in kdb+:

```bash
q src/test/benchmark/denormalization/aquery/with_denormalization.q
```

Or inside a q session:

```q
\l src/test/benchmark/denormalization/aquery/with_denormalization.q
```

## Run Benchmark Experiments

The scripts under `aquery-master/src/test/benchmark` are organized by experiment and DBMS. AQuery entrypoint scripts are usually named `run_aquery.sh`. Run them from `aquery-master` so result CSV files are written to `aquery-master/results`:

```bash
cd aquery-master
bash src/test/benchmark/select_all/run_aquery.sh
```

The shared AQuery benchmark runner is `src/test/benchmark/base_aquery.sh`. It loads one setup `.q` file, then loads one or more query `.q` files. Each query runs 11 times by default, and results are appended to `./results/<output>.csv`:

```bash
bash src/test/benchmark/base_aquery.sh \
  src/test/benchmark/select_all/load_tpch_small.q \
  aquery_small_select_all.csv \
  src/test/function_support/retrieve_need_col/retrieve_a.q:"All Columns"
```

Common experiment entrypoints:

```bash
cd aquery-master

# select all / retrieve-needed-columns
bash src/test/benchmark/select_all/run_aquery.sh

# range query without index
bash src/test/benchmark/range_noindex/run_aquery.sh

# indexed columns vs scan columns
bash src/test/benchmark/scancanwin/run_aquery.sh

# denormalization experiment
bash src/test/benchmark/denormalization/run_aquery.sh

# aggregate trigger experiment
bash src/test/benchmark/trigger/aquery/run_aquery.sh
```

Before running:

- kdb+ `q` must be executable. If `q` is not in `PATH`, set `Q_BIN`, for example `Q_BIN=/Users/tianxin/q/m64/q bash src/test/benchmark/range_noindex/run_aquery.sh`.
- `base_aquery.sh` depends on `bash`, `script`, `bc`, and kdb+. The trigger experiment also uses `python` and `sbt` to compile `.a` files.
- Most AQuery benchmarks already include pre-generated `.q` query files. If you edit the corresponding `.a` files, translate them again before running the benchmark.
- The `denormalization` and `trigger` experiments default to local absolute data paths. Use `DENORM_TBL=...` to point to the denormalized TPCH file, and `TRIGGER_INPUT_CSV=...` to point to the trigger input CSV.
- The same benchmark directories also include scripts such as `run_duckdb.sh` and `run_postgres.sh` for DuckDB/PostgreSQL comparison runs. PostgreSQL scripts usually require database connection setup and data loading first.

## YOU SHOULD BE ALL SET NOW, WHAT FOLLOWS HERE IS OPTIONAL

## Translate `.a` files to `.q` With Selected Optimizations

`-a 1` applies all available optimizations by default. To apply selected optimizations only, pass `-opts` with a comma-separated list:

```bash
java -cp target/scala-2.11/aquery.jar edu.nyu.aquery.Aquery \
  -c \
  -a 1 \
  -opts pushFiltersJoin,makeReorderFilter \
  -o output.q \
  input.a
```

Available optimizer names:

```text
simplifySort
filterBeforeSort
embedSort
simplifyEmbeddedSort
pushFiltersJoin
makeReorderFilter
sortToSortCols
```

### Batch Translate

Translate every `.a` file in the denormalization AQuery directory without optimization:

```bash
for f in src/test/benchmark/denormalization/aquery/*.a; do
  java -cp target/scala-2.11/aquery.jar edu.nyu.aquery.Aquery -c -o "${f%.a}.q" "$f"
done
```

Translate every `.a` file in the denormalization AQuery directory with optimization:

```bash
for f in src/test/benchmark/denormalization/aquery/*.a; do
  java -cp target/scala-2.11/aquery.jar edu.nyu.aquery.Aquery -c -a 1 -o "${f%.a}.q" "$f"
done
```

If the jar has a main-class manifest, this shorter form may also work:

```bash
java -jar target/scala-2.11/aquery.jar -c -o output.q input.a
```

## Advanced option: Build aquery.jar

This is only needed if you modified the Scala source code.

From the repository root:

```bash
sbt assembly
```

Expected output:

```text
target/scala-2.11/aquery.jar
```

If you are already inside `target/scala-2.11`, the jar path is simply:

```text
aquery.jar
```
