"""
extract.py
----------
Copies the three source Excel files from a given folder into data/
so the rest of the pipeline always reads from a single known location.
"""

import os
import shutil
import pandas as pd

EXPECTED_FILES = {
    "Products.xlsx": "Products.xlsx",
    "Sales.xlsx":    "Sales.xlsx",
    "Stocks.xlsx":   "Stocks.xlsx",
}

RAW_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data")


def extract_files(source_folder: str) -> dict:
    os.makedirs(RAW_DIR, exist_ok=True)
    paths = {}

    for source_name, dest_name in EXPECTED_FILES.items():
        source_path = os.path.join(source_folder, source_name)
        dest_path   = os.path.join(RAW_DIR, dest_name)

        if not os.path.exists(source_path):
            raise FileNotFoundError(
                f"[EXTRACT] Could not find '{source_name}' in '{source_folder}'.\n"
                f"  Expected: {source_path}\n"
                f"  Please check your SOURCE_FOLDER in main.py."
            )

        shutil.copy2(source_path, dest_path)
        table_key = source_name.replace(".xlsx", "").lower()
        paths[table_key] = dest_path
        print(f"[EXTRACT] {source_name} → {dest_path}")

    return paths


def read_raw(paths: dict) -> dict:
    frames = {}
    for key, path in paths.items():
        df = pd.read_excel(path, dtype=str)
        print(f"[EXTRACT] Loaded '{key}': {df.shape[0]:,} rows × {df.shape[1]} cols")
        frames[key] = df
    return frames