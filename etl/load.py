"""
etl/load.py
Writes the 5 cleaned tables (4 staging + 1 derived aging table) to
spectrum_db on MySQL. Each run fully replaces the table contents
(if_exists="replace") so the dashboard always reflects the latest export.
 
Speed notes:
- CSV snapshots are OFF by default (SAVE_SNAPSHOTS = False below). Writing
  a ~90,000-row CSV on top of the MySQL write roughly doubles the time for
  stg_sales for very little benefit. Set SAVE_SNAPSHOTS = True if you want
  them back for auditing.
- We do NOT use method="multi". For pymysql, method="multi" builds giant
  multi-row INSERT statements that can stall or exceed MySQL's
  max_allowed_packet on large/wide tables (this is the usual cause of the
  pipeline appearing to "hang" on stg_sales). The default executemany-style
  insert is faster and more reliable here.
- chunksize is set higher (10,000) since each insert is now a single-row
  statement executed in batches, not one giant statement.
"""
 
import os
import pandas as pd
from db.connection import get_engine
 
PROCESSED_DIR = os.path.join("data", "processed")
 
# Set to True if you want a CSV copy of each table written to data/processed/
SAVE_SNAPSHOTS = False
 
 
def _save_csv_snapshot(name: str, df: pd.DataFrame):
    os.makedirs(PROCESSED_DIR, exist_ok=True)
    path = os.path.join(PROCESSED_DIR, f"{name}.csv")
    df.to_csv(path, index=False)
    print(f"[load]   snapshot saved -> {path}")
 
 
def load_table(name: str, df: pd.DataFrame, engine, chunksize: int = 10000):
    print(f"[load] writing {name} ({df.shape[0]:,} rows x {df.shape[1]} cols) ...")
    df.to_sql(
        name,
        con=engine,
        if_exists="replace",
        index=False,
        chunksize=chunksize,
    )
    if SAVE_SNAPSHOTS:
        _save_csv_snapshot(name, df)
    print(f"[load]   -> done: {name}")
 
 
def load_all(tables: dict):
    """
    tables: dict produced by transform.transform_all(), e.g.
        {
          "stg_product": df,
          "stg_sales": df,
          "stg_stock_balance": df,
          "stg_stock_movement": df,
          "stg_stock_aging": df,
        }
    """
    engine = get_engine()
    for name, df in tables.items():
        load_table(name, df, engine)
    print("[load] all tables loaded into spectrum_db.")