CREATE TABLE Olist.CUSTOMERS
(
	customer_id VARCHAR(32),
	customer_unique_id VARCHAR(32),
	customer_zip_code_prefix INT,
	customer_city VARCHAR(32),
	customer_state VARCHAR(5)
);

CREATE TABLE Olist.GEOLOCATION
(
	geolocation_zip_code_prefix INT,
	geolocation_lat DOUBLE,
	geolocation_lng DOUBLE,
	geolocation_city VARCHAR(64),
	geolocation_state VARCHAR(64)
);

CREATE TABLE Olist.LOCATIONS
(
	zip_code_prefix INT,
	latitude DOUBLE,
	longitude DOUBLE,
	state VARCHAR(32),
	state_code VARCHAR(5),
	city VARCHAR(64)
);
CREATE TABLE Olist.ORDER_ITEMS
(
	order_id VARCHAR(32),
	order_item_id INT,
	product_id VARCHAR(32),
	seller_id VARCHAR(32),
	shipping_limit_date DATETIME,
	price DOUBLE,
	freight_value DOUBLE
);

CREATE TABLE Olist.ORDER_PAYMENTS
(
	order_id VARCHAR(32),
	payment_sequential INT,
	payment_type VARCHAR(32),
	payment_installments INT,
	payment_value DOUBLE
)

CREATE TABLE Olist.ORDER_REVIEWS
(
	review_id VARCHAR(32),
	order_id VARCHAR(32),
	review_score INT,
	review_comment_title LONGTEXT,
	review_comment_message LONGTEXT,
	review_creation_date DATETIME,
	review_answer_timestamp DATETIME
);

CREATE TABLE Olist.ORDERS
(	
	order_id VARCHAR(32),
	customer_id VARCHAR(32),
	order_status VARCHAR(32),
	order_purchase_timestamp DATETIME,
	order_approved_at VARCHAR(32),
	order_delivered_carrier_date DATETIME,
	order_delivered_customer_date DATETIME,
	order_estimated_delivery_date DATETIME
);

CREATE TABLE Olist.PRODUCTS
(
	product_id VARCHAR(32),
	product_category_name VARCHAR(64),
	product_name_lenght INT,
	product_description_lenght INT,
	product_photos_qty INT,
	product_weight_g INT,
	product_length_cm INT,
	product_height_cm INT,
	product_width_cm INT
);

CREATE TABLE Olist.SELLERS
(
	seller_id VARCHAR(32),
	seller_zip_code_prefix INT,
	seller_city VARCHAR(32),
	seller_state VARCHAR(5)
);

CREATE TABLE Olist.TRANSLATION
(
	product_category_name VARCHAR(64),
	product_category_name_english VARCHAR(64)
);

/* Some customers and sellers have zip codes that do not exist within the locations table:
 * 
-- SELECT DISTINCT c.customer_zip_code_prefix FROM Olist.CUSTOMERS c
-- WHERE c.customer_zip_code_prefix NOT IN 
-- (SELECT l.zip_code_prefix FROM Olist.locations l)
-- ORDER BY c.customer_zip_code_prefix;
-- 
-- SELECT DISTINCT s.seller_zip_code_prefix FROM Olist.SELLERS s
-- WHERE s.seller_zip_code_prefix NOT IN 
-- (SELECT l.zip_code_prefix FROM Olist.locations l)
-- ORDER BY s.seller_zip_code_prefix;
 * 
 * Therefore, a zip code area list was created based on https://pt.wikipedia.org/wiki/C%C3%B3digo_de_Endere%C3%A7amento_Postal#Zonas_Postais_e_Faixas_de_CEP.
 * Then join with original geolocation dataset to obtain average latitudes and longitudes (multiple are given for each zip code area)
 * to create new table
*/
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
