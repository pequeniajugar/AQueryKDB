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

## Build aquery.jar

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

### With Selected Optimizations

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

## Run generated q

After translation, load the generated `.q` file in kdb+:

```bash
q src/test/benchmark/denormalization/aquery/with_denormalization.q
```

Or inside a q session:

```q
\l src/test/benchmark/denormalization/aquery/with_denormalization.q
```
