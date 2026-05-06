# AQuery jar and kdb+ quick start

This directory contains the packaged AQuery jar

## Install kdb+

Official references:

- kdb+ Personal Edition download: https://kx.com/kdb-personal-edition-download
- kdb+ install guide: https://code.kx.com/q/learn/install/

For non-commercial use, sign up for kdb+ Personal Edition on the KX download page. KX provides the platform zip and a license file, usually `kc.lic`.

On macOS, the downloaded platform zip is normally `m64.zip`. Install it under `$HOME/q`:

```bash
cd ~/Downloads
unzip m64.zip -d "$HOME/q"
```

Put the license file in `QHOME`:

```bash
cp /path/to/kc.lic "$HOME/q/kc.lic"
```

Authorize and run q from Terminal:

```bash
cd "$HOME"
spctl --add q/m64/q
xattr -d com.apple.quarantine q/m64/q
q/m64/q
```

You should see a `q)` prompt. Exit with:

```q
\\
```

Optional shell setup:

```bash
export QHOME="$HOME/q"
export PATH="$QHOME/m64:$PATH"
```

Then run:

```bash
q
```

For Linux, use the matching official zip, commonly `l64.zip`, unzip it to `$HOME/q`, place `kc.lic` in `$HOME/q`, and run:

```bash
$HOME/q/l64/q
```

## Build aquery.jar(not needed unless you modified the scala code)

From the repository root:

```bash
sbt assembly
```

Expected output:

```bash
aquery.jar
```

## Translate `.a` files to `.q`

Use `aquery.jar` with the compiler mode:

```bash
java -cp aquery.jar edu.nyu.aquery.Aquery -c -o output.q input.a
```

Example:

```bash
java -cp aquery.jar edu.nyu.aquery.Aquery \
  -c \
  -o src/test/benchmark/denormalization/aquery/with_denormalization.q \
  src/test/benchmark/denormalization/aquery/with_denormalization.a
```

Translate every `.a` file in the denormalization AQuery directory:

```bash
for f in src/test/benchmark/denormalization/aquery/*.a; do
  java -cp aquery.jar edu.nyu.aquery.Aquery -c -o "${f%.a}.q" "$f"
done
```

If the jar has a main-class manifest, this shorter form may also work:

```bash
java -jar aquery.jar -c -o output.q input.a
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
