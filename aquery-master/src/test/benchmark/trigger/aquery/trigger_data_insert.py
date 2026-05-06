import argparse
import csv
import subprocess
import tempfile
import time
from pathlib import Path


DEFAULT_TBL_FILE_PATH = "/Users/tianxin/projects/nyu/ms1/research/dbtunning_experiements/data_generation/store/triggers_input.csv"


def ensure_results_csv(csv_path: Path):
    if not csv_path.exists():
        csv_path.parent.mkdir(parents=True, exist_ok=True)
        with csv_path.open("w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["dbms", "label", "iteration", "execution_time", "response_time"])


def append_result(csv_path: Path, label: str, iteration: int, exec_time: float, resp_time: float):
    with csv_path.open("a", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["aquery", label, iteration, f"{exec_time:.6f}", f"{resp_time:.6f}"])


def q_symbol(value: str) -> str:
    escaped = value.strip().replace("\\", "\\\\").replace('"', '\\"')
    return f'`$"{escaped}"'


def build_insert_q(csv_path: Path, out_q: Path):
    lines = []
    with csv_path.open("r", newline="") as f:
        reader = csv.reader(f)
        next(reader, None)
        for line_no, row in enumerate(reader, start=2):
            fields = [field.strip() for field in row]
            if len(fields) < 6:
                raise ValueError(
                    f"line {line_no}: expected 6 columns "
                    "(ordernum,itemnum,quantity,price,storeid,vendorid)"
                )
            ordernum, itemnum, quantity, price, storeid, vendorid = fields[:6]
            lines.append(
                ".aq.insert[`orders;orders;();([]"
                f"ordernum:enlist {int(ordernum)};"
                f"itemnum:enlist {int(itemnum)};"
                f"quantity:enlist {int(quantity)};"
                f"price:enlist {float(price)};"
                f"storeid:enlist {q_symbol(storeid)};"
                f"vendorid:enlist {q_symbol(vendorid)})];"
            )
    out_q.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return len(lines)


def build_run_q(setup_q: Path, insert_q: Path, out_q: Path):
    out_q.write_text(
        "\n".join(
            [
                f'system "l {setup_q}";',
                f'system "l {insert_q}";',
                "exit 0;",
            ]
        )
        + "\n",
        encoding="utf-8",
    )


def run_insert_once(repo_root: Path, q_bin: str, setup_q: Path, insert_q: Path):
    with tempfile.TemporaryDirectory(prefix="aquery_trigger_insert_") as tmp_dir:
        run_q = Path(tmp_dir) / "run_insert.q"
        build_run_q(setup_q, insert_q, run_q)
        start_real = time.perf_counter()
        start_cpu = time.process_time()
        proc = subprocess.run(
            [q_bin, str(run_q)],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        resp_time = time.perf_counter() - start_real
        exec_time = time.process_time() - start_cpu
        if proc.returncode != 0:
            raise RuntimeError(
                "q insert run failed\n"
                f"command: {q_bin} {run_q}\n"
                f"stdout:\n{proc.stdout}\n"
                f"stderr:\n{proc.stderr}"
            )
    return resp_time, exec_time


def run_insert_experiment(args):
    repo_root = Path(args.repo_root).resolve()
    csv_path = Path(args.file).resolve()
    setup_q = Path(args.setup_q).resolve()
    results_csv = repo_root / args.results_csv
    ensure_results_csv(results_csv)

    label = "with_trigger_insert" if args.mode == "with_trigger" else "without_trigger_insert"

    with tempfile.TemporaryDirectory(prefix="aquery_trigger_insert_src_") as tmp_dir:
        tmp = Path(tmp_dir)
        insert_q = tmp / "orders_insert.q"
        expected_rows = build_insert_q(csv_path, insert_q)

        print(f"\n=== Row-by-row INSERT experiment ({args.mode}, AQuery) ===")
        for run in range(1, args.runs + 1):
            print(f"\n[INSERT - {args.mode}] Run #{run}")
            resp_time, exec_time = run_insert_once(
                repo_root=repo_root,
                q_bin=args.q_bin,
                setup_q=setup_q,
                insert_q=insert_q,
            )
            print(f"  Response Time: {resp_time:.4f}s")
            print(f"  Execution Time: {exec_time:.4f}s")
            print(f"  Rows Inserted (this run): {expected_rows}")
            append_result(results_csv, label, run, exec_time, resp_time)


def main():
    parser = argparse.ArgumentParser(
        description="AQuery row-by-row insert benchmark for simplified aggregate triggers."
    )
    parser.add_argument("--mode", choices=["with_trigger", "without_trigger"], required=True)
    parser.add_argument("--file", default=DEFAULT_TBL_FILE_PATH)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--setup-q", required=True)
    parser.add_argument("--q-bin", default="q")
    parser.add_argument("--runs", type=int, default=11)
    parser.add_argument(
        "--results-csv",
        default="results/aquery_aggregate_triggers_insert.csv",
        help="Path relative to repo root.",
    )
    run_insert_experiment(parser.parse_args())


if __name__ == "__main__":
    main()
