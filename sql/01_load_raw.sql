-- =============================================================
-- 01_load_raw.sql
-- Step 1: Create a raw table and load the two source files.
-- Everything is loaded as TEXT so no row fails on import.
-- Types are converted later, in 02_validation.sql.
-- =============================================================

CREATE TABLE raw_sales (
    invoice       TEXT,
    stock_code    TEXT,
    description   TEXT,
    quantity      TEXT,
    invoice_date  TEXT,
    price         TEXT,
    customer_id   TEXT,
    country       TEXT,
    source_sheet  TEXT
);

-- Data was imported with pgAdmin's Import/Export tool
-- (Right-click raw_sales -> Import/Export Data -> CSV, Header ON):
--   retail_2009_2010.csv
--   retail_2010_2011.csv
-- Source: UCI Online Retail II dataset (CC BY 4.0)

-- Check: the row count must match the source files
SELECT COUNT(*) AS total_rows FROM raw_sales;   -- expected: 1,067,371

-- Note: the first import accidentally loaded a file twice.
-- Fixed with TRUNCATE raw_sales; and re-importing each file once.
