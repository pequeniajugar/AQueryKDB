# AQuery Trigger Tests

This folder contains example `.a` programs that exercise the current AQuery trigger implementation.

## Current Trigger Shape

The trigger syntax currently supported by AQuery is:

```sql
CREATE TRIGGER trigger_name
BEFORE | AFTER
INSERT | UPDATE | DELETE
ON source_table
[REFERENCING NEW TABLE AS inserted]
[REFERENCING OLD TABLE AS deleted]
DO <single top-level statement>
```

The current trigger lifecycle DDL supported in AQuery is:

```sql
DROP TRIGGER trigger_name
```

The `DO` body must currently be exactly one top-level AQuery statement. In practice, the most useful supported bodies are:

- `UPDATE ...`
- `DELETE ...`
- `INSERT ...`
- `SELECT ...` inside `INSERT ... SELECT ...`

## How To Use

1. Write a trigger in a `.a` file.
2. Compile it to q:

```bash
sbt "run -c -o path/to/file.q path/to/file.a"
```

3. Load the generated `.q` file in q:

```q
\l path/to/file.q
```

Notes:

- `.a` is AQuery source, not q source. Do not load a `.a` file directly with `\l`.
- The trigger runtime is implemented in `src/main/resources/q/base.q`, which is included in generated `.q` output.
- In this repository, several trigger tests compile successfully. End-to-end q execution may still depend on your local q setup and license availability.

## Runtime Update Strategy

The current trigger runtime does not use one single execution strategy for every data-modification statement. It now mixes row-level updates with whole-table replacement depending on what the generated q runtime can safely identify.

### `INSERT`

- Plain `INSERT` with no ordering requirement uses a row-level append/upsert path.
- `INSERT` that carries ordering semantics still uses whole-table replacement.

In practice this means:

- `INSERT ... VALUES ...`
- `INSERT ... SELECT ...`

normally go through direct `upsert`.

But if the generated insert path first materializes a sorted version of the destination table, the runtime rebuilds the final table and writes it back with `set`.

### `UPDATE`

- `UPDATE` uses a row-level fast path only when the evaluated `WHERE` object already directly identifies rows.
- Otherwise it falls back to the old native kdb functional update path, which computes a new table result and writes it back.

Examples of `WHERE` shapes that are treated as directly locatable:

- a boolean scalar
- a boolean vector
- a row-index list
- a single row dictionary used as a row match key
- the precomputed index/mask forms produced by some helper paths

Examples of `WHERE` shapes that still fall back to whole-table/native update:

- normal predicate expressions such as `c1 > 0`
- compound predicates such as `sym = "AAPL" AND qty < 10`
- more complex expressions that must still be interpreted by kdb at update time

### `DELETE`

- `DELETE` currently stays on the native whole-table path.

This is intentional. A fully row-level delete path was explored, but complex delete shapes were easier to regress semantically than insert/update. For now, delete keeps the older behavior and favors correctness over partial optimization.

### Why The Split Exists

- Row-level paths are faster when the runtime already knows exactly which rows to touch.
- Whole-table replacement is still needed when the operation depends on richer q predicate evaluation or on table reordering semantics.
- The runtime prefers falling back to the old native path rather than guessing and silently changing query behavior.

## Supported Features

### 1. Basic statement-level trigger with no transition tables

You can attach a trigger to one table and perform a fixed action on another table.

Example:

```sql
CREATE TRIGGER trg_sync_table2
AFTER UPDATE ON table1
DO UPDATE table2
   SET qty = qty + 100, note = "updated_by_trigger"
   WHERE id = 1
```

Test case:

- `trigger_sync_tables.a`

Expected outcome:

- `table1` is updated by the main statement.
- The trigger then updates `table2` using the fixed action in the trigger body.
- In this testcase, the matching row in `table2` should have `qty` increased by `100` and `note` changed to `"updated_by_trigger"`.

### 2. `REFERENCING NEW TABLE AS inserted`

You can reference the new rows produced by an `INSERT`/`UPDATE` event through a transition table alias such as `inserted`.

Example:

```sql
CREATE TRIGGER trg_sync_table2
AFTER UPDATE ON table1
REFERENCING NEW TABLE AS inserted
DO UPDATE table2
   SET qty = inserted.qty, note = inserted.note
   WHERE table2.id = inserted.id
```

Test case:

- `trigger_transition_sync.a`

Expected outcome:

- The trigger reads the updated row(s) through `inserted`.
- The matching row in `table2` receives copied values from `inserted`.
- In this testcase, the row with `id = 1` in `table2` should reflect the updated values from `table1`.

### 3. Multi-column mapping

Multiple destination columns can be updated from the transition table in the same trigger.

Test case:

- `trigger_transition_sync.a`

Expected outcome:

- More than one destination column is updated in one trigger firing.
- In this testcase, both `qty` and `note` in `table2` are copied from `inserted`.

### 4. Multi-key matching

The synchronization condition may use multiple key columns.

Example:

```sql
WHERE table2.id = inserted.id
  AND table2.subid = inserted.subid
```

Test case:

- `trigger_transition_sync_multikey.a`

Expected outcome:

- Only rows whose full composite key matches are updated.
- In this testcase, only the `(id, subid) = (1, 10)` row in `table2` should change.
- Other rows should remain unchanged.

### 5. Simple expressions over the transition table

Assignments may use simple expressions derived from one transition table.

Example:

```sql
SET qty = inserted.qty + 1, note = inserted.note
```

Test case:

- `trigger_transition_expr_sync.a`

Expected outcome:

- The trigger computes a derived value from `inserted`.
- In this testcase, the matching row in `table2` should get `qty = inserted.qty + 1` and `note = inserted.note`.

### 6. Mixed target-table and transition-table expressions

Assignments may mix columns from the destination table and the transition table.

Example:

```sql
SET qty = table2.qty + inserted.delta
```

Test case:

- `trigger_transition_mixed_expr_where.a`

Expected outcome:

- The trigger body may reference both `table2` and `inserted` in the same assignment.
- In this testcase, `table2.qty` should increase by `inserted.delta`.
- The update should only happen when the extra predicate `table2.qty < inserted.limit` is true.

### 7. More complex `WHERE` conditions

The trigger-specific `UPDATE`/`DELETE` path now supports conditions beyond simple equality, as long as:

- the body still contains at least one equality match between destination-table keys and transition-table keys, and
- all referenced columns come from the destination table plus exactly one transition table alias

Example:

```sql
WHERE table2.id = inserted.id
  AND table2.qty < inserted.limit
```

Test cases:

- `trigger_transition_mixed_expr_where.a`
- `trigger_transition_delete_sync.a`

Expected outcome:

- Trigger-generated code preserves additional `AND` predicates beyond the key match.
- Non-equality predicates such as `<` are included in the trigger-specific path.

### 8. `REFERENCING OLD TABLE AS deleted`

You can reference old rows through `deleted` for `UPDATE` and `DELETE` triggers.

Example:

```sql
CREATE TRIGGER trg_sync_table2_old
AFTER UPDATE ON table1
REFERENCING OLD TABLE AS deleted
DO UPDATE table2
   SET qty = deleted.qty, note = deleted.note
   WHERE table2.id = deleted.id
```

Test cases:

- `trigger_transition_old_update_sync.a`
- `trigger_transition_delete_sync.a`

Expected outcome:

- The trigger reads old rows through `deleted`.
- In `trigger_transition_old_update_sync.a`, `table2` should receive the pre-update values from `table1`, not the post-update values.
- In `trigger_transition_delete_sync.a`, `table2` should be updated using values from rows deleted out of `table1`.

### 9. `BEFORE UPDATE` / `BEFORE DELETE` old-row binding

`BEFORE` triggers now receive old rows through `OLD TABLE AS deleted` for update/delete events.

This is mainly useful for auditing and pre-delete/pre-update side effects.

Test case:

- `trigger_transition_delete_audit.a`

Expected outcome:

- `deleted` is available before the delete happens.
- The row being deleted from `table1` is copied into `audit`.
- After execution, the deleted row should be absent from `table1` and present in `audit`.

### 10. Delete-driven synchronization to another table

The trigger body may itself be a `DELETE` that is driven by the rows in `deleted`.

Example:

```sql
CREATE TRIGGER trg_sync
AFTER DELETE ON table1
REFERENCING OLD TABLE AS deleted
DO DELETE FROM table2
   WHERE table2.id = deleted.id
```

Related generated-code support is covered by trigger codegen tests, and the folder also includes:

- `trigger_transition_delete_sync.a`

Expected outcome:

- After a delete on `table1`, the trigger can remove matching rows from another table.
- The trigger body behaves like a delete-driven synchronization step.

### 11. Audit-style trigger using `deleted`

You can use `deleted` in a `BEFORE DELETE` trigger body to copy rows into an audit table.

Example:

```sql
CREATE TRIGGER trg_audit_deleted
BEFORE DELETE ON table1
REFERENCING OLD TABLE AS deleted
DO INSERT INTO audit
   SELECT id, qty, note FROM deleted
```

Test case:

- `trigger_transition_delete_audit.a`

Expected outcome:

- The deleted row is captured before removal and inserted into `audit`.
- This is the recommended audit pattern for delete events with the current implementation.

### 12. Drop trigger

You can remove a registered trigger by name.

Example:

```sql
DROP TRIGGER trg_drop_me
```

Test case:

- `trigger_drop.a`

Expected outcome:

- The trigger is created first and then removed with `DROP TRIGGER`.
- Generated q code should include a `.trg.drop[...]` call for the trigger name.

## Test Cases In This Folder

- `trigger_sync_tables.a`: fixed-action statement-level trigger with no transition table.
- `trigger_sync_tables.a`: fixed-action statement-level trigger with no transition table.
  Expected outcome: `table2` changes because of a fixed trigger action, not because of transition-table values.
- `trigger_transition_sync.a`: `AFTER UPDATE` with `NEW TABLE AS inserted`, single-key sync.
  Expected outcome: the matching row in `table2` receives copied values from the updated row in `table1`.
- `trigger_transition_sync_multikey.a`: multi-key transition-table sync.
  Expected outcome: only the exact composite-key match in `table2` changes.
- `trigger_transition_expr_sync.a`: transition-table sync with simple expressions such as `inserted.qty + 1`.
  Expected outcome: the destination row receives computed values, not just direct copies.
- `trigger_transition_mixed_expr_where.a`: mixed destination/transition expressions plus more complex `WHERE`.
  Expected outcome: the trigger updates only rows satisfying both the key match and the extra predicate.
- `trigger_transition_old_update_sync.a`: `AFTER UPDATE` with `OLD TABLE AS deleted`.
  Expected outcome: `table2` receives the old pre-update values from `table1`.
- `trigger_transition_delete_sync.a`: `AFTER DELETE` with `OLD TABLE AS deleted`.
  Expected outcome: `table2` is synchronized from rows deleted out of `table1`.
- `trigger_transition_delete_audit.a`: `BEFORE DELETE` auditing using `deleted`.
  Expected outcome: the deleted row is copied into `audit` before it is removed from `table1`.
- `trigger_drop.a`: create a trigger and then remove it with `DROP TRIGGER`.
  Expected outcome: generated q code includes trigger creation followed by `.trg.drop[...]`.
- `test.a`: not a trigger test; a simple update example kept in this folder.
  Expected outcome: no trigger behavior; only a plain update.

## Current Limitations / Not Yet Supported

The trigger implementation is still intentionally narrow. The following are not fully supported yet:

- `BEFORE INSERT` / `BEFORE UPDATE` mutation semantics that change the rows being written in-place.
- Using both `NEW TABLE AS inserted` and `OLD TABLE AS deleted` together in one transition-aware trigger body.
- Arbitrary multi-statement trigger bodies such as `DO BEGIN ... END ...`.
- Row-level trigger syntax such as `FOR EACH ROW`, `NEW.col`, or `OLD.col`.
- Full semantic validation for every invalid trigger combination.
  Example: some invalid combinations should eventually fail earlier and with clearer diagnostics.
- Arbitrarily complex trigger bodies with joins, nested local queries, or multiple transition tables mixed together.
- Trigger lifecycle DDL such as `DROP TRIGGER`, `ALTER TRIGGER`, `ENABLE TRIGGER`, or `DISABLE TRIGGER` in AQuery syntax.
- `DROP TRIGGER` is supported, but `ALTER TRIGGER`, `ENABLE TRIGGER`, `DISABLE TRIGGER`, and richer forms such as `DROP TRIGGER IF EXISTS` are not yet supported.
- A complete end-to-end q runtime test suite inside this folder.
  The `.a -> .q` compilation path is covered here, but actual q execution may depend on your local q installation and license state.

## Practical Guidance

If you want the most reliable trigger shape with the current implementation, prefer this pattern:

```sql
CREATE TRIGGER trg_name
AFTER UPDATE ON source_table
REFERENCING NEW TABLE AS inserted
DO UPDATE target_table
   SET target_col = target_table.target_col + inserted.delta
   WHERE target_table.id = inserted.id
```

or this delete/audit pattern:

```sql
CREATE TRIGGER trg_name
BEFORE DELETE ON source_table
REFERENCING OLD TABLE AS deleted
DO INSERT INTO audit_table
   SELECT * FROM deleted
```
