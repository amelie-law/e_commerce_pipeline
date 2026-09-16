
-- Analytics Queries: Olist Gold Layer
-- Run against: olist.gold.fact_order_items, dim_customer, dim_product, dim_seller

-- 1. Top 10 entities by a chosen metric
-- Top 10 products by total revenue 

SELECT 
    p.product_id, 
    p.product_category_name_english,
    CAST(SUM(f.price) AS DECIMAL(18, 2)) AS total_revenue,
    COUNT(*) AS units_sold
FROM olist.gold.fact_order_items AS f
JOIN olist.gold.dim_product AS p
    ON f.product_sk = p.product_sk
GROUP BY p.product_id, p.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 10;


-- 2. Metric trend over time
-- Monthly revenue trend across the full dataset

SELECT
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month,
    CAST(SUM(price) AS DECIMAL(18, 2)) AS monthly_revenue,
    COUNT(DISTINCT order_sk) AS order_count
FROM olist.gold.fact_order_items
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date), YEAR(order_date)
ORDER BY YEAR(order_date), MONTH(order_date);


-- 3. Outlier / anomaly detection 
-- Products priced above the 95th percentile - flagging unusually high-value items for further investigation

WITH price_percentiles AS (
    SELECT
        PERCENTILE(price, 0.95) AS p95_price
    FROM olist.gold.fact_order_items
)
SELECT
    f.order_item_sk,
    f.order_sk,
    p.product_id,
    p.product_category_name_english,
    f.price
FROM olist.gold.fact_order_items f
JOIN olist.gold.dim_product p
    ON f.product_sk = p.product_sk
CROSS JOIN price_percentiles pp
WHERE f.price > pp.p95_price
ORDER BY f.price DESC;


-- 4. Geographic breakdown 
-- Revenue and order count by customer state

SELECT
    c.customer_state,
    ROUND(SUM(f.price), 2) AS total_revenue,
    COUNT(DISTINCT f.order_sk) AS order_count,
    ROUND(SUM(f.price) / COUNT(DISTINCT f.order_sk), 2) AS avg_order_value
FROM olist.gold.fact_order_items f
JOIN olist.gold.dim_customer c
    ON f.customer_sk = c.customer_sk
GROUP BY c.customer_state
ORDER BY total_revenue DESC;


-- 5. Stakeholder query 
-- What is our current month-to-date revenue, and how does it compare to the same point in the previous month?

WITH monthly_totals AS (
    SELECT
        DATE_TRUNC('month', order_date) AS order_month,
        ROUND(SUM(price), 2) AS monthly_revenue
    FROM olist.gold.fact_order_items
    WHERE order_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    order_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY order_month) AS previous_month_revenue,
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY order_month))
        / LAG(monthly_revenue) OVER (ORDER BY order_month) * 100,
        1
    ) AS pct_change_vs_previous_month
FROM monthly_totals
ORDER BY order_month DESC;