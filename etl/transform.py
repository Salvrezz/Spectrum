"""
etl/transform.py
All cleaning rules live here. The guiding principle for this whole module:
 
    >>> NEVER DROP A ROW. <<<
 
Every function below either keeps a row as-is or replaces a blank with an
explicit, visible placeholder ("ORAIMO", "UNCATEGORISED", "UNSPECIFIED-<n>",
"No Movement Data", etc.) so it still shows up in Power BI slicers, tables
and totals instead of silently disappearing.
"""
 
import re
import numpy as np
import pandas as pd
 
 
# --------------------------------------------------------------------------- #
# Generic cleaning helpers
# --------------------------------------------------------------------------- #
 
def _to_blank_aware_str(series: pd.Series) -> pd.Series:
    """Trim whitespace and turn NaN/'nan'/'None'/'' into a true empty string."""
    s = series.astype(str).str.strip()
    s = s.replace({"nan": "", "None": "", "NaT": "", "<NA>": ""})
    return s
 
 
def clean_category(df: pd.DataFrame, col: str) -> pd.DataFrame:
    """Blank category -> 'UNCATEGORISED'. Always uppercased for consistent grouping."""
    df = df.copy()
    df[col] = _to_blank_aware_str(df[col])
    df.loc[df[col].eq(""), col] = "UNCATEGORISED"
    df[col] = df[col].str.upper()
    return df
 
 
def clean_brand(df: pd.DataFrame, category_col: str, brand_col: str) -> pd.DataFrame:
    """
    Blank-brand rule:
      - If category == ORAIMO and brand is blank -> 'ORAIMO'
        (sits as its own row alongside Oraimo Cables, Oraimo Charger, etc.)
      - Otherwise blank -> '<CATEGORY> - UNBRANDED'
    Always uppercased so 'Oraimo Battery' / 'ORAIMO BATTERY' match.
    """
    df = df.copy()
    df[brand_col] = _to_blank_aware_str(df[brand_col])
 
    cat = df[category_col].astype(str).str.strip().str.upper()
    is_oraimo = cat.eq("ORAIMO")
    is_blank = df[brand_col].eq("")
 
    df.loc[is_blank & is_oraimo, brand_col] = "ORAIMO"
    df.loc[is_blank & ~is_oraimo, brand_col] = (
        df.loc[is_blank & ~is_oraimo, category_col].astype(str).str.strip().str.upper()
        + " - UNBRANDED"
    )
    df[brand_col] = df[brand_col].str.upper().str.strip()
    return df
 
 
def clean_product_no(df: pd.DataFrame, col: str) -> pd.DataFrame:
    """Blank Product No -> 'UNSPECIFIED-<row index>' so the row stays unique & traceable."""
    df = df.copy()
    df[col] = _to_blank_aware_str(df[col])
    blank_mask = df[col].eq("")
    df.loc[blank_mask, col] = [f"UNSPECIFIED-{i}" for i in df.index[blank_mask]]
    return df
 
 
def clean_text_field(df: pd.DataFrame, col: str, default: str) -> pd.DataFrame:
    """Generic: blank text field -> a given default label, never dropped."""
    df = df.copy()
    df[col] = _to_blank_aware_str(df[col])
    df.loc[df[col].eq(""), col] = default
    return df
 
 
def parse_date(df: pd.DataFrame, col: str) -> pd.DataFrame:
    """
    Parse dd/mm/yyyy dates. Anything that fails to parse becomes NaT (blank),
    which Power BI will render as blank rather than an error. The row is kept.
    """
    df = df.copy()
    df[col] = pd.to_datetime(df[col], format="%d/%m/%Y", errors="coerce")
    return df
 
 
# --------------------------------------------------------------------------- #
# 1. PRODUCT.xlsx
# --------------------------------------------------------------------------- #
 
PRODUCT_KEEP_COLS = [
    "Product No.", "Product Name", "Product Type", "Tier 1 Category", "Brand",
    "SKU No.", "Unit of Measure", "Purchase Price", "Wholesale Price",
    "Retail Price", "Online Price", "Product Barcode",
]
 
 
def transform_product(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df = clean_category(df, "Category")
    df = clean_brand(df, "Category", "Brand")
    df = clean_product_no(df, "Product No.")
    df.rename(columns={"Category": "Tier 1 Category"}, inplace=True)
    return df[PRODUCT_KEEP_COLS]
 
 
# --------------------------------------------------------------------------- #
# 2. SALES.xlsx
# --------------------------------------------------------------------------- #
 
def transform_sales(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df = parse_date(df, "Date")
    df = clean_category(df, "Tier 1 Category")
    df = clean_brand(df, "Tier 1 Category", "Brand")
    df = clean_product_no(df, "Product NO.")
    df = clean_text_field(df, "Sales Channels", "UNSPECIFIED")
    df["Sales Channels"] = df["Sales Channels"].str.upper().str.strip()
    df = clean_text_field(df, "Warehouse", "UNSPECIFIED WAREHOUSE")
    df = clean_text_field(df, "Store", "UNSPECIFIED STORE")
    return df
 
 
# --------------------------------------------------------------------------- #
# 3. STOCK_BALANCE.xlsx  (wide -> long unpivot, one row per Product No + Warehouse)
# --------------------------------------------------------------------------- #
 
def unpivot_stock_balance(df: pd.DataFrame) -> pd.DataFrame:
    """
    STOCK_BALANCE.xlsx has one column-triplet per warehouse:
        '<Warehouse>- Stock on Hand'
        '<Warehouse>-Unit Cost'
        '<Warehouse>-Inventory Asset Value'
    plus a 'Summary-*' triplet (the cross-warehouse total, excluded here to
    avoid double counting once we go long).
 
    Output: one row per Product No. + Warehouse with Stock on Hand, Unit Cost,
    Inventory Asset Value. Rows where Stock on Hand == 0 are KEPT (a 0-stock
    row is meaningful — it's an out-of-stock SKU, used on the restock page).
    """
    df = df.copy()
    id_cols = [
        "Product No.", "Product Name", "SKU No.",
        "Category", "Brand", "Unit of Measurement",
    ]
 
    soh_cols = [c for c in df.columns if re.search(r"Stock on Hand$", c)]
 
    frames = []
    for c in soh_cols:
        wh = re.sub(r"\s*-\s*Stock on Hand$", "", c).strip()
        if wh.lower() == "summary":
            continue  # skip the cross-warehouse summary columns
 
        cost_col = f"{wh}-Unit Cost"
        val_col = f"{wh}-Inventory Asset Value"
 
        sub = df[id_cols].copy()
        sub["Warehouse"] = wh
        sub["Stock on Hand"] = pd.to_numeric(df[c], errors="coerce").fillna(0)
        sub["Unit Cost"] = pd.to_numeric(df.get(cost_col, np.nan), errors="coerce")
        sub["Inventory Asset Value"] = pd.to_numeric(df.get(val_col, np.nan), errors="coerce")
        frames.append(sub)
 
    long_df = pd.concat(frames, ignore_index=True)
 
    long_df = clean_category(long_df, "Category")
    long_df = clean_brand(long_df, "Category", "Brand")
    long_df = clean_product_no(long_df, "Product No.")
    long_df.rename(columns={"Category": "Tier 1 Category"}, inplace=True)
 
    return long_df
 
 
# --------------------------------------------------------------------------- #
# 4. STOCK_BALANCE_DETAILS.xlsx  (movement log)
# --------------------------------------------------------------------------- #
 
STOCK_MOVEMENT_KEEP_COLS = [
    "Product No.", "Product Name", "SKU No.", "Tier 1 Category", "Brand",
    "Unit of Measure", "Type", "Document No.", "Date", "Warehouse",
    "Inbound-Quantity", "Outbound-Quantity", "Closing-Quantity", "Closing-Cost",
]
 
 
def transform_stock_movement(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df = parse_date(df, "Date")
    df = clean_category(df, "Category")
    df = clean_brand(df, "Category", "Brand")
    df = clean_product_no(df, "Product No.")
    df = clean_text_field(df, "Type", "UNSPECIFIED MOVEMENT")
    df = clean_text_field(df, "Warehouse", "UNSPECIFIED WAREHOUSE")
    df.rename(columns={"Category": "Tier 1 Category"}, inplace=True)
    return df[STOCK_MOVEMENT_KEEP_COLS]
 
 
# --------------------------------------------------------------------------- #
# 5. Derived: stg_stock_aging
# --------------------------------------------------------------------------- #
 
def _aging_bucket(days) -> str:
    if pd.isna(days) or days < 0:
        return "No Movement Data"
    if days <= 15:
        return "0-15 Days"
    if days <= 30:
        return "16-30 Days"
    if days <= 45:
        return "31-45 Days"
    if days <= 60:
        return "46-60 Days"
    if days <= 90:
        return "61-90 Days"
    return "90+ Days"
 
 
def build_stock_aging(
    stock_long: pd.DataFrame,
    stock_movement: pd.DataFrame,
    run_date,
    aging_threshold_days: int = 45,
) -> pd.DataFrame:
    """
    One row per Product No. + Warehouse (same grain as stock_long).
 
    Last Movement Date = MAX(Date) across ALL movement types (in or out)
    for that Product No. + Warehouse, from STOCK_BALANCE_DETAILS.
 
    If a Product No. + Warehouse pair has NO movement record at all, the
    Last Movement Date and Inventory Age Days are left BLANK (NaT / NaN),
    not zero, and the row gets bucket = 'No Movement Data'. The row is
    still kept in full.
    """
    last_move = (
        stock_movement.dropna(subset=["Date"])
        .groupby(["Product No.", "Warehouse"], as_index=False)["Date"]
        .max()
        .rename(columns={"Date": "Last Movement Date"})
    )
 
    aging = stock_long.merge(last_move, on=["Product No.", "Warehouse"], how="left")
 
    run_ts = pd.Timestamp(run_date)
    aging["Inventory Age Days"] = (run_ts - aging["Last Movement Date"]).dt.days
 
    aging["Aging Bucket"] = aging["Inventory Age Days"].apply(_aging_bucket)
    aging["Is Aged 45 Plus"] = aging["Inventory Age Days"].apply(
        lambda d: bool(pd.notna(d) and d >= aging_threshold_days)
    )
 
    aging_cols = [
        "Product No.", "Product Name", "Tier 1 Category", "Brand", "Warehouse",
        "Stock on Hand", "Inventory Asset Value", "Last Movement Date",
        "Inventory Age Days", "Aging Bucket", "Is Aged 45 Plus",
    ]
    return aging[aging_cols]
 
 
# --------------------------------------------------------------------------- #
# Orchestration helper
# --------------------------------------------------------------------------- #
 
def transform_all(raw: dict, run_date) -> dict:
    product = transform_product(raw["product"])
    sales = transform_sales(raw["sales"])
    stock_long = unpivot_stock_balance(raw["stock_balance"])
    stock_movement = transform_stock_movement(raw["stock_balance_details"])
    stock_aging = build_stock_aging(stock_long, stock_movement, run_date)
 
    return {
        "stg_product": product,
        "stg_sales": sales,
        "stg_stock_balance": stock_long,
        "stg_stock_movement": stock_movement,
        "stg_stock_aging": stock_aging,
    }