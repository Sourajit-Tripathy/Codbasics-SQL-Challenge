--- Query 1:

-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT * FROM gdb023.dim_customer;

SELECT DISTINCT market FROM gdb023.dim_customer
WHERE customer = 'Atliq Exclusive' AND region = 'APAC';

----------------------------------------------------------------------------------------------------------
--- Query 2:
--- 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields,
--- unique_products_2020, unique_products_2021, percentage_chg

WITH unq_prd_20 AS (
SELECT COUNT(DISTINCT dp.product_code) AS unique_products_2020 
FROM gdb023.dim_product dp
JOIN gdb023.fact_sales_monthly sm
ON dp.product_code = sm.product_code
WHERE fiscal_year = 2020
),

unq_prd_21 AS (
SELECT COUNT(DISTINCT dp.product_code) AS unique_products_2021
FROM gdb023.dim_product dp
JOIN gdb023.fact_sales_monthly sm
ON dp.product_code = sm.product_code
WHERE fiscal_year = 2021
)

SELECT unique_products_2020, unique_products_2021,
ROUND((unique_products_2021-unique_products_2020)*100/unique_products_2020,2) AS percentage_chg 
FROM unq_prd_20, unq_prd_21;

----------------------------------------------------------------------------------------------------------
--- Quary 3:-
---  Provide a report with all the unique product counts for each segment and
--- sort them in descending order of product counts. The final output contains 2 fields,
----             segment
----             product_count

SELECT * FROM gdb023.dim_product;

SELECT segment, COUNT(DISTINCT product_code) AS product_count
FROM gdb023.dim_product 
GROUP BY segment
ORDER BY product_count DESC;

---------------------------------------------------------------------------------------------------------
--- Quary 4:-
---  Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
---  The final output contains these fields,
---      segment, product_count_2020, product_count_2021, difference

WITH prd_count_20 AS (
SELECT segment, COUNT(DISTINCT dp.product_code) AS product_count_2020
FROM gdb023.dim_product as dp
JOIN gdb023.fact_sales_monthly as sm
ON dp.product_code = sm.product_code
WHERE fiscal_year = 2020
GROUP BY segment
ORDER BY segment
),

prd_count_21 AS (
SELECT segment, COUNT(DISTINCT dp.product_code) AS product_count_2021
FROM gdb023.dim_product as dp
JOIN gdb023.fact_sales_monthly as sm
ON dp.product_code = sm.product_code
WHERE fiscal_year = 2021
GROUP BY segment
ORDER BY segment
)

SELECT *, (product_count_2021 - product_count_2020) AS difference
FROM prd_count_20 JOIN  prd_count_21
USING (segment)
ORDER BY difference DESC;

---------------------------------------------------------------------------------------------------------
--- Quary 5:-
---  Get the products that have the highest and lowest manufacturing costs.
---    The final output should contain these fields,
---    product_code, product, manufacturing_cost

SELECT * FROM gdb023.fact_manufacturing_cost;

SELECT dp.product_code as product_code, dp.product as product, 
mc.manufacturing_cost as manufacturing_cost
FROM gdb023.dim_product AS dp
INNER JOIN gdb023.fact_manufacturing_cost AS mc
ON dp.product_code = mc.product_code
WHERE mc.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM gdb023.fact_manufacturing_cost)
OR mc.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM gdb023.fact_manufacturing_cost)
ORDER BY mc.manufacturing_cost DESC;

---------------------------------------------------------------------------------------------------
--- Quary 6:- 
---   Generate a report which contains the top 5 customers who received an average high 
---    high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.
---    The final output contains these fields,
---     customer_code, customer, average_discount_percentage

SELECT * FROM gdb023.fact_pre_invoice_deductions; 

SELECT dc.customer_code, dc.customer, ROUND(AVG(fid.pre_invoice_discount_pct)*100,2) AS average_discount_percentage
FROM gdb023.dim_customer as dc
JOIN gdb023.fact_pre_invoice_deductions as fid
ON dc.customer_code = fid.customer_code
WHERE fiscal_year = 2021 AND market = 'India'
GROUP BY customer_code
ORDER BY pre_invoice_discount_pct DESC
LIMIT 5;

------------------------------------------------------------------------------------------------------------
--- Quary 7:
---   Get the complete report of the Gross sales amount for the customer 'Atliq Exclusive' for each month
---    This analysis helps to get an idea of low and high-performing months and take stragic decisions.
----   The final report contains these columns:
----   Month, Year, Gross sales Amount

SELECT * FROM gdb023.fact_gross_price;

SELECT MONTHNAME(sm.date) as Month, YEAR(sm.date) as Year, 
ROUND(SUM(sm.sold_quantity * gp.gross_price)/100000,2) as Gross_sales_amount   /* In Lakhs */
FROM gdb023.fact_sales_monthly as sm
INNER JOIN gdb023.fact_gross_price as gp
USING (product_code, fiscal_year)
INNER JOIN gdb023.dim_customer as dc
USING (customer_code)
WHERE dc.customer = "Atliq Exclusive"
GROUP BY Month, Year 
ORDER BY Gross_sales_amount DESC;

--------------------------------------------------------------------------------------------------------
--- Quary 8:
---   In which quarter of 2020, got the maximum total_sold_quantity? The final
---    output contains these fields sorted by the total_sold_quantity,
---      Quarter, total_sold_quanity

SELECT * FROM gdb023.fact_sales_monthly;

SELECT 
CASE WHEN month(date) IN (9,10,11) THEN 'Quarter1'
     WHEN month(date) IN (12,1,2) then 'Quarter2'
     WHEN month(date) IN (3,4,5) then 'Quarter3'
			WHEN month(date) IN (6,7,8) then 'Quarter4'
     END as 'Quarter',
     SUM(sold_quantity) as total_sold_quantity
     FROM gdb023.fact_sales_monthly
     WHERE fiscal_year = '2020'
     GROUP BY Quarter 
     ORDER BY total_sold_quantity DESC; 
     
---------------------------------------------------------------------------------------------
--- Quary 9:
--- Which channel helped to bring more gross sales in the fiscal year 2021 and the
--- percentage of contribution? The final output contains these fields, 
---    channel, gross_sales_min, percentage

SELECT * FROM gdb023.fact_sales_monthly;

WITH q1 AS (
           SELECT dc.channel as channel, 
           ROUND((SUM(sm.sold_quantity * gp.gross_price))/1000000,2) as gross_sales_min
           FROM gdb023.dim_customer as dc
           JOIN gdb023.fact_sales_monthly as sm
           USING (customer_code)
           JOIN gdb023.fact_gross_price as gp
           USING (product_code, fiscal_year)
           WHERE fiscal_year = 2021
           GROUP BY channel
           ) 
SELECT channel, gross_sales_min, CONCAT(ROUND(gross_sales_min/SUM(gross_sales_min) over()*100,2),'%') as percentage 
FROM q1
ORDER BY percentage DESC; 

--------------------------------------------------------------------------------------------------------------------
--- Quary 10:
---  Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?
---  The final output contains these fields,
---    division, product_code, product, total_sold_quantity, rank_order

WITH q1 AS (
SELECT dp.division as division, dp.product as product, dp.product_code, 
SUM(sold_quantity) as total_sold_quantity
FROM gdb023.dim_product as dp
JOIN gdb023.fact_sales_monthly as sm
USING (product_code)
WHERE sm.fiscal_year = 2021
GROUP BY division, dp.product_code, product
),

q2 AS (
SELECT *, DENSE_RANK() OVER(partition BY division ORDER BY total_sold_quantity DESC) rank_order
FROM q1)

SELECT * FROM q2
WHERE rank_order < 4; 
  
------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------ 
