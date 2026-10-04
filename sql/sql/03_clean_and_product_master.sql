-- =============================================================
-- 03_clean_and_product_master.sql
-- Step 3: Keep only trusted rows (sales_clean), fix product-code
-- case, and build a product master with one name per product.
-- =============================================================


-- ---------- A. THE CLEAN TABLE ----------
-- Only PASS rows. invoice_month is added for monthly reporting.

DROP TABLE IF EXISTS sales_clean;

CREATE TABLE sales_clean AS
SELECT
    invoice, stock_code, description, quantity, price, sales_value,
    invoice_date,
    DATE_TRUNC('month', invoice_date)::date AS invoice_month,
    customer_id, missing_customer, needs_recoding, country
FROM sales_validated
WHERE dq_status = 'PASS';

-- Reconciliation: clean + excluded = raw
SELECT
    (SELECT COUNT(*) FROM sales_clean)                              AS clean_rows,     -- 994,109
    (SELECT COUNT(*) FROM sales_validated WHERE dq_status <> 'PASS') AS excluded_rows,  -- 73,262
    (SELECT COUNT(*) FROM raw_sales)                                AS raw_rows;       -- 1,067,371


-- ---------- B. PRODUCT CODE CASE FIX ----------
-- Found while building the Power BI model: some codes appear in
-- both lower and upper case (e.g. 15056bl and 15056BL).
-- PostgreSQL treats them as different, Power BI treats them as the same,
-- so the relationship failed with a "duplicate value" error.

-- B1. How many codes exist in more than one case?
SELECT COUNT(*) AS case_variant_codes          -- 170
FROM (
    SELECT UPPER(stock_code)
    FROM (SELECT DISTINCT stock_code FROM sales_clean) s
    GROUP BY UPPER(stock_code)
    HAVING COUNT(*) > 1
) x;

-- B2. Standardise to upper case.
-- This only relabels the code; no rows are added or removed,
-- so total sales stay exactly the same.
UPDATE sales_clean
SET stock_code = UPPER(stock_code);


-- ---------- C. PRODUCT MASTER ----------
-- One row per product. The same code can have several descriptions
-- (typos, renames). MODE() picks the most frequent one as the
-- standard product name.

DROP TABLE IF EXISTS product_master;

CREATE TABLE product_master AS
SELECT
    stock_code,
    MODE() WITHIN GROUP (ORDER BY description) AS product_name,
    COUNT(DISTINCT description)                AS name_variants
FROM sales_clean
GROUP BY stock_code;

-- Checks
SELECT COUNT(*)                                  AS products,              -- 4,715
       COUNT(*) FILTER (WHERE name_variants > 1) AS products_with_2plus_names  -- 597
FROM product_master;

-- Example: products that had the most different names
SELECT stock_code, product_name, name_variants
FROM product_master
ORDER BY name_variants DESC
LIMIT 10;
