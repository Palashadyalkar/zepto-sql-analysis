# Zepto Inventory Analysis with SQL

This is a complete SQL project built on a Zepto product inventory dataset. I cleaned the raw data, loaded it into PostgreSQL, and wrote 34 queries to answer real business questions about stock availability, pricing and discounts.

## Tools used
PostgreSQL, pgAdmin, SQL

## Files in this repository

| File | What it is |
|---|---|
| `zepto_analysis_queries.sql` | Table creation and all 34 business questions with their queries |
| `zepto_final.csv` | The cleaned dataset, ready to load into PostgreSQL |

## About the dataset

The original file had 3,732 rows scraped from Zepto's product listings. After cleaning, the final dataset has **1,967 rows across 9 categories**.

| Column | Meaning |
|---|---|
| sku_id | Unique ID for each row |
| category | Product category |
| product_name | Product name |
| mrp | Maximum retail price in Rs |
| discount_percent | Discount on MRP |
| discounted_selling_price | Price after discount in Rs |
| available_quantity | Units currently in stock |
| weight_in_gms | Pack weight in grams (a few rows have no value) |
| quantity | Pack size info as scraped |
| out_of_stock | TRUE if the product is not available |

## Data cleaning

The raw file had a few issues that would have given wrong results if I had loaded it as is:

- **Prices were in paise, not rupees.** An MRP of 2500 actually meant Rs 25. I divided both price columns by 100.
- **The file was Windows-1252 encoded, not UTF-8.** This caused product names with special characters, like Nestlé, to fail on import. I re-saved it as UTF-8.
- **Extra spaces and inconsistent spelling in product names.** Some names had trailing spaces or different letter casing for the same product, like "Vicks VapoRub" and "Vicks Vaporub". These would have counted as different products in GROUP BY, so I standardised them.
- **One row had MRP and price both at 0.** I removed it since it would break discount calculations.
- **Weight was 0 on a few rows.** I set these to NULL instead of keeping a false value.
- **A couple of exact duplicate rows.** Removed.
- **Five categories turned out to be exact copies of other categories.** Munchies was an identical copy of Cooking Essentials, Beverages was a copy of Dairy Bread & Batter, and Ice Cream & Desserts, Chocolates & Candies and Paan Corner were copies of Packaged Food and Personal Care. This looked like a scraping mistake, since items like cheese and diapers were sitting under the wrong category names. Removing the copies dropped the row count from 3,729 to 1,967, and made every category-level number accurate instead of inflated.

## How to run this project

1. Create a database in PostgreSQL, for example `zepto_analysis`.
2. Open `zepto_analysis_queries.sql` and run the `CREATE TABLE` statement at the top.
3. Import `zepto_final.csv` into the `zepto` table (in pgAdmin: right-click the table, Import/Export, format csv, header on, encoding UTF8).
4. Check `SELECT COUNT(*) FROM zepto;` returns 1967.
5. Run any of the 34 queries below it, in any order.

## What the queries cover

The 34 questions in `zepto_analysis_queries.sql` are grouped around these themes:

- **Stock availability** – which categories run out of stock the most, which products are almost sold out, and which high-value items are currently unavailable
- **Stock value** – where the value of the inventory sits, top products and categories by value, and a Pareto (80/20) and ABC classification of products
- **Discounts** – average discount by category, how discounts are distributed, whether pricier products get bigger discounts, and the correlation between price and discount
- **Pricing** – price per gram, cheapest and costliest products per category, and whether bigger packs are cheaper per gram
- **Category patterns** – products listed under more than one category, and which categories overlap the most

## SQL concepts used

Aggregations (SUM, AVG, COUNT, MIN, MAX), GROUP BY and HAVING, CASE WHEN for buckets and pivots, CTEs, window functions (ROW_NUMBER, RANK, NTILE, running SUM), PERCENTILE_CONT, CORR, STDDEV, self joins, CROSS JOIN, subqueries, and SPLIT_PART.

Example, top 3 most discounted products in each category:

```sql
SELECT category, product_name, discount_percent, rnk
FROM (
    SELECT category, product_name, discount_percent,
           ROW_NUMBER() OVER (PARTITION BY category
                              ORDER BY discount_percent DESC, mrp DESC, product_name) AS rnk
    FROM zepto
) ranked
WHERE rnk <= 3
ORDER BY category, rnk;
```

## Key findings

- Biscuits have the worst stock availability, with 28.6% of listings out of stock, followed by Dairy Bread & Batter (21.7%) and Meats, Fish & Eggs (19.0%). Personal Care is the most reliable at 6.1%.
- Three categories, Cooking Essentials, Personal Care and Packaged Food, together hold about 74% of the total stock value on the shelf.
- Nine of the top 10 products by stock value are cooking oils or ghee, so these products carry the biggest revenue risk if they go out of stock.
- The average discount across the catalogue is only 7.7%, and 30.1% of listings have no discount at all.
- 38 products priced above Rs 500 have less than 10% discount, mostly large oil jars, detergent and baby formula. These look like good candidates for promotions.
- 279 in-stock listings have 2 units or fewer left, concentrated in Packaged Food, Cooking Essentials and Personal Care.
- 141 products are listed under more than one category, so any product-level count needs DISTINCT or GROUP BY product_name to avoid double counting.

## Limitations

- Stock value here means price times units currently on the shelf, not actual sales. There is no sales or date data in this dataset, so trends over time cannot be measured.
- Category labels come from the original scraped source, and some products are genuinely listed under more than one category.
- The `quantity` column's exact meaning is not documented, so I did not rely on it for analysis.

## About me

Palash, data analyst. Skills: SQL, Power BI, Excel, basic Python.
LinkedIn: https://linkedin.com/in/palashadyalkar
