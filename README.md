# Zepto Inventory Analysis with SQL

I picked up a Zepto product inventory dataset, loaded it into PostgreSQL and wrote 34 SQL queries to pull out business insights from it. This covers stock availability, discounts, pricing and pack sizes.

## Tools used
PostgreSQL, pgAdmin, SQL

## What the file contains
`zepto_analysis_queries.sql` has the table structure and all 34 queries. Every query has its question written above it as a comment, so you can read the question and run the query right below it.

## Dataset
The `zepto` table has these columns:

| Column | Meaning |
|---|---|
| sku_id | Unique ID for each row |
| category | Product category |
| product_name | Product name |
| mrp | Maximum retail price in Rs |
| discount_percent | Discount on MRP |
| discounted_selling_price | Price after discount in Rs |
| available_quantity | Units in stock |
| weight_in_gms | Pack weight in grams (some rows have no value) |
| quantity | Pack size info |
| out_of_stock | TRUE if the product is not available |

## Topics covered by the queries
- Stock availability: which categories run out of stock the most, and which products are almost out
- Stock value: where most of the value sits, top products, category rankings
- Discounts: average discount by category, discount ranges, correlation with price
- Pricing: price per gram, cheapest and costliest products, bulk pack savings
- Category patterns: products listed in more than one category, categories that overlap

## SQL concepts used
Aggregations, GROUP BY and HAVING, CASE WHEN for buckets, CTEs, window functions (ROW_NUMBER, RANK, NTILE, running SUM), PERCENTILE_CONT, CORR, STDDEV, self joins, CROSS JOIN, subqueries, SPLIT_PART

## How to run
1. Create a database and connect to it.
2. Run the `CREATE TABLE` statement at the top of the file.
3. Load your cleaned Zepto CSV into the table.
4. Run any query below it, in any order.

## About me
Palash, data analyst. Skills: SQL, Power BI, Excel, basic Python.
LinkedIn: https://linkedin.com/in/palashadyalkar
