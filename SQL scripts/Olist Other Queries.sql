-- Highest-grossing product category for each month, and the proportion of total daily revenue arising from it
SELECT 
		`MONTH`,
		PRODUCT_CATEGORY,
		ROUND(CATEGORY_REVENUE,2) AS CATEGORY_REVENUE_MONTH,
		ROUND(MONTHLY_REVENUE,2) AS TOTAL_REVENUE_MONTH,
		ROUND((CATEGORY_REVENUE / MONTHLY_REVENUE),2) AS REVENUE_PROPORTION_FROM_CATEGORY
	FROM
	(SELECT 
			DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m') AS `MONTH`, 
			t.product_category_name_english AS PRODUCT_CATEGORY,
			SUM(oi.price) AS CATEGORY_REVENUE,
			-- Total revenue across all product categories
			SUM(SUM(oi.price)) OVER (PARTITION BY DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m')) AS MONTHLY_REVENUE,
			-- Rank product categories by sales for each month
			RANK() 
				OVER (
					PARTITION BY DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m')
					ORDER BY SUM(oi.price) DESC) AS REVENUE_RANK
		FROM olist.orders o
		LEFT JOIN olist.order_items oi
			ON o.order_id = oi.order_id
		LEFT JOIN olist.products p
			ON oi.product_id = p.product_id
		LEFT JOIN olist.`translation` t
			ON p.product_category_name = t.product_category_name
		GROUP BY
			DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m'),
			t.product_category_name_english) AS by_category
	WHERE 
		by_category.REVENUE_RANK IN (1) -- Obtain the highest-grossing category for the month
	AND
		PRODUCT_CATEGORY IS NOT NULL -- exclude blank rows
	ORDER BY
		`MONTH` ASC,
		CATEGORY_REVENUE DESC;

-- Shipping distances for each order (Euclidean distance calculated from customer and seller coordinates)
SELECT 
		customer.ORDER_ID,
		customer.CUSTOMER_ZIP_CODE_PREFIX,
		SQRT(POWER((CUSTOMER_LATITUDE-SELLER_LATITUDE),2) + POWER((customer.CUSTOMER_LONGITUDE-seller.SELLER_LONGITUDE),2)) AS SHIPPING_DISTANCE,
		customer.CUSTOMER_LATITUDE, customer.CUSTOMER_LONGITUDE,
		seller.SELLER_LATITUDE, seller.SELLER_LONGITUDE
	FROM	
		(SELECT 
				oi.order_id AS ORDER_ID,
				l.ZIP_CODE_PREFIX AS CUSTOMER_ZIP_CODE_PREFIX,
				l.LATITUDE AS CUSTOMER_LATITUDE,
				l.LONGITUDE AS CUSTOMER_LONGITUDE,
				oi.FREIGHT_VALUE AS FREIGHT_VALUE
			FROM Olist.ORDER_PAYMENTS op 
			LEFT JOIN Olist.ORDERS o
				ON o.order_id = op.order_id
			LEFT JOIN Olist.ORDER_ITEMS oi
				ON oi.order_id = o.order_id
			LEFT JOIN Olist.CUSTOMERS c
				ON c.customer_id = o.customer_id
			LEFT JOIN Olist.locations AS l
				ON c.customer_zip_code_prefix = l.ZIP_CODE_PREFIX) customer
	INNER JOIN -- Both customer and seller should have order_id
		(SELECT 
				oi.order_id AS ORDER_ID,
				l.ZIP_CODE_PREFIX AS SELLER_ZIP_CODE_PREFIX,
				l.LATITUDE AS SELLER_LATITUDE,
				l.LONGITUDE AS SELLER_LONGITUDE
		FROM Olist.ORDER_ITEMS oi
		LEFT JOIN Olist.SELLERS s
			ON s.seller_id = oi.seller_id
		LEFT JOIN Olist.locations AS l
			ON s.seller_zip_code_prefix = l.ZIP_CODE_PREFIX) seller		
	ON customer.ORDER_ID = seller.ORDER_ID
	ORDER BY
		SQRT(POWER((customer.CUSTOMER_LATITUDE-seller.SELLER_LATITUDE),2) + POWER((customer.CUSTOMER_LONGITUDE-seller.SELLER_LONGITUDE),2)) DESC;

-- Did delivery time forecasts become more accurate over time?
-- Difference between actual and estimated delivery date
-- Can be grouped by month in tableau to see monthly distribution
SELECT 
		o.order_id, 
		CAST(o.order_purchase_timestamp AS DATE) PAYMENT_DATE,
		CAST(o.order_estimated_delivery_date AS DATE) ESTIMATED_DATE,
		CAST(o.order_delivered_customer_date AS DATE) ACTUAL_DATE,
		DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS ACT_EST_DELIVERY_DIFF
	FROM
		Olist.ORDERS o
	WHERE
		o.order_delivered_customer_date IS NOT NULL
	ORDER BY
		o.order_purchase_timestamp;

-- Sales in different quarters each year, based on price paid
-- Can be visualised as a grouped bar chart to compare sales in each quarter across different years
SELECT
		CASE 
			WHEN RIGHT(`MONTH`,2) IN ('01','02','03') THEN 'Q1' 
			WHEN RIGHT(`MONTH`,2) IN ('04','05','06') THEN 'Q2'
			WHEN RIGHT(`MONTH`,2) IN ('07','08','09') THEN 'Q3'
			WHEN RIGHT(`MONTH`,2) IN ('10','11','12') THEN 'Q4'
		END AS `QUARTER`,
		`YEAR`,
		REVENUE
FROM
(SELECT
		YEAR(o.order_purchase_timestamp) AS `YEAR`,
		DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m') AS `MONTH`, 
		ROUND(SUM(op.payment_value),2) AS REVENUE
	FROM 
		Olist.ORDERS o
	LEFT JOIN Olist.ORDER_PAYMENTS op
		ON o.order_id = op.order_id
	GROUP BY 
		YEAR(o.order_purchase_timestamp), 
		MONTH(o.order_purchase_timestamp)) monthly_revenue
GROUP BY
	`YEAR`, 
	`QUARTER`
ORDER BY
	`QUARTER` ASC, 
	`YEAR` ASC;
	
-- Total sales by state, based on price paid
-- Some customers are not associated with zip codes
SELECT 
		l.STATE_CODE,
		l.STATE,
		ROUND(SUM(op.payment_value),2) AS REVENUE
	FROM Olist.CUSTOMERS c
	LEFT JOIN Olist.ORDERS o
		ON o.customer_id = c.customer_id
	LEFT JOIN Olist.ORDER_PAYMENTS op
		ON o.order_id = op.order_id
	LEFT JOIN Olist.locations l
		ON c.customer_zip_code_prefix = l.ZIP_CODE_PREFIX
	GROUP BY 
		l.STATE_CODE
	ORDER BY l.STATE_CODE ASC;

-- Total sales on each day by zip code, based on price paid
SELECT 
		CAST(o.order_purchase_timestamp AS DATE) AS `DATE`, 
		l.ZIP_CODE_PREFIX,
		l.LATITUDE,
		l.LONGITUDE,
		ROUND(SUM(op.payment_value),2) AS REVENUE
	FROM Olist.CUSTOMERS c
	LEFT JOIN Olist.locations AS l
		ON c.customer_zip_code_prefix = l.ZIP_CODE_PREFIX
	LEFT JOIN Olist.ORDERS o
		ON o.customer_id = c.customer_id
	LEFT JOIN Olist.ORDER_PAYMENTS op
		ON o.order_id = op.order_id
	WHERE
		CAST(o.order_purchase_timestamp AS DATE) IS NOT NULL
	GROUP BY 
		CAST(o.order_purchase_timestamp AS DATE),
		l.ZIP_CODE_PREFIX
	ORDER BY o.order_purchase_timestamp ASC;

-- Percentage of reviews with each score (1-5) per day
SELECT 
		CAST(o.order_purchase_timestamp AS DATE) AS `DATE`, 
		or.review_score SCORE,
		COUNT(or.review_score) AS VOTES,
		SUM(COUNT(or.review_score)) OVER (PARTITION BY CAST(o.order_purchase_timestamp AS DATE)) AS VOTES_DAY_TOTAL,
		COUNT(or.review_score) / 
			SUM(COUNT(or.review_score)) OVER (PARTITION BY CAST(o.order_purchase_timestamp AS DATE)) AS SCORE_PROPORTION
	FROM Olist.ORDERS o
	LEFT JOIN Olist.ORDER_REVIEWS `or`
		ON o.order_id = `or`.order_id
	WHERE
		OR.review_score IS NOT NULL
	GROUP BY 
		CAST(o.order_purchase_timestamp AS DATE),
		or.review_score
	ORDER BY 
		CAST(o.order_purchase_timestamp AS DATE) ASC,
		or.review_score ASC;

-- Highest-grossing sellers
SELECT 
		s.seller_id AS SELLER,
		ROUND(SUM(oi.price),2) AS SALES
	FROM Olist.sellers s
	LEFT JOIN Olist.ORDER_ITEMS oi
		ON oi.seller_id = s.seller_id
	GROUP BY
		s.seller_id
	ORDER BY
		SALES DESC;

-- Volume of product transported from sellers to customers, 
-- in kilograms,
-- assuming products are always physically stored at sellers' locations
-- Some customers are not associated with zip codes
SELECT 
		customer.CUSTOMER_ZIP_CODE_PREFIX, customer.CUSTOMER_LATITUDE, customer.CUSTOMER_LONGITUDE,
		seller.SELLER_ZIP_CODE_PREFIX, seller.SELLER_LATITUDE, seller.SELLER_LONGITUDE,
		ROUND(SUM(customer.PRODUCT_WEIGHT), 2) AS TOTAL_FREIGHT_VALUE
	FROM	
		(SELECT 
				p.product_ID AS PRODUCT_ID, 
				oi.order_id AS ORDER_ID,
				l.ZIP_CODE_PREFIX AS CUSTOMER_ZIP_CODE_PREFIX,
				l.LATITUDE AS CUSTOMER_LATITUDE,
				l.LONGITUDE AS CUSTOMER_LONGITUDE,
				p.product_weight_g AS PRODUCT_WEIGHT
			FROM Olist.PRODUCTS p 
			LEFT JOIN Olist.ORDER_ITEMS oi
				ON oi.product_id = p.product_id
			LEFT JOIN Olist.ORDERS o
				ON o.order_id = oi.order_id
			LEFT JOIN Olist.CUSTOMERS c
				ON c.customer_id = o.customer_id
			LEFT JOIN Olist.locations AS l
				ON c.customer_zip_code_prefix = l.ZIP_CODE_PREFIX) customer
	INNER JOIN -- Both customer and seller should have order_id
		(SELECT 
				oi.order_id AS ORDER_ID,
				l.ZIP_CODE_PREFIX AS SELLER_ZIP_CODE_PREFIX,
				l.LATITUDE AS SELLER_LATITUDE,
				l.LONGITUDE AS SELLER_LONGITUDE
		FROM Olist.ORDER_ITEMS oi
		LEFT JOIN Olist.SELLERS s
			ON s.seller_id = oi.seller_id
		LEFT JOIN Olist.locations AS l
			ON s.seller_zip_code_prefix = l.ZIP_CODE_PREFIX) seller		
	ON customer.ORDER_ID = seller.ORDER_ID
	GROUP BY 
		customer.CUSTOMER_ZIP_CODE_PREFIX,
		seller.SELLER_ZIP_CODE_PREFIX
	ORDER BY
		customer.CUSTOMER_ZIP_CODE_PREFIX ASC,
		seller.SELLER_ZIP_CODE_PREFIX ASC;

-- Total no. of shipments from sellers to customers,
-- assuming products are always physically stored at sellers' locations
-- Some customers are not associated with zip codes
SELECT 
		customer.CUSTOMER_ZIP_CODE_PREFIX, customer.CUSTOMER_LATITUDE, customer.CUSTOMER_LONGITUDE,
		seller.SELLER_ZIP_CODE_PREFIX, seller.SELLER_LATITUDE, seller.SELLER_LONGITUDE,
		COUNT(customer.SHIPMENT_DATE) AS NO_OF_SHIPMENTS
	FROM	
		(SELECT 
				oi.order_id AS ORDER_ID,
				l.ZIP_CODE_PREFIX AS CUSTOMER_ZIP_CODE_PREFIX,
				l.LATITUDE AS CUSTOMER_LATITUDE,
				l.LONGITUDE AS CUSTOMER_LONGITUDE,
				o.order_delivered_customer_date AS SHIPMENT_DATE
			FROM Olist.ORDERS o
			LEFT JOIN Olist.ORDER_ITEMS oi
				ON oi.order_id = o.order_id
			LEFT JOIN Olist.CUSTOMERS c
				ON c.customer_id = o.customer_id
			LEFT JOIN Olist.locations AS l
				ON c.customer_zip_code_prefix = l.ZIP_CODE_PREFIX) customer
	INNER JOIN -- Both customer and seller should have order_id
		(SELECT 
				oi.order_id AS ORDER_ID,
				l.ZIP_CODE_PREFIX AS SELLER_ZIP_CODE_PREFIX,
				l.LATITUDE AS SELLER_LATITUDE,
				l.LONGITUDE AS SELLER_LONGITUDE
		FROM Olist.ORDER_ITEMS oi
		LEFT JOIN Olist.SELLERS s
			ON s.seller_id = oi.seller_id
		LEFT JOIN Olist.locations AS l
			ON s.seller_zip_code_prefix = l.ZIP_CODE_PREFIX) seller		
	ON customer.ORDER_ID = seller.ORDER_ID
	GROUP BY 
		customer.CUSTOMER_ZIP_CODE_PREFIX,
		seller.SELLER_ZIP_CODE_PREFIX
	ORDER BY
		customer.CUSTOMER_ZIP_CODE_PREFIX ASC,
		seller.SELLER_ZIP_CODE_PREFIX ASC;

-- Total freight value transported from sellers to customers, 
-- in local currency (Brazilian reais, BRL),
-- assuming products are always physically stored at sellers' locations
-- Some customers are not associated with zip codes
SELECT 
		customer.CUSTOMER_ZIP_CODE_PREFIX, customer.CUSTOMER_LATITUDE, customer.CUSTOMER_LONGITUDE,
		seller.SELLER_ZIP_CODE_PREFIX, seller.SELLER_LATITUDE, seller.SELLER_LONGITUDE,
		ROUND(SUM(customer.FREIGHT_VALUE), 2) AS TOTAL_FREIGHT_VALUE
	FROM	
		(SELECT 
				oi.order_id AS ORDER_ID,
				l.ZIP_CODE_PREFIX AS CUSTOMER_ZIP_CODE_PREFIX,
				l.LATITUDE AS CUSTOMER_LATITUDE,
				l.LONGITUDE AS CUSTOMER_LONGITUDE,
				oi.FREIGHT_VALUE AS FREIGHT_VALUE
			FROM Olist.ORDER_PAYMENTS op 
			LEFT JOIN Olist.ORDERS o
				ON o.order_id = op.order_id
			LEFT JOIN Olist.ORDER_ITEMS oi
				ON oi.order_id = o.order_id
			LEFT JOIN Olist.CUSTOMERS c
				ON c.customer_id = o.customer_id
			LEFT JOIN Olist.locations AS l
				ON c.customer_zip_code_prefix = l.ZIP_CODE_PREFIX) customer
	INNER JOIN
		(SELECT 
				oi.order_id AS ORDER_ID,
				l.ZIP_CODE_PREFIX AS SELLER_ZIP_CODE_PREFIX,
				l.LATITUDE AS SELLER_LATITUDE,
				l.LONGITUDE AS SELLER_LONGITUDE
		FROM Olist.ORDER_ITEMS oi
		LEFT JOIN Olist.SELLERS s
			ON s.seller_id = oi.seller_id
		LEFT JOIN Olist.locations AS l
			ON s.seller_zip_code_prefix = l.ZIP_CODE_PREFIX) seller		
	ON customer.ORDER_ID = seller.ORDER_ID -- Both customer and seller should have order_id
	GROUP BY 
		customer.CUSTOMER_ZIP_CODE_PREFIX,
		seller.SELLER_ZIP_CODE_PREFIX
	ORDER BY
		customer.CUSTOMER_ZIP_CODE_PREFIX ASC,
		seller.SELLER_ZIP_CODE_PREFIX ASC;