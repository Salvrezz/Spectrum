"""
transform.py
------------
Cleans and transforms the three raw DataFrames into
analysis-ready tables ready for MySQL loading.

Rules applied per table
------------------------
Products : drop 14 empty/useless columns, rename, cast types, strip whitespace
Sales    : drop 3 derivable columns, rename Product NO. → product_no,
           parse dates, cast margin % string → float
Stocks   : drop 4 redundant columns, parse dates, cast numeric columns,
           standardize movement type labels
"""

import os
import pandas as pd
import numpy as np

PROCESSED_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _strip_str_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Strip leading/trailing whitespace from all string columns."""
    for col in df.select_dtypes(include="object").columns:
        df[col] = df[col].str.strip()
    return df


def _to_float(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series, errors="coerce")


def _to_int(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series, errors="coerce").astype("Int64")  # nullable int


def _parse_date(series: pd.Series) -> pd.Series:
    """Parse dd/mm/yyyy strings into datetime."""
    return pd.to_datetime(series, format="%d/%m/%Y", errors="coerce")


# ---------------------------------------------------------------------------
# Products
# ---------------------------------------------------------------------------

PRODUCTS_DROP = [
    "Parent Category",
    "Shelf Life In Days",
    "Early Warning Days",
    "Other Unit",
    "Quantity",
    "Product Barcode",
    "Sales Channel",
    "Online Price",
    "AttributeGroup:AttributeValue1",
    "AttributeGroup:AttributeValue2",
    "AttributeGroup:AttributeValue3",
    "Remarks",
    "Product Type",       # only value = 'Goods'
    "Has multiple UOM",   # only value = 'N'
    "Has Expiration Date.",
    "Has Batch No.",
    "Unit",               # duplicate of Unit of Measure
]

PRODUCTS_RENAME = {
    "Product Name":    "product_name",
    "Product No.":     "product_no",
    "Category":        "category",
    "Brand":           "brand",
    "Has Specifications": "has_specifications",
    "Purchase Tax Rate":  "purchase_tax_rate",
    "Sale Tax Rate":      "sale_tax_rate",
    "Has Serial No.":     "has_serial_no",
    "Unit of Measure":    "unit_of_measure",
    "SKU No.":            "sku_no",
    "Purchase Price":     "purchase_price",
    "Wholesale Price":    "wholesale_price",
    "Retail Price":       "retail_price",
}


def transform_products(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df = _strip_str_columns(df)

    # Drop columns that exist in the file (ignore any already missing)
    drop_existing = [c for c in PRODUCTS_DROP if c in df.columns]
    df.drop(columns=drop_existing, inplace=True)

    df.rename(columns=PRODUCTS_RENAME, inplace=True)

    # Cast numeric
    for col in ["purchase_tax_rate", "sale_tax_rate", "purchase_price", "wholesale_price", "retail_price"]:
        df[col] = _to_float(df[col])

    # Boolean-like flags → clean Y/N
    for col in ["has_specifications", "has_serial_no"]:
        if col in df.columns:
            df[col] = df[col].str.upper().str.strip()

    # Drop fully duplicate rows
    df.drop_duplicates(subset=["product_no"], keep="first", inplace=True)

    print(f"[TRANSFORM] products → {df.shape[0]:,} rows × {df.shape[1]} cols")
    return df


# ---------------------------------------------------------------------------
# Sales
# ---------------------------------------------------------------------------

SALES_DROP = [
    "Product Type",          # low-value; only Standard / Service
    "Net Sales Unit Price",  # derivable: Net Sales Amount / Net Sales Quantity
    "Net Sales Unit Cost",   # derivable: Net Sales Cost  / Net Sales Quantity
]

SALES_RENAME = {
    "Date":                   "sale_date",
    "Product":                "product_name",
    "Product NO.":            "product_no",       # NOTE: different spelling in source
    "Tier 1 Category":        "category",
    "Brand":                  "brand",
    "Warehouse":              "warehouse",
    "Store":                  "store",
    "Sales Channels":         "sales_channel",
    "Refund Quantity":        "refund_quantity",
    "Refund Order Count":     "refund_order_count",
    "Net Sales Amount":       "net_sales_amount",
    "Net Sales Quantity":     "net_sales_quantity",
    "Net Sales Cost":         "net_sales_cost",
    "Net Sales Gross Profit": "gross_profit",
    "Net Sales Gross Margin": "gross_margin_pct",
}


def transform_sales(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df = _strip_str_columns(df)

    drop_existing = [c for c in SALES_DROP if c in df.columns]
    df.drop(columns=drop_existing, inplace=True)

    df.rename(columns=SALES_RENAME, inplace=True)

    # Parse date
    df["sale_date"] = _parse_date(df["sale_date"])

    # Gross margin: "37.15%" → 37.15 (stored as float, represents %)
    df["gross_margin_pct"] = (
        df["gross_margin_pct"]
        .str.replace("%", "", regex=False)
        .pipe(_to_float)
    )

    # Numeric casts
    for col in ["net_sales_amount", "net_sales_cost", "gross_profit"]:
        df[col] = _to_float(df[col])

    for col in ["refund_quantity", "refund_order_count", "net_sales_quantity"]:
        df[col] = _to_int(df[col])

    # Standardise channel label
    df["sales_channel"] = df["sales_channel"].str.title()   # Retail / Wholesale

    print(f"[TRANSFORM] sales    → {df.shape[0]:,} rows × {df.shape[1]} cols")
    return df


# ---------------------------------------------------------------------------
# Stocks
# ---------------------------------------------------------------------------

STOCKS_DROP = [
    "Attribute",         # 100% null
    "Unit of Measure",   # already in products
    "SKU No.",           # already in products
    "Inbound-Unit Cost",  # derivable
    "Outbound-Unit Cost", # derivable
    "Closing-Unit Cost",  # derivable
]

STOCKS_RENAME = {
    "Product No.":      "product_no",
    "Product Name":     "product_name",
    "Category":         "category",
    "Brand":            "brand",
    "Type":             "movement_type",
    "Document No.":     "document_no",
    "Date":             "movement_date",
    "Warehouse":        "warehouse",
    "Inbound-Quantity":  "inbound_qty",
    "Inbound-Cost":      "inbound_cost",
    "Outbound-Quantity": "outbound_qty",
    "Outbound-Cost":     "outbound_cost",
    "Closing-Quantity":  "closing_qty",
    "Closing-Cost":      "closing_cost",
}

# Standardise movement type labels to clean values
MOVEMENT_TYPE_MAP = {
    "opening stock":       "Opening Stock",
    "opening":             "Opening Stock",
    "stock in":            "Stock In",
    "receive stock":       "Stock In",
    "store orders":        "Store Transfer Out",
    "transfer stock":      "Transfer",
    "deliveries":          "Delivery Out",
    "retail sales returns":"Sales Return",
    "sales returns":       "Sales Return",
    "stock out":           "Stock Out",
    "purchase returns":    "Purchase Return",
}


def transform_stocks(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df = _strip_str_columns(df)

    drop_existing = [c for c in STOCKS_DROP if c in df.columns]
    df.drop(columns=drop_existing, inplace=True)

    df.rename(columns=STOCKS_RENAME, inplace=True)

    # Parse date
    df["movement_date"] = _parse_date(df["movement_date"])

    # Numeric casts
    for col in ["inbound_cost", "outbound_cost", "closing_cost"]:
        df[col] = _to_float(df[col])

    for col in ["inbound_qty", "outbound_qty", "closing_qty"]:
        df[col] = _to_int(df[col])

    # Standardise movement type
    df["movement_type"] = (
        df["movement_type"]
        .str.lower()
        .str.strip()
        .map(MOVEMENT_TYPE_MAP)
        .fillna("Other")
    )

    print(f"[TRANSFORM] stocks   → {df.shape[0]:,} rows × {df.shape[1]} cols")
    return df


# ---------------------------------------------------------------------------
# Save processed files (optional — for audit trail)
# ---------------------------------------------------------------------------

def save_processed(frames: dict):
    """Save cleaned DataFrames to data/processed/ as CSV for audit."""
    os.makedirs(PROCESSED_DIR, exist_ok=True)
    for name, df in frames.items():
        path = os.path.join(PROCESSED_DIR, f"{name}_clean.csv")
        df.to_csv(path, index=False)
        print(f"[TRANSFORM] Saved processed CSV → {path}")


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

def transform_all(raw_frames: dict) -> dict:
    """
    Run all three transforms.

    Args:
        raw_frames: dict {"products": df, "sales": df, "stocks": df}

    Returns:
        dict {"products": df_clean, "sales": df_clean, "stocks": df_clean}
    """
    clean = {
        "products": transform_products(raw_frames["products"]),
        "sales":    transform_sales(raw_frames["sales"]),
        "stocks":   transform_stocks(raw_frames["stocks"]),
    }
    save_processed(clean)
    return clean
