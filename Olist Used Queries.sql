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
	
/* 
 * Corresponds to the "Highest-Grossing Categories" bar plot
 * Results in the "DAYS_AT_TOP.csv" data frame
 * 
 * Total freight value transported from sellers to customers, 
 * in local currency (Brazilian reais, BRL),
 * assuming products are always physically stored at sellers' locations
 * 
 * Note that some sellers and customers did not provide zip codes
 */
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