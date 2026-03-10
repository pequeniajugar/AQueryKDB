# Editable aquery.jar

This folder is an editable copy of `aquery.jar`.

## Structure
- `unpacked/`: extracted jar contents (class files/resources)
- `aquery-editable-base.jar`: original backup copy
- `rebuild_jar.sh`: rebuild script

## Edit + Rebuild
1. Edit files under `unpacked/` (for example `unpacked/q/base.q`).
2. Rebuild:
   ```bash
   ./rebuild_jar.sh
   ```
3. Output jar:
   - default: `aquery-editable.jar`
   - custom path: `./rebuild_jar.sh /path/to/custom.jar`

## Run with rebuilt jar
```bash
java -cp /absolute/path/to/aquery-editable.jar edu.nyu.aquery.Aquery -c your_query.a
```
