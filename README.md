# Inventory Data Pipeline

### Spectrum Innovation Technologies Ltd
 
A production Python ETL pipeline and Power BI reporting suite that integrates product, sales and stock movement data from the Kilimax ERP system into a MySQL data warehouse, powering 8 executive and operational dashboards used by leadership to drive inventory and sales decisions.
 
---
 
## Project Overview
 
Before this pipeline existed, reconciling stock and sales data across the business was a manual, error prone process. This project automates the full data lifecycle from raw ERP exports to interactive Power BI dashboards, tracking inventory ageing, slow moving stock, sales channel performance and restock signals across 1,869 SKUs and 76 warehouses.
 
---
 
## Key Results
 
- Processes **283,398 records** across 4 source systems with zero record loss
- Tracks **1,869 SKUs** across **76 warehouses** in a single unified data model
- Flags stock idle for **45+ days** and brands with **≥10% slow moving inventory**
- Delivers **8 Power BI dashboards** used directly in COO level business reviews
- Eliminates manual stock and sales reconciliation through automated ETL
---
 
## Tech Stack
 
| Layer | Tools |
|---|---|
| Data Source | Kilimax ERP (Excel exports) |
| Language | Python 3.11+ |
| Data Processing | Pandas, NumPy |
| Database | MySQL (spectrum_db) |
| ORM / Connector | SQLAlchemy, PyMySQL |
| BI & Reporting | Power BI Desktop (DAX, Power Query) |
| Version Control | Git, GitHub |
| IDE | VS Code |
 
---
 
## Project Structure
 
```
spectrum/
├── .env                        # DB credentials (not tracked)
├── data/
│   ├── raw/                    # Source Excel exports from Kilimax ERP
│   └── processed/              # Optional CSV snapshots (not tracked)
├── db/
│   └── connection.py           # SQLAlchemy engine
├── etl/
│   ├── extract.py              # Read source Excel files
│   ├── transform.py            # Clean, reshape and build aging table
│   └── load.py                 # Load to MySQL
├── sql/
│   └── create_tables.sql       # Staging table DDL (documentation)
├── main.py                     # Pipeline orchestrator
└── requirements.txt
```
 
---
 
## Data Pipeline
 
```
Kilimax ERP (Excel)
        │
        ▼
   [ extract.py ]
   Read 4 raw files
        │
        ▼
  [ transform.py ]
  Clean & reshape
  Blank handling
  Wide to long unpivot (76 warehouses)
  Build inventory aging table
        │
        ▼
   [ load.py ]
   Write 5 tables to MySQL
        │
        ▼
   spectrum_db (MySQL)
        │
        ▼
   Power BI Dashboards
```
 
### Staging Tables
 
| Table | Source | Rows | Description |
|---|---|---|---|
| stg_product | PRODUCT.xlsx | 1,869 | Product master from ERP |
| stg_sales | SALES.xlsx | 89,488 | Sales transactions by channel |
| stg_stock_balance | STOCK_BALANCE.xlsx | 136,496 | Stock on hand per SKU per warehouse |
| stg_stock_movement | STOCK_BALANCE_DETAILS.xlsx | 198,089 | Full movement log (in/out/transfer) |
| stg_stock_aging | Derived | 136,496 | Aging days, buckets and slow moving flags |
 
---
 
## Inventory Ageing Framework
 
Stock ageing is computed per SKU per warehouse using:
 
```
Inventory Age (Days) = Run Date − Last Movement Date
```
 
Where Last Movement Date is the most recent transaction date across all movement types (Opening Stock, Receive Stock, Transfer Stock, Store Orders, Deliveries) from stg_stock_movement.
 
Items are then segmented into ageing buckets:
 
| Bucket | Days |
|---|---|
| Healthy | 0 to 15 days |
| Watch | 16 to 30 days |
| Review | 31 to 45 days |
| Slow Moving | 46 to 60 days |
| Critical | 61 to 90 days |
| Dead Stock | 90+ days |
| No Movement Data | No transaction history found |
 
A brand level slow moving ratio flags any brand where 10% or more of its stocked SKUs are aged 45+ days.
 
```
Slow Moving Ratio % = SKUs Aged 45+ Days / Total SKUs In Stock
```
 
---
 
## Power BI Dashboards (8 Pages)
 
| Page | Description |
|---|---|
| Executive Dashboard | Business wide KPIs, inventory value, sales trend, brand health |
| Sales Performance | Net sales, gross margin, channel split (Wholesale vs Retail) |
| Oraimo Dashboard | Full Oraimo sub brand analytics, ageing table, channel performance |
| Phones Dashboard | Brand grouped phone inventory and sales (iPhone, Samsung, Tecno etc.) |
| Solar Products | Itel Solar, Villaon and other solar category stock and sales |
| Accessories | Non Oraimo accessories inventory health and ageing |
| Inventory Health | Overstocked vs restock needed, days of cover per brand |
| Management Alert | Business wide 45 day flag view, excludes Oraimo (has its own page) |
 
---
 
## Blank Handling Rules
 
No rows are dropped at any stage of the pipeline. Every blank field receives an explicit visible placeholder:
 
| Field | Rule |
|---|---|
| Brand (under Oraimo category) | Replaced with "ORAIMO" |
| Brand (other categories) | Replaced with "CATEGORY NAME - UNBRANDED" |
| Product No. | Replaced with "UNSPECIFIED-{row index}" |
| Tier 1 Category | Replaced with "UNCATEGORISED" |
| Date (unparseable) | Kept as NULL, displays as blank in Power BI |
| Movement Type | Replaced with "UNSPECIFIED MOVEMENT" |
 
---
 
## Setup & Usage
 
### Prerequisites
 
- Python 3.11+
- MySQL 8.0+ with spectrum_db database created
- Power BI Desktop
### Installation
 
```bash
# Clone the repo
git clone https://github.com/yourusername/spectrum.git
cd spectrum
 
# Create and activate virtual environment
python -m venv .venv
.venv\Scripts\activate        # Windows
source .venv/bin/activate     # Mac/Linux
 
# Install dependencies
pip install -r requirements.txt
```
 
### Environment Setup
 
```bash
# Copy the example env file and fill in your MySQL credentials
copy .env.example .env
```
 
```env
DB_USER=root
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=3306
DB_NAME=spectrum_db
```
 
### Database Setup (once only)
 
```sql
CREATE DATABASE IF NOT EXISTS spectrum_db;
SET GLOBAL local_infile = 1;
```
 
### Run the Pipeline
 
```bash
# Place your 4 raw Excel files in data/raw/ then run:
python main.py
```
 
Expected output:
 
```
=== Spectrum ETL run — ageing calculated as of 2026-06-11 ===
 
--- STEP 1: EXTRACT ---
[extract] reading data\raw\PRODUCT.xlsx ...
[extract]   -> 1,869 rows x 30 cols
...
 
--- STEP 2: TRANSFORM ---
[transform] stg_stock_aging: 136,496 rows x 11 cols
...
 
--- STEP 3: LOAD ---
[load] writing stg_sales (89,488 rows x 18 cols) ...
[load]   -> done: stg_sales
...
 
=== ETL complete. Refresh Power BI to pick up the new data. ===
```
 
### Refresh Power BI
 
After `python main.py` completes, open your Power BI file and click **Home → Refresh**. All 8 dashboards update automatically with the new data.
 
---
 
## Data Model (Power BI Star Schema)
 
```
              dim_date
                 │
    ┌────────────┼────────────┐
    │                         │
fact_sales              fact_stock_aging
    │                         │
    └────────────┬────────────┘
                 │
         dim_brand   dim_warehouse   dim_category
```
 
---
 
## Skills Demonstrated
 
- ETL pipeline development (Extract, Transform, Load)
- Data warehouse design and MySQL schema management
- Data cleaning, blank handling and data quality engineering
- Inventory analytics and ageing metric design
- Power BI data modeling (star schema, DAX measures, Power Query)
- ERP data integration (Kilimax)
- Business intelligence and executive dashboard delivery
- Supply chain and retail/wholesale analytics
---
 
## Author
 
**Rock Izuazu**
Data Analyst | BI & Inventory Analytics
[LinkedIn](https://linkedin.com/in/yourprofile) · [GitHub](https://github.com/yourusername)