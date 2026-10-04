# retail-data-quality-pipeline
SQL data validation and cleaning of 1M+ real retail transactions, with an Excel data-quality report and Power BI dashboard
# Retail Sales Data Quality Pipeline & Dashboard

An end-to-end data operations project on **1,067,371 real retail transactions**:
validating and cleaning the data in **PostgreSQL**, documenting data quality in **Excel**,
and reporting the results in a **Power BI** dashboard.

---

## Results at a glance

| Metric | Value |
|---|---|
| Raw transactions checked | 1,067,371 |
| Data-quality rules applied | 7 |
| Invalid records excluded | 73,262 (6.86%) |
| Clean records (pass rate) | 994,109 (93.14%) |
| Records lost | 0 (clean + excluded = raw) |
| Product codes standardised | 170 |
| Products in product master | 4,715 |

---

## Dataset

**Online Retail II** – UCI Machine Learning Repository (CC BY 4.0).
Transactions from a UK-based online retailer selling giftware, mostly to wholesalers,
from **1 Dec 2009 to 9 Dec 2011**.
The data is not included in this repo because of its size; download it from the
[UCI website](https://archive.ics.uci.edu/dataset/502/online+retail+ii).

---

## How the pipeline works

```
raw_sales (all TEXT)  →  sales_validated (typed + dq_status)  →  sales_clean (PASS only)  →  Power BI
                                                                  product_master (1 row per product)
```

1. **Raw layer:** everything is loaded as text so no row fails on import.
2. **Validated layer:** values are converted to proper types, and every row gets a
   `dq_status`: either `PASS` or the **first** rule it fails. Nothing is deleted at this stage.
3. **Clean layer:** only `PASS` rows are kept and used for reporting.

### Data-quality rules

| # | Rule | Why | Rows | % of raw |
|---|---|---|---|---|
| 1 | Duplicate row | The two source sheets overlap (1–9 Dec 2010) | 34,335 | 3.22% |
| 2 | Cancellation | Invoice starts with "C" | 19,104 | 1.79% |
| 3 | Bad-debt adjustment | Invoice starts with "A" (accounting entry, not a sale) | 6 | 0.00% |
| 4 | Non-product code | Postage, fees, test codes (not a 5-digit product code) | 4,628 | 0.43% |
| 5 | Order later cancelled | A matching cancellation exists for the same customer, product and quantity | 9,229 | 0.86% |
| 6 | Zero / negative quantity | Not a valid sale | 3,390 | 0.32% |
| 7 | Zero price | Free or placeholder rows | 2,570 | 0.24% |
| | **PASS** | | **994,109** | **93.14%** |

### Key decisions

- **Flagged, not deleted:** 226,760 valid sales (22.81% of clean rows) have no customer ID,
  likely guest checkouts. They are real revenue, so they were kept and flagged with
  `missing_customer` instead of being removed.
- **Product code case fix:** 170 codes appeared in both lower and upper case
  (e.g. `15056bl` / `15056BL`). This broke the Power BI relationship, so codes were
  standardised to upper case. This only relabels the code; total sales are unchanged.
- **Product master:** many products had several descriptions (typos, renames).
  The most frequent description was chosen as the standard name (597 products affected).
- **Reconciliation:** every stage is checked so that no record is lost or duplicated.

---

## Power BI dashboard

**Page 1 – Sales Overview**

![Sales Overview](images/dashboard_page1.png)

**Page 2 – Products & Markets**

![Products & Markets](images/dashboard_page2.png)

Built on a star-schema model (`sales_clean` fact table linked to `product_master`),
with DAX measures for sales, orders, customers, average order value, country share
and month-over-month growth.

---

## Key insights

- **£18.9M** in sales across **39,189 orders** and **5,838 customers**; average order value **£482.60**.
- Sales peak every **November** (around £1.4M), driven by Christmas stock-up.
- The **UK accounts for about 85%** of revenue; the largest other markets are EIRE, the Netherlands and Germany.
- Guest customers are 22.8% of rows but only **13.6% of sales**, so their orders are smaller.
- The sharp drop in December 2011 is **not a real decline**: the data ends on 9 Dec 2011,
  so that month is incomplete and should be excluded from growth reporting.

---

## Repository structure

```
sql/
  01_load_raw.sql                    create raw table and load the CSV files
  02_validation.sql                  data checks, 7 rules, sales_validated table
  03_clean_and_product_master.sql    clean table, code fix, product master
images/
  dashboard_page1.png
  dashboard_page2.png
Project1_DQ_Report.xlsx              Excel data-quality report (summary, findings log, reconciliation)
```

## How to reproduce

1. Download the dataset from UCI and save both sheets as CSV.
2. In PostgreSQL, run `sql/01_load_raw.sql` and import the two CSV files.
3. Run `sql/02_validation.sql`, then `sql/03_clean_and_product_master.sql`.
4. Connect Power BI to the `sales_clean` and `product_master` tables.

## Tools

PostgreSQL 17 · pgAdmin 4 · Microsoft Excel · Power BI Desktop (DAX)
