"""
main.py
Pipeline orchestrator. Run from the project root:
 
    python main.py
 
Steps:
  1. Extract  - read the 4 raw Excel files from data/raw/
  2. Transform- clean, unpivot, build aging table (no rows ever dropped)
  3. Load     - write 5 tables to spectrum_db (MySQL) + CSV snapshots
 
Set RUN_DATE below if you want to "freeze" the ageing calculation to a
specific date (e.g. for re-running on yesterday's export). By default it
uses today's date.
"""
 
import datetime
from etl.extract import extract_all
from etl.transform import transform_all
from etl.load import load_all
 
# Override this if you need to recompute ageing as-of a past date,
# e.g. RUN_DATE = datetime.date(2026, 6, 9)
RUN_DATE = datetime.date.today()
 
 
def main():
    print(f"=== Spectrum ETL run — ageing calculated as of {RUN_DATE} ===")
 
    print("\n--- STEP 1: EXTRACT ---")
    raw = extract_all()
 
    print("\n--- STEP 2: TRANSFORM ---")
    clean = transform_all(raw, RUN_DATE)
    for name, df in clean.items():
        print(f"[transform] {name}: {df.shape[0]:,} rows x {df.shape[1]} cols")
 
    print("\n--- STEP 3: LOAD ---")
    load_all(clean)
 
    print("\n=== ETL complete. Refresh Power BI to pick up the new data. ===")
 
 
if __name__ == "__main__":
    main()
 