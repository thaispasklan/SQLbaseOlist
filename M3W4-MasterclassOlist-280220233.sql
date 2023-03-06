--Quem é o cliente com maior volume de compras total por estado?
WITH tabela AS (
SELECT c.customer_id, 
	   c.customer_state, 
	   SUM(op.payment_value) as valor_compra 
FROM customers c 
INNER JOIN orders o 
	ON c.customer_id = o.customer_id 
INNER JOIN order_payments op 
	ON o.order_id = op.order_id 
GROUP by c.customer_id, c.customer_state
)

, ranking AS (
SELECT customer_id, 
	   valor_compra,
	   customer_state,
	   RANK() OVER (PARTITION BY customer_state ORDER BY valor_compra DESC) AS rank_cust
FROM tabela
)

SELECT *
FROM ranking
WHERE rank_cust = 1
ORDER BY valor_compra DESC;

--Quais as 10 categorias de produto mais vendidas?
--Por volume de vendas.
SELECT p.product_category_name, SUM(oi.price) as sum_price
FROM products p 
INNER JOIN order_items oi 
	ON p.product_id = oi.product_id 
GROUP BY product_category_name
ORDER BY sum_price DESC
LIMIT 10;

--Por quantidade de itens vendidos.
SELECT p.product_category_name, COUNT(DISTINCT oi.order_id) as quantity
FROM products p 
INNER JOIN order_items oi 
	ON p.product_id = oi.product_id 
GROUP BY product_category_name
ORDER BY quantity DESC
LIMIT 10;

--Quais são as 10 categorias de produtos mais vendidas (em volume de vendas) para 2016, 2017 e 2018? 
WITH category_price_year AS (
	SELECT product_category_name, SUM(price) AS price, SUBSTRING(order_purchase_timestamp, 1, 4) AS year_purchase
	FROM products p 
	LEFT JOIN order_items oi 
		ON p.product_id = oi.product_id 
	LEFT JOIN orders o 
		ON oi.order_id = o.order_id 
	GROUP BY product_category_name, year_purchase
	ORDER BY price DESC 
)

,ranking_year AS (
	SELECT product_category_name, price, year_purchase, RANK() OVER (PARTITION BY year_purchase ORDER BY price DESC) AS ranking
	FROM category_price_year
)

SELECT product_category_name, price, year_purchase, ranking
FROM ranking_year
WHERE ranking <= 10
ORDER BY year_purchase, price DESC;

--Em que dia da semana a quantidade de vendas é maior?
SELECT 
CASE CAST (STRFTIME('%w', order_purchase_timestamp) AS INTEGER)
	WHEN 0 THEN 'sunday'
	WHEN 1 THEN 'monday'
	WHEN 2 THEN 'tuesday'
	WHEN 3 THEN 'wednesday'
	WHEN 4 THEN 'thursday'
	WHEN 5 THEN 'friday'
	ELSE 'saturday' END AS day_week,
COUNT(order_id) AS sales 
FROM orders
GROUP BY day_week
ORDER BY sales;

--Há quanto tempo cada seller entrou na nossa base?
WITH seller_order AS (
SELECT seller_id, order_purchase_timestamp, 
	   FIRST_VALUE (order_purchase_timestamp) OVER (PARTITION BY seller_id) AS first_sale
FROM sellers  
INNER JOIN order_items oi USING (seller_id)
INNER JOIN orders o USING (order_id)
)

SELECT seller_id, 
       first_sale, 
       ROUND(JULIANDAY('2018-10-17') - JULIANDAY(first_sale)) AS days_since_first_sale
FROM seller_order
GROUP BY seller_id;

--Quais são as três categorias de produto mais vendidas por estado?
WITH order_products AS (
SELECT order_id, price, product_category_name
FROM order_items oi 
INNER JOIN products p 
	ON oi.product_id = p.product_id 
)

, sales_state AS (
SELECT customer_state, product_category_name, SUM(price) AS sum_price
FROM order_products op
INNER JOIN orders o 
	ON o.order_id = op.order_id
INNER JOIN customers c 
	ON o.customer_id = c.customer_id
GROUP BY customer_state, product_category_name
)

, state_ranking AS (
SELECT customer_state, product_category_name, sum_price, ROW_NUMBER () OVER (PARTITION BY customer_state ORDER BY sum_price DESC) AS ranking
FROM sales_state
)

SELECT customer_state, product_category_name, sum_price, ranking
FROM state_ranking
WHERE ranking <=3;

--Existe alguma diferença de comportamento de RS e de BA?
WITH order_products AS (
SELECT order_id, price, product_category_name
FROM order_items oi 
INNER JOIN products p 
	ON oi.product_id = p.product_id 
)

, sales_state AS (
SELECT customer_state, product_category_name, SUM(price) AS sum_price
FROM order_products op
INNER JOIN orders o 
	ON o.order_id = op.order_id
INNER JOIN customers c 
	ON o.customer_id = c.customer_id
GROUP BY customer_state, product_category_name
)

, state_ranking AS (
SELECT customer_state, product_category_name, sum_price, ROW_NUMBER () OVER (PARTITION BY customer_state ORDER BY sum_price DESC) AS ranking
FROM sales_state
)

SELECT customer_state, product_category_name, sum_price, ranking
FROM state_ranking
WHERE ranking <=3 AND customer_state IN ("RS", "BA");

--Qual é o número de usuário ativos mensais para 2017?
--Qual é a taxa de crescimento?
WITH month_year AS (
SELECT COUNT(DISTINCT customer_id) AS users,
	   SUBSTRING(order_purchase_timestamp, 1, 7) AS month_purchase,
	   SUBSTRING(order_purchase_timestamp, 1, 4) AS year_purchase
FROM orders
GROUP BY month_purchase
HAVING year_purchase = '2017'
)

, previously_month AS (
SELECT month_purchase, users,
	   LAG(users) OVER (ORDER BY month_purchase ASC) AS last_month
FROM month_year
)

SELECT month_purchase, users, last_month,
	   ROUND (CAST (users AS FLOAT)/CAST(last_month AS FLOAT), 2) AS growth_rate
FROM previously_month;

--Supondo que o SLA de resposta de review deve ser de 24 horas, esse prazo está sendo cumprido?
SELECT AVG(JULIANDAY(review_answer_timestamp) - JULIANDAY(review_creation_date))
FROM order_reviews;