"""
etl/extract.py
Reads the 4 raw Excel exports from data/raw/ and returns them as DataFrames.
No cleaning happens here — that's transform.py's job. This step is purely
"get the data into pandas, exactly as it is in the file."
 
Expected files in data/raw/:
    PRODUCT.xlsx
    SALES.xlsx
    STOCK_BALANCE.xlsx
    STOCK_BALANCE_DETAILS.xlsx
"""
 
import os
import pandas as pd
 
RAW_DIR = os.path.join("data", "raw")
 
 
def _read(filename: str) -> pd.DataFrame:
    path = os.path.join(RAW_DIR, filename)
    print(f"[extract] reading {path} ...")
    df = pd.read_excel(path, sheet_name="Sheet1")
    print(f"[extract]   -> {df.shape[0]:,} rows x {df.shape[1]} cols")
    return df
 
 
def extract_product() -> pd.DataFrame:
    return _read("PRODUCT.xlsx")
 
 
def extract_sales() -> pd.DataFrame:
    return _read("SALES.xlsx")
 
 
def extract_stock_balance() -> pd.DataFrame:
    return _read("STOCK_BALANCE.xlsx")
 
 
def extract_stock_balance_details() -> pd.DataFrame:
    return _read("STOCK_BALANCE_DETAILS.xlsx")
 
 
def extract_all() -> dict:
    """Convenience helper used by main.py"""
    return {
        "product": extract_product(),
        "sales": extract_sales(),
        "stock_balance": extract_stock_balance(),
        "stock_balance_details": extract_stock_balance_details(),
    }
 