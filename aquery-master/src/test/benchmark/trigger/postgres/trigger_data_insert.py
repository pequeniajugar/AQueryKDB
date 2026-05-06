import argparse
import csv
import os
import time
from pathlib import Path

try:
    import psycopg2
except ModuleNotFoundError:
    psycopg2 = None
from tqdm import tqdm


# PostgreSQL configuration. Environment variables override these defaults.
POSTGRES_CONFIG = {
    "host": os.environ.get("PGHOST", "localhost"),
    "port": int(os.environ.get("PGPORT", "5432")),
    "user": os.environ.get("PGUSER", "postgres"),
    "password": os.environ.get("PGPASSWORD", "pwd"),
    "dbname": os.environ.get("PGDATABASE", "store_new_10_5"),
}

# CSV columns must be:
# ordernum,itemnum,quantity,price,storeid,vendorid
DEFAULT_TBL_FILE_PATH = "/Users/tianxin/projects/nyu/ms1/research/dbtunning_experiements/data_generation/store/triggers_input.csv"
COLUMN_COUNT = 6


def get_connection():
    if psycopg2 is None:
        raise SystemExit(
            "Missing dependency: psycopg2. Install psycopg2 or psycopg2-binary in "
            "the Python environment used to run this benchmark."
        )
    return psycopg2.connect(**POSTGRES_CONFIG)


def clear_orders(conn, initial_max_ordernum: int):
    with conn.cursor() as cursor:
        cursor.execute(
            "DELETE FROM orders WHERE ordernum > %s;",
            (initial_max_ordernum,),
        )
    conn.commit()


def parse_order_row(row, line_no: int):
    fields = [field.strip() for field in row]
    if len(fields) < COLUMN_COUNT:
        raise ValueError(
            f"line {line_no}: expected at least {COLUMN_COUNT} columns "
            "(ordernum,itemnum,quantity,price,storeid,vendorid)"
        )
    return fields[:COLUMN_COUNT]


def single_row_insert_experiment(file_path: str, conn):
    """
    Insert orders one by one and measure time.

    The trigger computes quantity * price using the inserted price column.
    """
    insert_query = """
        INSERT INTO orders (
            ordernum, itemnum, quantity, price, storeid, vendorid
        ) VALUES (%s, %s, %s, %s, %s, %s)
    """

    start_real_time = time.time()
    start_cpu_time = time.process_time()

    inserted_rows = 0
    with conn.cursor() as cursor, open(file_path, "r", newline="") as f:
        reader = csv.reader(f)
        next(reader, None)
        for line_no, row in enumerate(tqdm(reader, desc="Inserting rows"), start=2):
            cursor.execute(insert_query, parse_order_row(row, line_no))
            inserted_rows += 1
        conn.commit()

    end_real_time = time.time()
    end_cpu_time = time.process_time()

    return end_real_time - start_real_time, end_cpu_time - start_cpu_time, inserted_rows


def ensure_insert_results_csv(csv_path: Path):
    if not csv_path.exists():
        csv_path.parent.mkdir(parents=True, exist_ok=True)
        with csv_path.open("w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["dbms", "label", "iteration", "execution_time", "response_time"])


def append_insert_result(csv_path: Path, label: str, iteration: int, exec_time: float, resp_time: float):
    with csv_path.open("a", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["postgres", label, iteration, f"{exec_time:.6f}", f"{resp_time:.6f}"])


def run_insert_experiment(tbl_file_path: str, mode: str):
    root_dir = Path(__file__).resolve().parents[5]
    results_csv = root_dir / "results" / "postgres_aggregate_triggers_insert.csv"
    ensure_insert_results_csv(results_csv)

    label = "with_trigger_insert" if mode == "with_trigger" else "without_trigger_insert"

    init_conn = get_connection()
    with init_conn.cursor() as init_cur:
        init_cur.execute("SELECT COALESCE(MAX(ordernum), 0) FROM orders;")
        initial_max_ordernum = init_cur.fetchone()[0] or 0
    init_conn.close()

    print(f"\n=== Row-by-row INSERT experiment ({mode}, PostgreSQL) ===")

    for run in range(1, 12):
        print(f"\n[INSERT - {mode}] Run #{run}")
        conn = get_connection()

        clear_orders(conn, initial_max_ordernum)

        resp_time, exec_time, inserted_rows = single_row_insert_experiment(
            tbl_file_path, conn
        )

        with conn.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) FROM orders;")
            row_count = cursor.fetchone()[0]

        print(f"  Response Time: {resp_time:.4f}s")
        print(f"  Execution Time: {exec_time:.4f}s")
        print(f"  Rows Inserted (this run): {inserted_rows}")
        print(f"  Rows in orders after run: {row_count}")

        append_insert_result(results_csv, label, run, exec_time, resp_time)

        conn.close()


def main():
    parser = argparse.ArgumentParser(
        description="Row-by-row INSERT experiment for simplified aggregate triggers on PostgreSQL."
    )
    parser.add_argument(
        "--mode",
        choices=["with_trigger", "without_trigger"],
        required=True,
        help="Whether to run the insertion experiment with or without triggers enabled.",
    )
    parser.add_argument(
        "--file",
        default=DEFAULT_TBL_FILE_PATH,
        help="CSV file containing ordernum,itemnum,quantity,price,storeid,vendorid rows.",
    )
    args = parser.parse_args()

    run_insert_experiment(args.file, args.mode)


if __name__ == "__main__":
    main()
