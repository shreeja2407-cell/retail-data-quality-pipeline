-- =============================================================
-- 02_validation.sql
-- Step 2: Check the raw data, then build sales_validated:
--   one row per raw row, with proper data types and a
--   dq_status column = PASS or the FIRST rule the row fails.
-- Nothing is deleted here: bad rows are labelled, not removed.
-- =============================================================


-- ---------- A. CHECKS ON THE RAW DATA ----------

-- A1. Missing values in each column (COUNT(col) skips NULLs)
SELECT
    COUNT(*)                       AS total_rows,
    COUNT(*) - COUNT(customer_id)  AS missing_customer,
    COUNT(*) - COUNT(description)  AS missing_description
FROM raw_sales;

-- A2. The two source sheets overlap (1-9 Dec 2010 is in both)
SELECT source_sheet,
       MIN(invoice_date::timestamp) AS first_date,
       MAX(invoice_date::timestamp) AS last_date,
       COUNT(*)                     AS row_count
FROM raw_sales
GROUP BY source_sheet;

-- A3. Duplicate rows: identical in every column except source_sheet
SELECT SUM(copies - 1) AS extra_copies          -- result: 34,335
FROM (
    SELECT COUNT(*) AS copies
    FROM raw_sales
    GROUP BY invoice, stock_code, description, quantity,
             invoice_date, price, customer_id, country
    HAVING COUNT(*) > 1
) d;

-- A4. Invoice types: 'C' = cancellation, 'A' = bad-debt adjustment
SELECT LEFT(invoice, 1) AS first_char, COUNT(*) AS rows
FROM raw_sales
WHERE invoice !~ '^[0-9]{6}$'
GROUP BY LEFT(invoice, 1);

-- A5. Non-product codes (postage, fees, test codes...)
--     Real products = 5 digits + up to 2 letters, e.g. 85123A
SELECT stock_code, MIN(description) AS example, COUNT(*) AS rows
FROM raw_sales
WHERE stock_code !~ '^[0-9]{5}[A-Za-z]{0,2}$'
GROUP BY stock_code
ORDER BY rows DESC;


-- ---------- B. BUILD THE VALIDATED TABLE ----------

DROP TABLE IF EXISTS sales_validated;

CREATE TABLE sales_validated AS
WITH typed AS (
    -- convert TEXT to proper types, and number identical rows
    SELECT
        invoice,
        stock_code,
        description,
        quantity::int                AS quantity,
        invoice_date::timestamp      AS invoice_date,
        price::numeric(10,2)         AS price,
        customer_id,
        country,
        source_sheet,
        ROW_NUMBER() OVER (
            PARTITION BY invoice, stock_code, description, quantity,
                         invoice_date, price, customer_id, country
            ORDER BY source_sheet
        )                            AS copy_number
    FROM raw_sales
),
cancelled_orders AS (
    -- normal orders that have a matching cancellation later:
    -- same customer, same product, opposite quantity
    SELECT DISTINCT o.invoice, o.stock_code, o.quantity
    FROM typed o
    JOIN typed c
      ON  c.invoice LIKE 'C%'
      AND c.customer_id  = o.customer_id
      AND c.stock_code   = o.stock_code
      AND c.quantity     = -o.quantity
      AND c.invoice_date >= o.invoice_date
    WHERE o.invoice ~ '^[0-9]{6}$'
)
SELECT
    t.invoice, t.stock_code, t.description, t.quantity, t.invoice_date,
    t.price, t.customer_id, t.country, t.source_sheet,
    t.quantity * t.price              AS sales_value,
    (t.customer_id IS NULL)           AS missing_customer,   -- kept, only flagged
    (t.stock_code LIKE 'DCGS%')       AS needs_recoding,     -- real products with odd codes
    CASE
        WHEN t.copy_number > 1                          THEN '1 Duplicate row'
        WHEN t.invoice LIKE 'C%'                        THEN '2 Cancellation'
        WHEN t.invoice LIKE 'A%'                        THEN '3 Bad-debt adjustment'
        WHEN t.stock_code !~ '^[0-9]{5}[A-Za-z]{0,2}$'
         AND t.stock_code NOT LIKE 'DCGS%'              THEN '4 Non-product code'
        WHEN co.invoice IS NOT NULL                     THEN '5 Order later cancelled'
        WHEN t.quantity <= 0                            THEN '6 Zero/negative quantity'
        WHEN t.price = 0                                THEN '7 Zero price'
        ELSE 'PASS'
    END                               AS dq_status
FROM typed t
LEFT JOIN cancelled_orders co
       ON co.invoice    = t.invoice
      AND co.stock_code = t.stock_code
      AND co.quantity   = t.quantity;


-- ---------- C. SUMMARY AND RECONCILIATION ----------

-- C1. How many rows failed each rule
SELECT dq_status,
       COUNT(*)                                            AS rows,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)  AS pct
FROM sales_validated
GROUP BY dq_status
ORDER BY dq_status;

-- C2. Nothing lost: raw rows must equal validated rows
SELECT (SELECT COUNT(*) FROM raw_sales)       AS raw_rows,         -- 1,067,371
       (SELECT COUNT(*) FROM sales_validated) AS validated_rows;   -- 1,067,371
