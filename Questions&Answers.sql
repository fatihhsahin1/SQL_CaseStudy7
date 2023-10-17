--HIGH LEVEL SALES ANALYSIS

--1. What was the total quantity sold for all products?
SELECT 		
	SUM(qty) AS total_qty
FROM 
	balanced_tree.sales 

ORDER BY total_qty

--2. What is the total generated revenue for all products before discounts?
SELECT
	SUM(qty*price) as total_revenue_bd
FROM 
	balanced_tree.sales 
ORDER BY total_revenue_bd

--3. What was the total discount amount for all products?
SELECT pd.product_name,
       ROUND(SUM((s.price * s.qty) * (CAST(s.discount AS NUMERIC) / 100)), 2 ) AS total_item_discounts
FROM balanced_tree.sales  s
JOIN balanced_tree.product_details  pd 
ON pd.product_id = s.prod_id
GROUP BY pd.product_name


--TRANSACTION ANALYSIS

--1. How many unique transactions were there?
SELECT
	COUNT(DISTINCT txn_id) AS unique_txns
FROM balanced_tree.sales

--2. What is the average unique products purchased in each transaction?

WITH TransactionProductCounts AS (
    SELECT 
        s.txn_id,
        COUNT(DISTINCT s.prod_id) AS unique_product_count
    FROM balanced_tree.sales AS s
    GROUP BY s.txn_id
)
SELECT 
   ROUND(AVG(CAST(unique_product_count AS FLOAT)),1) AS avg_unique_products_per_transaction
FROM TransactionProductCounts;

--3. What are the 25th, 50th and 75th percentile values for the revenue per transaction?
WITH TransactionRevenue AS (
    SELECT 
        s.txn_id,
        SUM(s.price * s.qty * (1 - (CAST(s.discount AS NUMERIC)/100))) AS revenue
    FROM balanced_tree.sales AS s
    GROUP BY s.txn_id
)

, Percentiles AS (
    SELECT
        txn_id,
        revenue,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY revenue) OVER () AS P25,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY revenue) OVER () AS P50,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY revenue) OVER () AS P75
    FROM TransactionRevenue
)

SELECT
    DISTINCT
    P25 AS "25th Percentile",
    P50 AS "50th Percentile",
    P75 AS "75th Percentile"
FROM Percentiles;


--4. What is the average discount value per transaction?
WITH get_discounts AS( 
SELECT 
	txn_id,
	SUM((price * qty) * (CAST(discount AS NUMERIC) / 100)) AS discounts
FROM balanced_tree.sales
GROUP BY txn_id
)
SELECT ROUND(AVG(discounts),2) AS avg_discount
FROM get_discounts
		
--5. What is the percentage split of all transactions for members vs non-members?
WITH MemberTransactionCounts AS (
    SELECT 
        member,
        COUNT(DISTINCT txn_id) AS transaction_count
    FROM balanced_tree.sales
    GROUP BY member
)

SELECT 
    member,
    transaction_count,
    (transaction_count * 100.0 / SUM(transaction_count) OVER()) AS percentage
FROM MemberTransactionCounts;

--6. What is the average revenue for member transactions and non-member transactions?

WITH TransactionRevenue AS (
    SELECT 
        s.txn_id,
        s.member,
        SUM(s.price * s.qty * (1 - CAST(s.discount AS NUMERIC) / 100)) AS revenue
    FROM balanced_tree.sales AS s
    GROUP BY s.txn_id, s.member
)

SELECT 
    member,
    AVG(revenue) AS average_revenue
FROM TransactionRevenue
GROUP BY member;


--PRODUCT ANALYSIS

--1. What are the top 3 products by total revenue before discount?
SELECT TOP 3
	pd.product_name,
	SUM(s.price * s.qty) AS revenue
FROM balanced_tree.sales s
JOIN balanced_tree.product_details pd ON pd.product_id=s.prod_id
GROUP BY product_name
ORDER BY revenue DESC;

--2. What is the total quantity, revenue and discount for each segment?
SELECT
	pd.segment_id,
	pd.segment_name,
	SUM(s.qty) AS total_quantity,
	SUM(s.price * s.qty) AS total_revenue,
	ROUND(SUM((s.price * s.qty) * (CAST(s.discount AS NUMERIC) / 100)), 2 ) AS total_item_discounts
FROM balanced_tree.sales s
JOIN balanced_tree.product_details pd ON pd.product_id=s.prod_id
GROUP BY segment_id,segment_name
ORDER BY total_quantity DESC;

--3. What is the top selling product for each segment?

WITH get_segments_revenue AS (
    SELECT 
        pd.segment_name,
        pd.product_name,
        SUM(s.qty) AS total_qty
    FROM balanced_tree.sales s
    JOIN balanced_tree.product_details pd ON pd.product_id = s.prod_id
    GROUP BY pd.segment_name, pd.product_name
)

, RankedProducts AS (
    SELECT 
        segment_name,
        product_name,
        total_qty,
        ROW_NUMBER() OVER(PARTITION BY segment_name ORDER BY total_qty DESC) AS product_rank
    FROM get_segments_revenue
)

SELECT 
    segment_name,
    product_name,
    total_qty
FROM RankedProducts
WHERE product_rank = 1;

--4. What is the total quantity, revenue and discount for each category?
SELECT
	pd.category_name,
    SUM(s.qty) AS total_qty,
	SUM(s.price * s.qty * (1 - CAST(s.discount AS NUMERIC) / 100)) AS total_revenue
FROM balanced_tree.sales s
JOIN balanced_tree.product_details pd ON pd.product_id = s.prod_id
GROUP BY category_name

--5. What is the top selling product for each category?
WITH get_category_revenue AS (
SELECT
	pd.category_name,
	pd.product_name,
    SUM(s.qty) AS total_qty
FROM balanced_tree.sales s
JOIN balanced_tree.product_details pd ON pd.product_id = s.prod_id
GROUP BY category_name,product_name
),

ranked_categories AS (
SELECT 
	category_name,
	product_name,
	total_qty,
	ROW_NUMBER() OVER(PARTITION BY category_name ORDER BY total_qty DESC) AS  category_rank
FROM get_category_revenue
)
SELECT 
    category_name,
    product_name,
    total_qty
FROM ranked_categories
WHERE category_rank = 1;


--6. What is the percentage split of revenue by product for each segment?
WITH ProductSegmentRevenue AS (
    SELECT 
        pd.segment_name,
        pd.product_name,
        SUM(s.price * s.qty * (1 - CAST(s.discount AS NUMERIC) / 100)) AS product_revenue
    FROM balanced_tree.sales AS s
    JOIN balanced_tree.product_details AS pd ON pd.product_id = s.prod_id
    GROUP BY pd.segment_name, pd.product_name
)

, SegmentTotalRevenue AS (
    SELECT 
        segment_name,
        SUM(product_revenue) AS total_segment_revenue
    FROM ProductSegmentRevenue
    GROUP BY segment_name
)

SELECT 
    psr.segment_name,
    psr.product_name,
    psr.product_revenue,
    (psr.product_revenue * 100.0 / str.total_segment_revenue) AS revenue_percentage
FROM ProductSegmentRevenue AS psr
JOIN SegmentTotalRevenue AS str ON psr.segment_name = str.segment_name
ORDER BY psr.segment_name, revenue_percentage DESC;

--7. What is the percentage split of revenue by segment for each category?
WITH SegmentCategoryRevenue AS (
    SELECT 
        pd.category_name,
        pd.segment_name,
        SUM(s.price * s.qty * (1 - CAST(s.discount AS NUMERIC) / 100)) AS segment_revenue
    FROM balanced_tree.sales AS s
    JOIN balanced_tree.product_details AS pd ON pd.product_id = s.prod_id
    GROUP BY pd.category_name, pd.segment_name
)

, CategoryTotalRevenue AS (
    SELECT 
        category_name,
        SUM(segment_revenue) AS total_category_revenue
    FROM SegmentCategoryRevenue
    GROUP BY category_name
)

SELECT 
    scr.category_name,
    scr.segment_name,
    scr.segment_revenue,
    (scr.segment_revenue * 100.0 / ctr.total_category_revenue) AS revenue_percentage
FROM SegmentCategoryRevenue AS scr
JOIN CategoryTotalRevenue AS ctr ON scr.category_name = ctr.category_name
ORDER BY scr.category_name, revenue_percentage DESC;

--8. What is the percentage split of total revenue by category?
WITH CategoryRevenue AS (
    SELECT 
        pd.category_name,
        SUM(s.price * s.qty * (1 - CAST(s.discount AS NUMERIC) / 100)) AS category_revenue
    FROM balanced_tree.sales AS s
    JOIN balanced_tree.product_details AS pd ON pd.product_id = s.prod_id
    GROUP BY pd.category_name
)

, TotalRevenue AS (
    SELECT 
        SUM(category_revenue) AS total_revenue
    FROM CategoryRevenue
)

SELECT 
    cr.category_name,
    cr.category_revenue,
    (cr.category_revenue * 100.0 / tr.total_revenue) AS revenue_percentage
FROM CategoryRevenue AS cr
CROSS JOIN TotalRevenue AS tr
ORDER BY revenue_percentage DESC;

--9. What is the total transaction “penetration” for each product? (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)
WITH ProductTransactions AS (
    SELECT 
        s.prod_id,
        COUNT(DISTINCT s.txn_id) AS product_txn_count
    FROM balanced_tree.sales AS s
    GROUP BY s.prod_id
)

, TotalTransactions AS (
    SELECT 
        COUNT(DISTINCT txn_id) AS total_txn_count
    FROM balanced_tree.sales
)

SELECT 
    pt.prod_id,
    pd.product_name,
    pt.product_txn_count,
    (pt.product_txn_count * 100.0 / tt.total_txn_count) AS penetration_percentage
FROM ProductTransactions AS pt
JOIN balanced_tree.product_details AS pd ON pd.product_id = pt.prod_id
CROSS JOIN TotalTransactions AS tt
ORDER BY penetration_percentage DESC;

--10. What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?
WITH TripleProductCombinations AS (
    SELECT 
        s1.txn_id,
        s1.prod_id AS product1,
        s2.prod_id AS product2,
        s3.prod_id AS product3
    FROM balanced_tree.sales AS s1
    JOIN balanced_tree.sales AS s2 ON s1.txn_id = s2.txn_id AND s1.prod_id < s2.prod_id
    JOIN balanced_tree.sales AS s3 ON s1.txn_id = s3.txn_id AND s2.prod_id < s3.prod_id
)

, CombinationCounts AS (
    SELECT 
        product1,
        product2,
        product3,
        COUNT(*) AS combination_count
    FROM TripleProductCombinations
    GROUP BY product1, product2, product3
)

SELECT TOP 1
    product1,
    product2,
    product3,
    combination_count
FROM CombinationCounts
ORDER BY combination_count DESC

