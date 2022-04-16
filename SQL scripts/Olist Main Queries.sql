/* 
 * Corresponds to the "Customer Lifetime Value (CLV)", "Conversion Rate", and the "Median Basket Size" metrics,
 * and the "Log(Basket Size) vs. Log(No. of Orders)" plot
 * Results in the "CUSTOMER_ORDER_SIZE_VALUE.csv" data frame
 * 
 * No. of orders and basket sizes for each unique customer
 * 
 * Note that both variables were logarithmically transformed in Tableau rather than using SQL
 */
SELECT 
		c.customer_unique_id AS CUSTOMER, -- use unique IDs to identify repeat customers
		COUNT(DISTINCT o.order_id) AS NO_OF_ORDERS,
		ROUND(SUM(op.payment_value),2) AS TOTAL_ORDER_VALUE
	FROM Olist.ORDERS o
	LEFT JOIN Olist.ORDER_PAYMENTS op
		ON o.order_id = op.order_id
	LEFT JOIN Olist.CUSTOMERS c
		ON c.customer_id = o.customer_id
	GROUP BY 
		CUSTOMER
	ORDER BY
		TOTAL_ORDER_VALUE DESC,
		NO_OF_ORDERS DESC;
	
/* 
 * Corresponds to the "Highest-Grossing Categories" bar plot
 * Results in the "DAYS_AT_TOP.csv" data frame
 * 
 * Total no. of days on which each product category was the highest-grossing category
 * and the sales generated from each product category, 
 * in local currency (Brazilian reais, BRL)
 * 
 * Note that some sellers and customers did not provide zip codes
 */
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

/* 
 * Corresponds to the "Median Delivery Time" metric and the "Delivery Time" box plot
 * Results in the "DELIVERY_TIME.csv" data frame
 *
 * Calculated as the time taken from payment to delivery
 */
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

/* 
 * Corresponds to the "Sales Growth" and "Total Sales" metrics, and the waterfall chart
 * Results in the "SALES.csv" data frame
 *
 * Sales on each day, based on price paid
 */
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

/* 
 * Corresponds to the "Average Rating" metric
 * Results in the "SCORE_TRENDS.csv" data frame
 *
 * Average review on each day
 */
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

/* 
 * Corresponds to the "Top Shipping Routes & Destinations" map
 * Results in the "SHIPMENT_FLOW_STATE.csv" data frame
 * 
 * Total freight value transported from sellers to customers, 
 * in local currency (Brazilian reais, BRL),
 * assuming products are always physically stored at sellers' locations
 * by state
 */
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