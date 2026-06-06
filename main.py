"""
main.py
-------
Entry point for the Spectrum inventory ETL pipeline.

Usage
-----
  # Full run (extract → transform → load → views):
  python main.py

  # First-time setup only (create DB tables):
  python main.py --setup

  # Just refresh views without re-loading data:
  python main.py --views-only

Configuration
-------------
  Set SOURCE_FOLDER below to the folder that contains your three Excel files:
    Products.xlsx
    Sales.xlsx
    Stocks.xlsx
"""

import argparse
import os
import sys
from sqlalchemy import text

# ---------------------------------------------------------------
# !! SET THIS TO THE FOLDER WHERE YOUR EXCEL FILES LIVE !!
# e.g. Windows: r"C:\Users\YourName\Downloads"
#      Mac/Linux: "/home/yourname/Downloads"
# ---------------------------------------------------------------
SOURCE_FOLDER = r"C:\Users\OWNER\Documents\Spectrum\data"


# ---------------------------------------------------------------
# Internal imports
# ---------------------------------------------------------------
sys.path.insert(0, os.path.dirname(__file__))

from db.connection import get_engine, test_connection
from etl.extract   import extract_files, read_raw
from etl.transform import transform_all
from etl.load      import load_all, run_views


# ---------------------------------------------------------------
# Setup: run create_tables.sql once to build the schema
# ---------------------------------------------------------------
def run_setup():
    print("\n[SETUP] Creating database and tables...")
    engine = get_engine()
    sql_path = os.path.join(os.path.dirname(__file__), "sql", "create_tables.sql")

    with open(sql_path, "r") as f:
        sql = f.read()

    # Split on semicolons and run each statement individually
    with engine.begin() as conn:
        for stmt in sql.split(";"):
            stmt = stmt.strip()
            if stmt:
                conn.execute(text(stmt))

    print("[SETUP] Tables created successfully.")


# ---------------------------------------------------------------
# Full pipeline
# ---------------------------------------------------------------
def run_pipeline(source_folder: str):
    print("\n" + "=" * 60)
    print("  SPECTRUM — Inventory ETL Pipeline")
    print("=" * 60)

    if not test_connection():
        print("\n[ABORT] Fix your .env DB credentials and try again.")
        sys.exit(1)

    print("\n--- READ ---")
    data_dir = os.path.join(os.path.dirname(__file__), "data")
    paths = {
        "products": os.path.join(data_dir, "Products.xlsx"),
        "sales":    os.path.join(data_dir, "Sales.xlsx"),
        "stocks":   os.path.join(data_dir, "Stocks.xlsx"),
    }
    for key, path in paths.items():
        if not os.path.exists(path):
            print(f"[ABORT] Missing file: {path}")
            sys.exit(1)
        print(f"[READ] Found {key}: {path}")

    raw_frames = read_raw(paths)

    print("\n--- TRANSFORM ---")
    clean_frames = transform_all(raw_frames)

    print("\n--- LOAD ---")
    load_all(clean_frames)

    print("\n--- VIEWS ---")
    run_views()

    print("\n" + "=" * 60)
    print("  Pipeline complete. Connect Power BI to your views.")
    print("=" * 60 + "\n")


# ---------------------------------------------------------------
# CLI
# ---------------------------------------------------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Spectrum Inventory ETL")
    parser.add_argument(
        "--setup",
        action="store_true",
        help="Create database tables (run once before first pipeline run)",
    )
    parser.add_argument(
        "--views-only",
        action="store_true",
        help="Refresh MySQL views without re-loading data",
    )
    args = parser.parse_args()

    if args.setup:
        run_setup()
    elif args.views_only:
        print("\n[VIEWS] Refreshing views only...")
        if test_connection():
            run_views()
    else:
        run_pipeline(SOURCE_FOLDER)
