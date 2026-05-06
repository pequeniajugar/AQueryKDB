import argparse
import csv
import subprocess
import tempfile
from pathlib import Path


DEFAULT_TBL_FILE_PATH = "/Users/tianxin/projects/nyu/ms1/research/dbtunning_experiements/data_generation/store/triggers_input.csv"
DEFAULT_RESULTS_CSV = "results/aquery_aggregate_triggers_insert.csv"
Q_RESULT_PREFIX = "RESULT|"


def ensure_insert_results_csv(csv_path: Path):
    if not csv_path.exists():
        csv_path.parent.mkdir(parents=True, exist_ok=True)
        with csv_path.open("w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["dbms", "label", "iteration", "execution_time", "response_time"])


def append_insert_result(csv_path: Path, label: str, iteration: int, exec_time: float, resp_time: float):
    with csv_path.open("a", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["aquery", label, iteration, f"{exec_time:.6f}", f"{resp_time:.6f}"])


def compile_aquery(repo_root: Path, src_a: Path, out_q: Path):
    cmd = [
        "sbt",
        f"run -c -o {out_q} {src_a}",
    ]
    subprocess.run(cmd, cwd=repo_root, check=True)


def sql_string_literal(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build_insert_a(csv_path: Path, out_a: Path):
    lines = []
    with csv_path.open("r", newline="") as f:
        reader = csv.reader(f)
        next(reader, None)
        for row in reader:
            if len(row) < 5:
                continue
            ordernum, itemnum, quantity, storeid, vendorid = row[:5]
            lines.append(
                "INSERT INTO orders VALUES("
                f"{int(ordernum)}, {int(itemnum)}, {int(quantity)}, "
                f"{sql_string_literal(storeid)}, {sql_string_literal(vendorid)})"
            )
    out_a.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_run_q(setup_q: Path, common_q: Path, insert_q: Path, mode: str, out_q: Path):
    lines = [
        f'system "l {setup_q}";',
        f'system "l {common_q}";',
        ".bench.configureMode[`$\"" + mode + "\"];",
        "wall0:.z.p;",
        f'stats:\\ts system "l {insert_q}";',
        "wall1:.z.p;",
        'resp:(\"f\"$(wall1-wall0))%1000000000f;',
        'exec:(\"f\"$first stats)%1000f;',
        'inserted:count ordersInput;',
        'rowCount:count orders;',
        '-1 "RESULT|",string resp,"|",string exec,"|",string inserted,"|",string rowCount;',
        "exit 0;",
    ]
    out_q.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_result(stdout: str):
    for line in stdout.splitlines():
        if line.startswith(Q_RESULT_PREFIX):
            _, resp_s, exec_s, inserted_s, rows_s = line.split("|")
            return float(resp_s), float(exec_s), int(inserted_s), int(rows_s)
    raise RuntimeError(f"did not find result line in q output:\n{stdout}")


def single_row_insert_experiment(
    repo_root: Path,
    q_bin: str,
    setup_q: Path,
    common_q: Path,
    insert_q: Path,
    mode: str,
):
    with tempfile.TemporaryDirectory(prefix="aquery_insert_run_") as tmp_dir:
        run_q = Path(tmp_dir) / f"insert_{mode}.q"
        build_run_q(setup_q, common_q, insert_q, mode, run_q)
        proc = subprocess.run(
            [q_bin, str(run_q)],
            cwd=repo_root,
            check=True,
            capture_output=True,
            text=True,
        )
    return parse_result(proc.stdout)


def run_insert_experiment(
    repo_root: Path,
    tbl_file_path: Path,
    mode: str,
    q_bin: str,
    setup_q: Path,
    common_q: Path,
    runs: int,
    results_csv: Path,
):
    ensure_insert_results_csv(results_csv)

    label = "with_trigger_insert" if mode == "with_trigger" else "without_trigger_insert"

    with tempfile.TemporaryDirectory(prefix="aquery_insert_src_") as tmp_dir:
        insert_a = Path(tmp_dir) / "orders_insert.a"
        insert_q = Path(tmp_dir) / "orders_insert.q"
        build_insert_a(tbl_file_path, insert_a)
        compile_aquery(repo_root, insert_a, insert_q)

        print(f"\n=== Row-by-row INSERT experiment ({mode}, AQuery) ===")

        for run in range(1, runs + 1):
            print(f"\n[INSERT - {mode}] Run #{run}")
            resp_time, exec_time, inserted_rows, row_count = single_row_insert_experiment(
                repo_root=repo_root,
                q_bin=q_bin,
                setup_q=setup_q,
                common_q=common_q,
                insert_q=insert_q,
                mode=mode,
            )

            print(f"  Response Time: {resp_time:.4f}s")
            print(f"  Execution Time: {exec_time:.4f}s")
            print(f"  Rows Inserted (this run): {inserted_rows}")
            print(f"  Rows in orders after run: {row_count}")

            append_insert_result(results_csv, label, run, exec_time, resp_time)


def main():
    parser = argparse.ArgumentParser(
        description="Row-by-row INSERT experiment for Aggregate Maintenance (AQuery)."
    )
    parser.add_argument("--mode", choices=["with_trigger", "without_trigger"], required=True)
    parser.add_argument("--file", default=DEFAULT_TBL_FILE_PATH)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--setup-q", required=True)
    parser.add_argument("--common-q", required=True)
    parser.add_argument("--q-bin", default="/Users/tianxin/q/m64/q")
    parser.add_argument("--runs", type=int, default=11)
    parser.add_argument("--results-csv", default=DEFAULT_RESULTS_CSV)
    args = parser.parse_args()

    run_insert_experiment(
        repo_root=Path(args.repo_root).resolve(),
        tbl_file_path=Path(args.file).resolve(),
        mode=args.mode,
        q_bin=args.q_bin,
        setup_q=Path(args.setup_q).resolve(),
        common_q=Path(args.common_q).resolve(),
        runs=args.runs,
        results_csv=Path(args.repo_root).resolve() / args.results_csv,
    )


if __name__ == "__main__":
    main()
