import argparse
import csv
import subprocess
import tempfile
import time
from pathlib import Path


DEFAULT_Q_BIN = "/Users/tianxin/q/m64/q"
Q_RESULT_PREFIX = "RESULT|"

EMPLOYEE_COLS = ["ssnum", "name", "lat", "long", "hundreds1", "hundreds2"]


def q_symbol(value: str) -> str:
    return "`" + value.replace("`", "")


def parse_csv(csv_path: Path, has_header: bool):
    start = time.perf_counter()
    rows = []
    with csv_path.open("r", newline="") as f:
        reader = csv.reader(f)
        if has_header:
            next(reader, None)
        for row in reader:
            if len(row) < 6:
                continue
            rows.append(
                (
                    int(row[0]),
                    q_symbol(row[1]),
                    int(row[2]),
                    int(row[3]),
                    int(row[4]),
                    int(row[5]),
                )
            )
    end = time.perf_counter()
    return rows, end - start


def build_row_insert_q(rows, out_q: Path):
    insert_lines = [
        "employees:([] ssnum:`int$(); name:`symbol$(); lat:`int$(); long:`int$(); hundreds1:`int$(); hundreds2:`int$());",
        "wall0:.z.p;",
    ]
    for ssnum, name, lat, long_v, hundreds1, hundreds2 in rows:
        insert_lines.append(
            "`employees upsert "
            f"({ssnum};{name};{lat};{long_v};{hundreds1};{hundreds2});"
        )
    insert_lines.extend(
        [
            "wall1:.z.p;",
            'resp:(\"f\"$(wall1-wall0))%1000000000f;',
            'rowsInserted:count employees;',
            '-1 \"RESULT|row_insert|\",string resp,\"|\",string rowsInserted;',
            "show 5#employees;",
            "exit 0;",
        ]
    )
    out_q.write_text("\n".join(insert_lines) + "\n", encoding="utf-8")


def build_direct_load_q(csv_path: Path, has_header: bool, out_q: Path):
    lines_expr = (
        "read0 hsym `$csvFile"
        if has_header
        else '("ssnum,name,lat,long,hundreds1,hundreds2"),read0 hsym `$csvFile'
    )
    script = f"""
csvFile:"{csv_path}";
wall0:.z.p;
employees:("ISIIII";enlist ",") 0: {lines_expr};
wall1:.z.p;
resp:("f"$(wall1-wall0))%1000000000f;
rowsLoaded:count employees;
-1 "RESULT|direct_load|",string resp,"|",string rowsLoaded;
show 5#employees;
exit 0;
""".strip()
    out_q.write_text(script + "\n", encoding="utf-8")


def run_q(q_bin: str, script_path: Path):
    proc = subprocess.run(
        [q_bin, str(script_path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return proc.stdout


def parse_result(stdout: str, expected_label: str):
    for line in stdout.splitlines():
        if line.startswith(Q_RESULT_PREFIX):
            _, label, seconds, count = line.split("|")
            if label == expected_label:
                return float(seconds), int(count)
    raise RuntimeError(f"did not find {expected_label} result line in q output:\n{stdout}")


def main():
    parser = argparse.ArgumentParser(
        description="Benchmark direct kdb csv load vs Python-read + row-by-row kdb insert."
    )
    parser.add_argument("--file", required=True, help="Path to employees CSV.")
    parser.add_argument("--q-bin", default=DEFAULT_Q_BIN)
    parser.add_argument("--has-header", action="store_true")
    args = parser.parse_args()

    csv_path = Path(args.file).resolve()
    rows, python_read_time = parse_csv(csv_path, args.has_header)

    with tempfile.TemporaryDirectory(prefix="employees_row_insert_") as tmp_dir:
        tmp_dir = Path(tmp_dir)
        row_insert_q = tmp_dir / "employees_row_insert.q"
        direct_load_q = tmp_dir / "employees_direct_load.q"

        build_row_insert_q(rows, row_insert_q)
        build_direct_load_q(csv_path, args.has_header, direct_load_q)

        row_insert_stdout = run_q(args.q_bin, row_insert_q)
        direct_load_stdout = run_q(args.q_bin, direct_load_q)

    row_insert_time, row_insert_count = parse_result(row_insert_stdout, "row_insert")
    direct_load_time, direct_load_count = parse_result(direct_load_stdout, "direct_load")

    print(f"python_read_seconds={python_read_time:.6f}")
    print(f"row_insert_seconds={row_insert_time:.6f}")
    print(f"row_insert_rows={row_insert_count}")
    print(f"direct_load_seconds={direct_load_time:.6f}")
    print(f"direct_load_rows={direct_load_count}")


if __name__ == "__main__":
    main()
