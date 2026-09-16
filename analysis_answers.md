### Commercial Insights

1. **Almost all customers buy once, then never return.** 

**Finding**: The majority of customers in the dataset placed exactly one order whilst repeat customers only presented a small number. 

**Method**: counting the number of distinct orders per customer using the fact table joined to the customer table then grouping the customers into "One-time" and "Repeat"

```
WITH customer_order_counts AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT f.order_sk) AS order_count,
        CASE 
            WHEN COUNT(DISTINCT f.order_sk) = 1 THEN 'One-time' 
            ELSE 'Repeat' 
        END AS order_count_bucket
    FROM olist.gold.fact_order_items f
    JOIN olist.gold.dim_customer c 
        ON f.customer_sk = c.customer_sk
    GROUP BY c.customer_unique_id
)
SELECT
    order_count_bucket,
    COUNT(*) AS customers
FROM customer_order_counts
GROUP BY order_count_bucket;
```

**Importance to Stakeholder**: Acquiring a customer costs money (marketing, discounts); if nobody buys a second time, the business is running on constant new-customer acquisition rather than building customer value. Even a small shift toward repeat purchasing would have an impact on margins, since a second purchase from an existing customer is far cheaper to generate than a first purchase from a new one.


2. **Revenue is heavily concentrated in a small number of states**  

**Finding**: A small number of states, especially Sao Paulo, account for the most revenue, while other states contribute comparatively little.

**Method**: total revenue and order count grouped by customer_state

**Importance to Stakeholder**: This tells the business where its customer base lives compared to where it might be under investing in marketing. It's a direct input into decisions like regional marketing budget allocation, warehouse/fulfillment placement, or which states are lacking support.


3. **A small number of products are priced well above their category average** 

**Findings**: A handful of items are priced significantly above the average of their product category (items more than 3 standard deviations above their category's mean price).

**Method**: For each product category, the average and standard deviation of item price were calculated, then flagged individual items whose price is a z-score outlier relative to their own category - this avoids unfairly flagging a normal-priced electronics item just because it's expensive compared to a stationery item.

```
WITH category_price_stats AS (
    SELECT
        p.product_category_name_english,
        AVG(f.price) AS mean_price,
        STDDEV(f.price) AS stddev_price
    FROM olist.gold.fact_order_items f
    JOIN olist.gold.dim_product p ON f.product_sk = p.product_sk
    WHERE p.product_category_name_english IS NOT NULL
    GROUP BY p.product_category_name_english
)
SELECT
    p.product_category_name_english,
    COUNT(*) AS outlier_count
FROM olist.gold.fact_order_items f
JOIN olist.gold.dim_product p ON f.product_sk = p.product_sk
JOIN category_price_stats cps ON p.product_category_name_english = cps.product_category_name_english
WHERE (f.price - cps.mean_price) / cps.stddev_price > 3
GROUP BY p.product_category_name_english
ORDER BY outlier_count DESC;
```

**Importance to Stakeholders**: High value outlier items likely carry different risk and margin profiles than the rest of the catalog so may require need different handling (insurance, packaging, fraud checks on payment). These customers may be a valuable premium segment that the business is not fully targeting. Looking at which categories they purchase can help identify where premium or upselling opportunities exist, while also highlighting cases where unusually high prices may need further investigation.

### Recommendations

- **Target segment**: Customers who made exactly one purchase, where that purchase was delivered successfully (not canceled, not a late-delivery case) within the last 60–90 days. A customer whose first experience was already bad (late delivery) is a weaker target for a "come back" campaign than one whose first experience was smooth.
- **Mechanic/offer**: a time-limited discount (e.g. 10-15% off, or free shipping) on a second order, delivered via email/notification within a defined window after their first delivery - framed as a "welcome back" or "thank you for your first order" incentive rather than a generic discount blast.
- **Expected commerical impact** - If 5% of one-time buyers make a second purchase because of the campaign, and the average order value is in line with the dataset's overall average order value, this would generate a meaningful increase in revenue that can be directly linked to the campaign. The main assumption is that the cost of the discount is lower than the profit gained from turning a one-time buyer into a repeat customer, especially since repeat customers do not require additional acquisition spending.

- **Measurement** - Run this as an A/B test. A random group of eligible one-time buyers receives no offer, while the remaining customers receive the discount. After 4–6 weeks, compare the rate of second purchases between the two groups. The campaign is successful if the offer leads to a statistically significant increase in repeat purchases, after accounting for the cost of the discount.


### Assumptions
- casa_conforto and casa_conforto_2 were kept as distinct categories rather than merged, since Olist's own official category translation table treats them as genuinely separate entries so merging them would have been an unverified assumption.
- orders marked canceled but showing a delivery date were left as they were rather than "corrected" or shown as "returned" - it's unclear whether they were delivered then canceled, or the status was updated without clearing the date
- some rows in the raw reviews data show corrupted/inconsistent values in the review_id field - for example, a pair of date values (2018-02-16 00:00:00, 2018-02-20 10:52:22) appearing where a review ID should be. This points to a CSV parsing issue upstream, likely caused by review comment text containing embedded commas or quotes that shifted column boundaries. Rather than guess at the correct values, affected rows were handled using try_to_timestamp() (nulling unparseable dates rather than crashing the pipeline) and one row with a fully null review_id was removed from silver, since it couldn't be reliably joined or deduplicated.
- `seller_city` contains at least one row with a purely numeric value (e.g. "04482255") instead of an actual city name, clearly a data entry error, likely a zip code mistakenly entered into the city field. This was documented but not corrected, since guessing at the intended city would be fabricating data rather than cleaning it



1. The revenue estimate, not a confirmed forecast. The actual conversion rate would need to be tested through a real campaign rather than assumed from the dataset.

2. The dataset covers 2016–2018, so customer behaviour may have changed since then. The recommendations therefore assume that the patterns seen in the dataset are still broadly relevant today.

3. There are a few known data quality issues, including an incorrect numeric value in `seller_city` and some corrupted review timestamps caused by CSV parsing. These affect only a small part of the data, so the overall impact is expected to be limited, but it has not been measured in detail.

**Top 3 Data Quality Issues**:
1. **Check for missing or duplicate keys** - make sure surrogate keys are never null or duplicated. This helps catch broken joins or corrupted data before it reaches the Gold layer.

2. **Check that relationships are valid** - for example, every `customer_sk` in `fact_order_items` should exist in `dim_customer`. This helps catch failed joins or missing records.

3. **Check that dates make sense** - for example, an order should not be delivered before it was purchased. This helps identify data errors or problems in the pipeline.

**Detecting unexpected schema changes or outdated data:**

**Detecting unexpected schema changes or outdated data:**

- **Monitor row and column counts** for each data load. Unexpected changes can indicate that the source data has changed or that something went wrong during ingestion.

- **Check the source schema** against the expected column names and data types. If a column is added, removed, or changed unexpectedly, the pipeline should flag the issue rather than silently continuing.

- **Check data freshness** by monitoring the latest `_loaded_at` value or most recent source date. If the data stops updating when it should, this indicates that the source may be out of date even if the pipeline appears to have completed successfully.



### Client Memo

I have built a complete data pipeline on Databricks that takes raw order, customer, and product data and turns it into a clean, reliable foundation for analysis. Data flows through three stages: a raw landing zone, a cleaned and deduplicated layer, and a business-ready layer optimized for fast reporting, all version-controlled and reproducible.

Using this foundation, I found that the overwhelming majority of customers buy once and never return which is one of the biggest opportunities in the business one where a significant amount of potential customer value is being missed. I also identified that revenue is heavily concentrated in a handful of regions, and found a cluster of high-value outlier items priced well above the avergae for their category, concentrated in specific categories worth a closer pricing review.

Recommended next step: Run a targeted, time limited second purchase incentive for recent one time buyers whose first order was delivered successfully, tested as a proper A/B experiment so we can measure real impact within 4-6 weeks before scaling spend.

This pipeline now gives us the infrastructure to keep generating findings like this on an ongoing basis.














