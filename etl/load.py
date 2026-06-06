import os
import pandas as pd
from sqlalchemy import text
from db.connection import get_engine

SQL_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "sql")

TABLE_MAP = {
    "products": "stg_products",
    "sales":    "stg_sales",
    "stocks":   "stg_stocks",
}


def load_table(df: pd.DataFrame, table_name: str, engine) -> None:
    with engine.begin() as conn:
        conn.execute(text(f"TRUNCATE TABLE `{table_name}`;"))

    df.to_sql(
        name=table_name,
        con=engine,
        if_exists="append",
        index=False,
        chunksize=100,
        method=None,
    )
    print(f"[LOAD] '{table_name}' loaded: {len(df):,} rows")


def load_all(clean_frames: dict) -> None:
    engine = get_engine()

    for key, df in clean_frames.items():
        table = TABLE_MAP[key]
        load_table(df, table, engine)

    print("[LOAD] All tables loaded successfully.")


def run_views(engine=None) -> None:
    if engine is None:
        engine = get_engine()

    views_dir = os.path.join(SQL_DIR, "views")
    sql_files = sorted(f for f in os.listdir(views_dir) if f.endswith(".sql"))

    with engine.begin() as conn:
        for fname in sql_files:
            fpath = os.path.join(views_dir, fname)
            with open(fpath, "r") as fh:
                sql = fh.read()

            statements = [s.strip() for s in sql.split(";") if s.strip()]
            for stmt in statements:
                conn.execute(text(stmt))

            print(f"[VIEWS] Applied: {fname}")

    print("[VIEWS] All views refreshed.")