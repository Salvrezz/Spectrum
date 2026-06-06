# Spectrum — Inventory Intelligence Pipeline

An end-to-end ETL pipeline that transforms raw retail inventory and sales data into a structured MySQL database with analytical views connected to Power BI dashboards.

## What it does

Processes 283,393 rows across three Excel source files — products, sales, and stock movements — cleans and restructures them into MySQL staging tables, and exposes 14 analytical SQL views covering inventory health, sales performance, procurement alerts, and stock velocity.

## Tech stack

- Python 3.x — ETL pipeline
- pandas — data cleaning and transformation
- SQLAlchemy + pymysql — database connection and loading
- MySQL — staging tables and analytical views
- Power BI — dashboard layer connected to views

## Project structure

\\\
spectrum/
├── .env                    # DB credentials (not tracked)
├── data/                   # Raw and processed files (not tracked)
├── db/
│   └── connection.py       # SQLAlchemy engine
├── etl/
│   ├── extract.py          # Read source Excel files
│   ├── transform.py        # Clean and reshape data
│   └── load.py             # Load to MySQL and refresh views
├── sql/
│   ├── create_tables.sql   # Staging table DDL
│   └── views/              # 14 analytical SQL views
├── main.py                 # Pipeline orchestrator
└── requirements.txt
\\\

## Setup

1. Clone the repository
2. Create and activate a virtual environment
\\\ash
python -m venv .venv
.venv\Scripts\activate
\\\
3. Install dependencies
\\\ash
pip install -r requirements.txt
\\\
4. Create a \.env\ file in the root folder with your MySQL credentials
\\\
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=spectrum_db
\\\
5. Add your three Excel files into the \data/\ folder
\\\
data/
├── Products.xlsx
├── Sales.xlsx
└── Stocks.xlsx
\\\

## Running the pipeline

Create database tables (run once):
\\\ash
python main.py --setup
\\\

Run the full pipeline:
\\\ash
python main.py
\\\

Refresh views only (without reloading data):
\\\ash
python main.py --views-only
\\\

## Analytical views

| View | Purpose |
|---|---|
| v_product_master | Clean product dimension table |
| v_stock_levels | Current stock quantity per product per warehouse |
| v_days_in_stock | Days on shelf with age bucket classification |
| v_low_stock_alert | Products with 7, 14, and 30 day stock cover alerts |
| v_fast_movers | High velocity products with reorder flags |
| v_slow_movers | Dead stock and capital at risk |
| v_sales_performance | Transaction-level sales KPIs |
| v_kpi_summary | Headline metrics for dashboard cards |
| v_kpi_revenue_trend | Daily and monthly revenue trends |
| v_kpi_category_brand | Performance by category and brand |
| v_kpi_warehouse | Revenue and stock health by location |
| v_kpi_stock_health | Capital at risk by age bucket |
| v_kpi_channel_split | Retail vs wholesale comparison |
| v_kpi_top_products | Product rankings with reorder intelligence |

## Power BI

Connect Power BI to MySQL using localhost and spectrum_db. Import only the views — never the stg_ staging tables directly. The dashboard covers five pages: executive overview, sales performance, inventory health, procurement alerts, and product deep dive.

## Refreshing data

Drop new Excel files into the \data/\ folder and run \python main.py\. The pipeline truncates and reloads all tables and refreshes all views automatically.
