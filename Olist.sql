CREATE TABLE Olist.GEOLOCATION
(
	geolocation_zip_code_prefix INT,
	geolocation_lat DOUBLE,
	geolocation_lng DOUBLE,
	geolocation_city VARCHAR(50),
	geolocation_state VARCHAR(50)
);

-- Show column names
SELECT COLUMN_NAME, ORDINAL_POSITION, COLUMN_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = N'GEOLOCATION'
ORDER BY ORDINAL_POSITION;

-- No. of orders and basket sizes for each unique customer
SELECT 
		c.customer_unique_id AS UNIQUE_CUSTOMER,
		COUNT(DISTINCT o.order_id) AS NO_OF_ORDERS,
		ROUND(SUM(op.payment_value),2) AS TOTAL_ORDER_VALUE
	FROM Olist.ORDERS o
	LEFT JOIN Olist.ORDER_PAYMENTS op
		ON o.order_id = op.order_id
	LEFT JOIN Olist.CUSTOMERS c
		ON c.customer_id = o.customer_id
	GROUP BY 
		UNIQUE_CUSTOMER -- use unique IDs to identify repeat customers
	ORDER BY
		TOTAL_ORDER_VALUE DESC,
		NO_OF_ORDERS DESC;	
	
-- Average no. of orders made by each customer per year
SELECT 
		YEAR(o.order_purchase_timestamp) AS `YEAR`,
		COUNT(DISTINCT o.order_id) / COUNT(DISTINCT c.customer_unique_id) AS AVG_NO_OF_ORDERS
	FROM Olist.orders o
	LEFT JOIN Olist.customers c
		ON o.customer_id = c.customer_id
	GROUP BY 
		YEAR(o.order_purchase_timestamp)
	ORDER BY
		`YEAR` ASC;

-- For calculating conversion rate: proportion of users (unique customer accounts) with purchases
SELECT
		c.customer_unique_id AS CUSTOMER,		
		COUNT(DISTINCT oi.order_item_id) AS NO_OF_ITEMS
	FROM Olist.orders o
	LEFT JOIN Olist.order_items oi
		ON o.order_id = oi.order_id
	LEFT JOIN Olist.customers c
		ON o.customer_id = c.customer_id
	GROUP BY 
		c.customer_unique_id;
	
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

-- Total no. of customers, orders, and items ordered on each day
SELECT 
		CAST(o.order_purchase_timestamp AS DATE) AS `DATE`, 
		COUNT(DISTINCT c.customer_unique_id) AS NO_OF_CUSTOMERS, -- use unique IDs to identify repeat customers
		COUNT(DISTINCT o.order_id) AS NO_OF_ORDERS, 
		COUNT(oi.order_item_id) AS NO_OF_ITEMS
	FROM Olist.ORDERS o
	LEFT JOIN Olist.ORDER_ITEMS oi 
		ON o.order_id = oi.order_id
	LEFT JOIN Olist.CUSTOMERS c
		ON c.customer_id = o.customer_id
	GROUP BY 
		CAST(o.order_purchase_timestamp AS DATE)
	ORDER BY o.order_purchase_timestamp ASC;
	
-- Order size of each order 
-- in local currency (Brazilian reais, BRL)
-- Box plots to show monthly distribution
SELECT 
		CAST(o.order_purchase_timestamp AS DATE) AS `DATE`,
		ROUND(op.payment_value,2) AS ORDER_VALUE
	FROM Olist.ORDERS o
	LEFT JOIN Olist.ORDER_PAYMENTS op
		ON o.order_id = op.order_id
	ORDER BY o.order_purchase_timestamp ASC;

-- Sales on each day, based on price paid
SELECT 
		DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m-%d') AS `DAY`, 
		ROUND(SUM(op.payment_value),2) AS REVENUE
	FROM 
		Olist.ORDERS o
	LEFT JOIN Olist.ORDER_PAYMENTS op
		ON o.order_id = op.order_id
	GROUP BY 
		YEAR(o.order_purchase_timestamp), 
		MONTH(o.order_purchase_timestamp),
		DAY(o.order_purchase_timestamp)
	ORDER BY o.order_purchase_timestamp ASC;

-- Sales in different quarters each year, based on price paid
-- Grouped bar chart
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

-- Top grossing product category for each month, and the proportion of total daily revenue arising from it
SELECT 
		`MONTH`,
		PRODUCT_CATEGORY,
		ROUND(CATEGORY_REVENUE,2),
		ROUND(DAILY_REVENUE,2),
		ROUND((CATEGORY_REVENUE / DAILY_REVENUE),2) AS REVENUE_PROPORTION_FROM_CATEGORY
	FROM
	(SELECT 
			DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m') AS `MONTH`, 
			t.product_category_name_english AS PRODUCT_CATEGORY,
			SUM(oi.price) AS CATEGORY_REVENUE,
			SUM(SUM(oi.price)) OVER (PARTITION BY DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m')) AS DAILY_REVENUE,
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
		by_category.REVENUE_RANK IN (1)
	AND
		PRODUCT_CATEGORY IS NOT NULL -- exclude blank rows
	ORDER BY
		`MONTH` ASC,
		CATEGORY_REVENUE DESC;

-- (Many days with blank rows are those with few orders that were cancelled)
SELECT 
		CAST(o.order_purchase_timestamp AS DATE) AS PURCHASE_DATE, 
		COUNT(o.order_id) AS NO_OF_ORDERS,
		o.order_status
	FROM olist.orders o
	GROUP BY 
		CAST(o.order_purchase_timestamp AS DATE)
	HAVING 
		COUNT(o.order_id) = 1
	ORDER BY
		CAST(o.order_purchase_timestamp AS DATE);

-- Total no. of days on which each product category was the highest-grossing category
-- and the revenue generated from each product category
SELECT 
		PRODUCT_CATEGORY,
		COUNT(REVENUE_RANK) AS NO_OF_DAYS,
		ROUND(SUM(CATEGORY_REVENUE),2) AS TOTAL_REVENUE
	FROM
	(SELECT 
			CAST(o.order_purchase_timestamp AS DATE) AS PURCHASE_DATE,
			t.product_category_name_english AS PRODUCT_CATEGORY,
			SUM(oi.price) AS CATEGORY_REVENUE,
			SUM(SUM(oi.price)) OVER (PARTITION BY CAST(o.order_purchase_timestamp AS DATE)) AS DAILY_REVENUE,
			RANK() 
				OVER (
					PARTITION BY CAST(o.order_purchase_timestamp AS DATE) 
					ORDER BY SUM(oi.price) DESC) AS REVENUE_RANK
		FROM olist.orders o
		LEFT JOIN olist.order_items oi
			ON o.order_id = oi.order_id
		LEFT JOIN olist.products p
			ON oi.product_id = p.product_id
		LEFT JOIN olist.`translation` t
			ON p.product_category_name = t.product_category_name
		GROUP BY
			CAST(o.order_purchase_timestamp AS DATE),
			t.product_category_name_english) AS by_category
	WHERE 
		by_category.REVENUE_RANK IN (1)
	AND
		PRODUCT_CATEGORY IS NOT NULL -- exclude blank ROWS
	GROUP BY
		PRODUCT_CATEGORY
	ORDER BY
		COUNT(REVENUE_RANK) DESC;

-- Created zip code area list from https://pt.wikipedia.org/wiki/C%C3%B3digo_de_Endere%C3%A7amento_Postal#Zonas_Postais_e_Faixas_de_CEP,
-- as the original geolocation dataset contains unclean data.
-- then join with original geolocation dataset to obtain average latitudes and longitudes (multiple are given for each zip code area)
-- to create new table
SELECT 
			g.geolocation_zip_code_prefix AS ZIP_CODE_PREFIX, 
			AVG(g.geolocation_lat) AS LATITUDE, -- use average latitude
			AVG(g.geolocation_lng) AS LONGITUDE, -- use average longitude
			z.state AS STATE, 
			z.state_code AS STATE_CODE, 
			z.city AS CITY
		FROM olist.geolocation g
		LEFT JOIN olist.zipcodes z
		ON 
			g.geolocation_zip_code_prefix >= z.zip_code_start
		AND
			g.geolocation_zip_code_prefix <= z.zip_code_end
		GROUP BY g.geolocation_zip_code_prefix
		ORDER BY g.geolocation_zip_code_prefix;

-- Some customers and sellers have zip codes that do not exist within the locations table
SELECT DISTINCT c.customer_zip_code_prefix FROM Olist.CUSTOMERS c
WHERE c.customer_zip_code_prefix NOT IN 
(SELECT l.zip_code_prefix FROM Olist.locations l)
ORDER BY c.customer_zip_code_prefix;

SELECT DISTINCT s.seller_zip_code_prefix FROM Olist.SELLERS s
WHERE s.seller_zip_code_prefix NOT IN 
(SELECT l.zip_code_prefix FROM Olist.locations l)
ORDER BY s.seller_zip_code_prefix;


-- Total revenue, based on price paid, by state
SELECT 
		c.customer_zip_code_prefix,
		states.STATE_CODE,
		states.STATE,
		states.LATITUDE,
		states.LONGITUDE,
		ROUND(SUM(op.payment_value),2) AS REVENUE
	FROM Olist.CUSTOMERS c
	LEFT JOIN Olist.locations l
		ON c.customer_zip_code_prefix = l.ZIP_CODE_PREFIX
	LEFT JOIN
		-- Select the smallest postcodes to represent for each state,
		-- because they tend to be (near) the centres of the largest cities in each state,
		-- e.g. 1001 is in the city centre of São Paulo
		(SELECT l.ZIP_CODE_PREFIX, l.LATITUDE, l.LONGITUDE, l.STATE, l.STATE_CODE
			FROM Olist.locations l 
			WHERE l.ZIP_CODE_PREFIX IN
				(SELECT min(l.ZIP_CODE_PREFIX) FROM Olist.locations l
					GROUP BY l.STATE_CODE)) AS states
		ON l.STATE_CODE = states.STATE_CODE
	LEFT JOIN Olist.ORDERS o
		ON o.customer_id = c.customer_id
	LEFT JOIN Olist.ORDER_PAYMENTS op
		ON o.order_id = op.order_id
	WHERE
		CAST(o.order_purchase_timestamp AS DATE) IS NOT NULL
	GROUP BY 
		states.STATE_CODE
	ORDER BY states.STATE_CODE ASC;

-- Revenue on each day, based on price paid, by zip code area
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

-- Time taken from payment to delivery
-- Grouped by quarter in Tableau to see quarterly distribution
SELECT 
		o.order_id, 
		CAST(o.order_purchase_timestamp AS DATE) PAYMENT_DATE,
		CAST(o.order_delivered_customer_date AS DATE) ACTUAL_DATE,
		DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS PAYMENT_DELIVERY_DIFF
	FROM
		Olist.ORDERS o
	WHERE
		DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) IS NOT NULL
	ORDER BY
		CAST(o.order_purchase_timestamp AS DATE);

-- Did delivery time forecasts become more accurate over time?
-- Difference between actual and estimated delivery date
-- Will be grouped by month in tableau to see monthly distribution
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

-- Total freight value for each zip code
SELECT
		c.customer_zip_code_prefix AS CUSTOMER_ZIP_CODE_PREFIX
		l.latitude AS CUSTOMER_LATITUDE,
		l.longitude AS CUSTOMER_LONGITUDE,
		ROUND(SUM(oi.freight_value),2) AS TOTAL_FREIGHT_VALUE
	FROM Olist.ORDER_PAYMENTS op 
	LEFT JOIN Olist.ORDERS o
		ON o.order_id = op.order_id
	LEFT JOIN Olist.ORDER_ITEMS oi
		ON oi.order_id = o.order_id
	LEFT JOIN Olist.CUSTOMERS c
		ON c.customer_id = o.customer_id
	LEFT JOIN Olist.locations l
		ON l.zip_code_prefix = c.customer_zip_code_prefix
	GROUP BY
		l.zip_code_prefix
	ORDER BY 
		c.customer_zip_code_prefix ASC;

-- Volume of product transported from sellers to customers, 
-- in kilograms,
-- assuming products are always physically stored at sellers' locations
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
	
-- Total freight value transported from sellers to customers, 
-- in local currency (Brazilian reais, BRL),
-- assuming products are always physically stored at sellers' locations
-- by state
SELECT 
		CUSTOMER_STATE, SELLER_STATE,
		CUSTOMER_STATE_LAT, CUSTOMER_STATE_LNG,
		SELLER_STATE_LAT, SELLER_STATE_LNG,
		ROUND(SUM(FREIGHT_VALUE), 2) AS TOTAL_FREIGHT_VALUE
	FROM	
		(SELECT 
				oi.order_id AS ORDER_ID,
				c.customer_state AS CUSTOMER_STATE,
				state_coords.STATE_LAT AS CUSTOMER_STATE_LAT, 
				state_coords.STATE_LNG AS CUSTOMER_STATE_LNG,
				oi.FREIGHT_VALUE AS FREIGHT_VALUE
			FROM Olist.ORDERS o
			LEFT JOIN Olist.ORDER_ITEMS oi
				ON oi.order_id = o.order_id
			LEFT JOIN Olist.CUSTOMERS c
				ON c.customer_id = o.customer_id
			LEFT JOIN 
				(SELECT 
						l.STATE_CODE, 
						l.STATE, 
						AVG(LATITUDE) STATE_LAT,
						AVG(LONGITUDE) STATE_LNG
					FROM Olist.locations l
					GROUP BY
						l.STATE_CODE) state_coords
				ON state_coords.state_code = c.customer_state) customer
	INNER JOIN -- Both customer and seller should have order_id
		(SELECT 
				oi.order_id AS ORDER_ID,
				s.seller_state AS SELLER_STATE,
				state_coords.STATE_LAT AS SELLER_STATE_LAT, 
				state_coords.STATE_LNG AS SELLER_STATE_LNG
			FROM Olist.ORDER_ITEMS oi
			LEFT JOIN Olist.SELLERS s
				ON s.seller_id = oi.seller_id
			LEFT JOIN 
				(SELECT 
						l.STATE_CODE, 
						l.STATE, 
						AVG(LATITUDE) STATE_LAT,
						AVG(LONGITUDE) STATE_LNG
					FROM Olist.locations l
					GROUP BY
						l.STATE_CODE) state_coords
			ON state_coords.state_code = s.seller_state) seller		
	ON customer.ORDER_ID = seller.ORDER_ID
	GROUP BY 
		customer.CUSTOMER_STATE,
		seller.SELLER_STATE
	ORDER BY
		customer.CUSTOMER_STATE ASC,
		seller.SELLER_STATE ASC;

-- Shipping distance (Euclidean distance calculated from customer and seller coordinates)
SELECT 
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

-- Review score trends, based on average review score per day
SELECT 
		CAST(o.order_purchase_timestamp AS DATE) AS `DATE`, 
		AVG(or.review_score) AS AVG_SCORE
	FROM Olist.ORDERS o
	LEFT JOIN Olist.ORDER_REVIEWS `or`
		ON o.order_id = `or`.order_id
	WHERE
		OR.review_score IS NOT NULL
	GROUP BY 
		CAST(o.order_purchase_timestamp AS DATE)
	ORDER BY o.order_purchase_timestamp ASC;

-- Review score trends, based on percentage of each score (1-5) per day
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
