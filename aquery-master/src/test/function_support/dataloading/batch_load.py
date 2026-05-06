import argparse
import subprocess
import tempfile
import time
from pathlib import Path


DEFAULT_DATA_FILE = "/path/to/employees.csv"
DEFAULT_TEMP_DIR = "./batches"
DEFAULT_Q_BIN = "/Users/tianxin/q/m64/q"
DEFAULT_BATCH_SIZES = [100000000]
DEFAULT_RUNS = 1
Q_RESULT_PREFIX = "RESULT|"


def ensure_dir(path: Path):
    path.mkdir(parents=True, exist_ok=True)


def clear_batches(temp_dir: Path):
    for batch_file in temp_dir.glob("batch_*"):
        batch_file.unlink()


def split_file(data_file: Path, temp_dir: Path, batch_size: int, has_header: bool):
    clear_batches(temp_dir)
    with data_file.open("r", newline="") as src:
        if has_header:
            next(src, None)
        batch_index = 0
        line_count = 0
        out = None
        try:
            for line in src:
                if line_count % batch_size == 0:
                    if out is not None:
                        out.close()
                    out_path = temp_dir / f"batch_{batch_index:06d}.csv"
                    out = out_path.open("w", newline="")
                    batch_index += 1
                out.write(line)
                line_count += 1
        finally:
            if out is not None:
                out.close()


def q_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build_run_q(batch_files, out_q: Path):
    header = "ssnum,name,lat,long,hundreds1,hundreds2"
    batch_expr = "(" + ";".join(f"hsym `$\"{str(path)}\"" for path in batch_files) + ")"
    script = f"""
employeeHeader:{q_string(header)};
batchFiles:{batch_expr};

employees:([] ssnum:`int$(); name:`symbol$(); lat:`int$(); long:`int$(); hundreds1:`int$(); hundreds2:`int$());

loadBatch:{{
  [fileHandle]
  lines:read0 fileHandle;
  if[0=count lines; :()];
  rows:("ISIIII";enlist ",") 0: (enlist employeeHeader),lines;
  `employees upsert rows;
  ::;
  }};

loadBatch each batchFiles;
rowCount:count employees;

-1 "RESULT|",string rowCount;
show 5#employees;
exit 0;
""".strip()
    out_q.write_text(script + "\n", encoding="utf-8")


def parse_result(stdout: str):
    for line in stdout.splitlines():
        if line.startswith(Q_RESULT_PREFIX):
            _, rows_s = line.split("|")
            return int(rows_s)
    raise RuntimeError(f"did not find result line in q output:\n{stdout}")


def run_q_script(q_bin: str, script_path: Path):
    proc = subprocess.run(
        [q_bin, str(script_path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return parse_result(proc.stdout)


def main():
    parser = argparse.ArgumentParser(
        description="Batch-load benchmark for employees on q/kdb+."
    )
    parser.add_argument("--file", default=DEFAULT_DATA_FILE, help="Path to employees CSV.")
    parser.add_argument("--temp-dir", default=DEFAULT_TEMP_DIR, help="Directory for split batch files.")
    parser.add_argument("--q-bin", default=DEFAULT_Q_BIN)
    parser.add_argument("--runs", type=int, default=DEFAULT_RUNS)
    parser.add_argument("--has-header", action="store_true")
    parser.add_argument(
        "--batch-sizes",
        nargs="+",
        type=int,
        default=DEFAULT_BATCH_SIZES,
        help="Batch sizes to test.",
    )
    args = parser.parse_args()

    data_file = Path(args.file).resolve()
    temp_dir = Path(args.temp_dir).resolve()
    ensure_dir(temp_dir)

    for batch_size in args.batch_sizes:
        print(f"=== Testing with BATCH_SIZE={batch_size} ===")
        split_file(data_file, temp_dir, batch_size, args.has_header)
        batch_files = sorted(temp_dir.glob("batch_*.csv"))

        for run in range(1, args.runs + 1):
            print(f"Run #{run} with batch size {batch_size}")

            with tempfile.TemporaryDirectory(prefix="q_batch_load_") as tmp_dir:
                run_q = Path(tmp_dir) / "batch_load.q"
                build_run_q(batch_files, run_q)
                start_real = time.time()
                start_cpu = time.process_time()
                row_count = run_q_script(args.q_bin, run_q)
                exec_time = time.process_time() - start_cpu
                resp_time = time.time() - start_real

            print(f"Real Time: {resp_time:.6f}s")
            print(f"Execution Time: {exec_time:.6f}s")
            print(f"Inserted Rows: {row_count}")


if __name__ == "__main__":
    main()
