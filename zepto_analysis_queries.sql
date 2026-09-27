CREATE TABLE zepto (
    sku_id                   SERIAL PRIMARY KEY,
    category                 VARCHAR(50),
    product_name             VARCHAR(150) NOT NULL,
    mrp                      NUMERIC(8,2),
    discount_percent         NUMERIC(5,2),
    discounted_selling_price NUMERIC(8,2),
    available_quantity       INTEGER,
    weight_in_gms            INTEGER,      -- kuch rows me NULL hai (weight unknown)
    quantity                 INTEGER,
    out_of_stock             BOOLEAN
);

SELECT * FROM zepto;

Q1. Which categories have the highest out-of-stock rate?

SELECT category,
       COUNT(*) AS total_skus,
       SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) AS out_of_stock_skus,
       ROUND(100.0 * SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) / COUNT(*), 1) AS oos_pct
FROM zepto
GROUP BY category
ORDER BY oos_pct DESC;


Q2. How much stock value does each category hold, and what share of the total is that?

SELECT category,
       SUM(discounted_selling_price * available_quantity) AS est_revenue,
       ROUND(100.0 * SUM(discounted_selling_price * available_quantity)
             / SUM(SUM(discounted_selling_price * available_quantity)) OVER (), 1) AS pct_of_total
FROM zepto
WHERE out_of_stock = FALSE
GROUP BY category
ORDER BY est_revenue DESC;


Q3. Which 10 products hold the most stock value?

SELECT product_name,
       SUM(discounted_selling_price * available_quantity) AS est_revenue
FROM zepto
WHERE out_of_stock = FALSE
GROUP BY product_name
ORDER BY est_revenue DESC
LIMIT 10;


Q4. What is the average discount in each category?

SELECT category, ROUND(AVG(discount_percent), 2) AS avg_discount_pct
FROM zepto
GROUP BY category
ORDER BY avg_discount_pct DESC;


Q5. Which 10 products have the highest discounts?

SELECT DISTINCT product_name, mrp, discount_percent, discounted_selling_price
FROM zepto
ORDER BY discount_percent DESC, mrp DESC
LIMIT 10;

Q6. How many products fall in each discount range?

SELECT CASE WHEN discount_percent = 0  THEN '1. No discount'
            WHEN discount_percent <= 10 THEN '2. 1-10%'
            WHEN discount_percent <= 25 THEN '3. 11-25%'
            ELSE '4. Above 25%' END AS discount_bucket,
       COUNT(*) AS skus,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM zepto
GROUP BY 1
ORDER BY 1;


Q7. Which products priced above Rs 500 have less than 10% discount?

SELECT DISTINCT product_name, category, mrp, discount_percent
FROM zepto
WHERE mrp > 500 AND discount_percent < 10
ORDER BY mrp DESC
LIMIT 15;


Q8. Which products with an MRP above Rs 300 are out of stock?

SELECT DISTINCT product_name, category, mrp, discounted_selling_price
FROM zepto
WHERE out_of_stock = TRUE AND mrp > 300
ORDER BY mrp DESC;


Q9. Which products give the lowest price per gram (packs of 100g or more)?

SELECT DISTINCT product_name, weight_in_gms, discounted_selling_price,
       ROUND(discounted_selling_price / weight_in_gms, 3) AS price_per_gram
FROM zepto
WHERE weight_in_gms >= 100
ORDER BY price_per_gram ASC
LIMIT 10;


Q10. How do small, medium and bulk packs compare on price and discount?

SELECT CASE WHEN weight_in_gms < 1000 THEN 'Low (<1kg)'
            WHEN weight_in_gms < 5000 THEN 'Medium (1-5kg)'
            ELSE 'Bulk (5kg+)' END AS pack_size,
       COUNT(*) AS skus,
       ROUND(AVG(discount_percent), 1) AS avg_discount_pct,
       ROUND(AVG(discounted_selling_price), 1) AS avg_price
FROM zepto
WHERE weight_in_gms IS NOT NULL
GROUP BY 1
ORDER BY skus DESC;


Q11. What is the total stock weight (in kg) in each category?

SELECT category,
       ROUND(SUM(weight_in_gms * available_quantity) / 1000.0, 0) AS total_stock_kg
FROM zepto
GROUP BY category
ORDER BY total_stock_kg DESC;


Q12. What are the top 3 most discounted products in each category?

SELECT category, product_name, discount_percent, rnk
FROM (
    SELECT category, product_name, discount_percent,
           ROW_NUMBER() OVER (PARTITION BY category
                              ORDER BY discount_percent DESC, mrp DESC, product_name) AS rnk
    FROM zepto
) ranked
WHERE rnk <= 3
ORDER BY category, rnk;


Q13. Which categories give more discount than the overall average?

WITH overall AS (
    SELECT AVG(discount_percent) AS avg_disc FROM zepto
),
per_category AS (
    SELECT category, AVG(discount_percent) AS cat_disc FROM zepto GROUP BY category
)
SELECT p.category,
       ROUND(p.cat_disc, 2) AS category_avg_discount,
       ROUND(o.avg_disc, 2) AS overall_avg_discount
FROM per_category p
CROSS JOIN overall o
WHERE p.cat_disc > o.avg_disc
ORDER BY p.cat_disc DESC;


Q14. What is the average saving per unit (MRP minus selling price) in each category?

SELECT category, ROUND(AVG(mrp - discounted_selling_price), 2) AS avg_saving_rs
FROM zepto
GROUP BY category
ORDER BY avg_saving_rs DESC;


Q15. What are the min, median, average and max MRP in each category?

SELECT category,
       MIN(mrp) AS min_mrp,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mrp) AS median_mrp,
       ROUND(AVG(mrp), 0) AS avg_mrp,
       MAX(mrp) AS max_mrp
FROM zepto
GROUP BY category
ORDER BY avg_mrp DESC;


Q16. Which in-stock products have only 1 or 2 units left?

SELECT category, product_name, available_quantity
FROM zepto
WHERE out_of_stock = FALSE AND available_quantity <= 2
ORDER BY available_quantity, category
LIMIT 15;


Q17. Which products are listed under more than one category?

SELECT product_name, COUNT(DISTINCT category) AS categories_listed
FROM zepto
GROUP BY product_name
HAVING COUNT(DISTINCT category) > 1
ORDER BY categories_listed DESC, product_name
LIMIT 10;


Q18. How many products make up 80% of the total stock value?

WITH prod AS (
    SELECT product_name, SUM(discounted_selling_price * available_quantity) AS rev
    FROM zepto
    WHERE out_of_stock = FALSE
    GROUP BY product_name
),
ranked AS (
    SELECT product_name, rev,
           SUM(rev) OVER (ORDER BY rev DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_rev,
           SUM(rev) OVER () AS total_rev
    FROM prod
)
SELECT COUNT(*) AS products_for_80pct,
       (SELECT COUNT(*) FROM prod) AS total_products,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM prod), 1) AS pct_of_products
FROM ranked
WHERE cum_rev - rev < 0.8 * total_rev;


Q19. Group products into A, B and C classes based on their stock value.

WITH prod AS (
    SELECT product_name, SUM(discounted_selling_price * available_quantity) AS rev
    FROM zepto
    WHERE out_of_stock = FALSE
    GROUP BY product_name
),
ranked AS (
    SELECT product_name, rev,
           SUM(rev) OVER (ORDER BY rev DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
             / SUM(rev) OVER () AS cum_share
    FROM prod
)
SELECT CASE WHEN cum_share <= 0.80 THEN 'A (top 80% of value)'
            WHEN cum_share <= 0.95 THEN 'B (next 15%)'
            ELSE 'C (last 5%)' END AS abc_class,
       COUNT(*) AS products,
       ROUND(SUM(rev), 0) AS class_value
FROM ranked
GROUP BY 1
ORDER BY 1;


Q20. Does a category's rank by product count match its rank by stock value?

SELECT category,
       COUNT(*) AS skus,
       RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_by_skus,
       ROUND(SUM(CASE WHEN out_of_stock THEN 0 ELSE discounted_selling_price * available_quantity END), 0) AS stock_value,
       RANK() OVER (ORDER BY SUM(CASE WHEN out_of_stock THEN 0 ELSE discounted_selling_price * available_quantity END) DESC) AS rank_by_value
FROM zepto
GROUP BY category
ORDER BY rank_by_value;


Q21. Do costlier products get bigger discounts?

WITH q AS (
    SELECT mrp, discount_percent, NTILE(4) OVER (ORDER BY mrp) AS price_quartile
    FROM zepto
)
SELECT price_quartile,
       MIN(mrp) AS min_mrp,
       MAX(mrp) AS max_mrp,
       ROUND(AVG(discount_percent), 2) AS avg_discount_pct
FROM q
GROUP BY price_quartile
ORDER BY price_quartile;


Q22. Is there a correlation between MRP and discount?

SELECT ROUND(CORR(mrp, discount_percent)::NUMERIC, 3) AS mrp_vs_discount_corr
FROM zepto;


Q23. Which products are unusually expensive for their category?

WITH stats AS (
    SELECT category, AVG(mrp) AS avg_mrp, STDDEV(mrp) AS sd_mrp
    FROM zepto
    GROUP BY category
)
SELECT DISTINCT z.category, z.product_name, z.mrp,
       ROUND(s.avg_mrp, 0) AS category_avg_mrp
FROM zepto z
JOIN stats s ON s.category = z.category
WHERE z.mrp > s.avg_mrp + 2 * s.sd_mrp
ORDER BY z.mrp DESC
LIMIT 15;


Q24. How many products fall in each discount range within each category?

SELECT category,
       SUM(CASE WHEN discount_percent = 0 THEN 1 ELSE 0 END) AS no_discount,
       SUM(CASE WHEN discount_percent BETWEEN 1 AND 10 THEN 1 ELSE 0 END) AS disc_1_10,
       SUM(CASE WHEN discount_percent BETWEEN 11 AND 25 THEN 1 ELSE 0 END) AS disc_11_25,
       SUM(CASE WHEN discount_percent > 25 THEN 1 ELSE 0 END) AS disc_above_25
FROM zepto
GROUP BY category
ORDER BY category;


Q25. How much discount (in Rs) is being offered in each category?

SELECT category,
       ROUND(SUM((mrp - discounted_selling_price) * available_quantity), 0) AS total_discount_value
FROM zepto
WHERE out_of_stock = FALSE
GROUP BY category
ORDER BY total_discount_value DESC;


Q26. Do heavily discounted products have more or less stock?

SELECT CASE WHEN discount_percent = 0  THEN '1. No discount'
            WHEN discount_percent <= 10 THEN '2. 1-10%'
            WHEN discount_percent <= 25 THEN '3. 11-25%'
            ELSE '4. Above 25%' END AS discount_bucket,
       COUNT(*) AS skus,
       ROUND(AVG(available_quantity), 2) AS avg_units_in_stock
FROM zepto
WHERE out_of_stock = FALSE
GROUP BY 1
ORDER BY 1;


Q27. Which categories have a higher out-of-stock rate than the overall rate?

WITH overall AS (
    SELECT 100.0 * SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) / COUNT(*) AS overall_oos_pct
    FROM zepto
),
cat AS (
    SELECT category, 100.0 * SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) / COUNT(*) AS cat_oos_pct
    FROM zepto
    GROUP BY category
)
SELECT c.category, ROUND(c.cat_oos_pct, 1) AS category_oos_pct, ROUND(o.overall_oos_pct, 1) AS overall_oos_pct
FROM cat c
CROSS JOIN overall o
WHERE c.cat_oos_pct > o.overall_oos_pct
ORDER BY c.cat_oos_pct DESC;


Q28. Which categories have the most products that are out of stock or almost out?

SELECT category,
       COUNT(*) AS total_skus,
       SUM(CASE WHEN out_of_stock OR available_quantity <= 2 THEN 1 ELSE 0 END) AS at_risk_skus,
       ROUND(100.0 * SUM(CASE WHEN out_of_stock OR available_quantity <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS at_risk_pct
FROM zepto
GROUP BY category
ORDER BY at_risk_pct DESC;


Q29. How much stock value is lost because of out-of-stock products? (estimate)

-- Estimate: out-of-stock price x average units held by in-stock items of the same category.
WITH avg_units AS (
    SELECT category, AVG(available_quantity) AS avg_qty
    FROM zepto
    WHERE out_of_stock = FALSE
    GROUP BY category
)
SELECT z.category,
       COUNT(*) AS oos_skus,
       ROUND(SUM(z.discounted_selling_price * a.avg_qty), 0) AS est_lost_stock_value
FROM zepto z
JOIN avg_units a ON a.category = z.category
WHERE z.out_of_stock = TRUE
GROUP BY z.category
ORDER BY est_lost_stock_value DESC;


Q30. What are the cheapest and the most expensive products in each category?

SELECT category, product_name, mrp,
       CASE WHEN rn_high = 1 THEN 'Most expensive' ELSE 'Cheapest' END AS position
FROM (
    SELECT category, product_name, mrp,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY mrp DESC, product_name) AS rn_high,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY mrp ASC,  product_name) AS rn_low
    FROM (SELECT DISTINCT category, product_name, mrp FROM zepto) d
) t
WHERE rn_high = 1 OR rn_low = 1
ORDER BY category, mrp DESC;


Q31. Which brands have the most products?

-- Brand is taken as the first word of the product name, so it is only approximate.
SELECT SPLIT_PART(product_name, ' ', 1) AS brand,
       COUNT(*) AS skus,
       ROUND(AVG(discount_percent), 2) AS avg_discount_pct,
       ROUND(AVG(mrp), 0) AS avg_mrp
FROM zepto
WHERE SPLIT_PART(product_name, ' ', 1) NOT IN ('The', '24')
GROUP BY 1
ORDER BY skus DESC
LIMIT 10;


Q32. Is the larger pack cheaper per gram than the smaller pack of the same product?

-- Only pairs where the large pack is 1.5x to 5x the small one, to avoid bad weight data.
WITH base AS (
    SELECT DISTINCT product_name, weight_in_gms, discounted_selling_price
    FROM zepto
    WHERE weight_in_gms IS NOT NULL
),
ranked AS (
    SELECT product_name, weight_in_gms, discounted_selling_price,
           ROW_NUMBER() OVER (PARTITION BY product_name ORDER BY weight_in_gms ASC)  AS rn_small,
           ROW_NUMBER() OVER (PARTITION BY product_name ORDER BY weight_in_gms DESC) AS rn_large,
           COUNT(*) OVER (PARTITION BY product_name) AS sizes
    FROM base
)
SELECT s.product_name,
       s.weight_in_gms AS small_pack_g,
       l.weight_in_gms AS large_pack_g,
       ROUND(s.discounted_selling_price / s.weight_in_gms, 3) AS price_per_g_small,
       ROUND(l.discounted_selling_price / l.weight_in_gms, 3) AS price_per_g_large,
       ROUND(100 * (1 - (l.discounted_selling_price / l.weight_in_gms)
                      / (s.discounted_selling_price / s.weight_in_gms)), 1) AS bulk_saving_pct
FROM ranked s
JOIN ranked l ON l.product_name = s.product_name AND l.rn_large = 1
WHERE s.rn_small = 1 AND s.sizes > 1
  AND l.weight_in_gms > s.weight_in_gms
  AND l.weight_in_gms BETWEEN 1.5 * s.weight_in_gms AND 5 * s.weight_in_gms
ORDER BY bulk_saving_pct DESC
LIMIT 10;


Q33. Which pairs of categories have the most products in common?

SELECT a.category AS category_a,
       b.category AS category_b,
       COUNT(DISTINCT a.product_name) AS shared_products
FROM zepto a
JOIN zepto b ON a.product_name = b.product_name AND a.category < b.category
GROUP BY a.category, b.category
ORDER BY shared_products DESC
LIMIT 10;


Q34. Category summary: products, out-of-stock %, discount, price and stock value.

SELECT category,
       COUNT(*) AS skus,
       ROUND(100.0 * SUM(CASE WHEN out_of_stock THEN 1 ELSE 0 END) / COUNT(*), 1) AS oos_pct,
       ROUND(AVG(discount_percent), 1) AS avg_discount_pct,
       ROUND(AVG(mrp), 0) AS avg_mrp,
       ROUND(SUM(CASE WHEN out_of_stock THEN 0 ELSE discounted_selling_price * available_quantity END), 0) AS stock_value
FROM zepto
GROUP BY category
ORDER BY stock_value DESC;













