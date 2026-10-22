-- Chapter 1: all lesson examples, in lesson order.
-- Run one statement at a time and study the result.
-- Lines starting with '-- ERROR DEMO' are deliberate mistakes: remove the leading '--' to see the error.


-- ============================================================
-- 2. Data types
-- ============================================================

SELECT 0.1::float8 + 0.2::float8 AS float_sum,
       0.1::numeric + 0.2::numeric AS numeric_sum;


-- ============================================================
-- 3. SELECT and FROM
-- ============================================================

SELECT name, city FROM customers;     -- two columns
SELECT * FROM customers;              -- every column (* = "all")

SELECT name AS product_name, price AS price_inr FROM products;

SELECT name, price, price * 0.18 AS gst FROM products;

SELECT 2 + 3 AS result, NOW() AS right_now;

-- ERROR DEMO: SELECT nam FROM customers;  -- ERROR: column "nam" does not exist
-- ERROR DEMO: SELECT name FROM customer;  -- ERROR: relation "customer" does not exist


-- ============================================================
-- 4. WHERE: filtering rows
-- ============================================================

SELECT * FROM customers WHERE city = 'Mumbai';

SELECT name, price FROM products WHERE price > 1000;
SELECT * FROM orders WHERE status <> 'delivered';
SELECT * FROM customers WHERE signup_date >= '2024-03-01';


-- ============================================================
-- 5. AND, OR, NOT
-- ============================================================

SELECT * FROM products WHERE category = 'Electronics' AND price < 5000;
SELECT * FROM customers WHERE city = 'Mumbai' OR city = 'Delhi';
SELECT * FROM orders WHERE NOT status = 'delivered';

SELECT name, category, price FROM products
WHERE category = 'Stationery' OR category = 'Home' AND price > 1000;

SELECT name, category, price FROM products
WHERE (category = 'Stationery' OR category = 'Home') AND price > 1000;


-- ============================================================
-- 6. IN and BETWEEN
-- ============================================================

-- Long way
SELECT * FROM customers WHERE city = 'Mumbai' OR city = 'Delhi' OR city = 'Bengaluru';

-- Short way (same result)
SELECT * FROM customers WHERE city IN ('Mumbai', 'Delhi', 'Bengaluru');

-- Opposite
SELECT * FROM customers WHERE city NOT IN ('Mumbai', 'Delhi');

SELECT name, price FROM products WHERE price BETWEEN 50 AND 2500;


-- ============================================================
-- 7. LIKE and ILIKE
-- ============================================================

SELECT name FROM customers WHERE name LIKE 'A%';
SELECT name FROM customers WHERE name LIKE '%a';
SELECT name FROM customers WHERE name LIKE '%ha%';
SELECT name FROM customers WHERE name LIKE '_en';

SELECT name FROM customers WHERE name LIKE  'a%';   -- 0 rows: no name starts with lowercase a
SELECT name FROM customers WHERE name ILIKE 'a%';   -- Asha


-- ============================================================
-- 8. ORDER BY, LIMIT, OFFSET
-- ============================================================

SELECT name, price FROM products ORDER BY price;        -- low to high (ASC is the default)
SELECT name, price FROM products ORDER BY price DESC;   -- high to low
SELECT name, category, price FROM products ORDER BY category, price DESC;

SELECT name, price FROM products ORDER BY price DESC LIMIT 3;
SELECT name, price FROM products ORDER BY price DESC LIMIT 3 OFFSET 3;

SELECT name, city FROM customers ORDER BY city NULLS FIRST;


-- ============================================================
-- 9. DISTINCT
-- ============================================================

SELECT DISTINCT city FROM customers;
SELECT DISTINCT department FROM employees;
SELECT DISTINCT category, price > 1000 AS is_premium FROM products;


-- ============================================================
-- 10. NULL
-- ============================================================

SELECT * FROM customers WHERE city = NULL;       -- 0 rows. Always. A classic bug.
SELECT * FROM customers WHERE city IS NULL;      -- Dev
SELECT * FROM customers WHERE city IS NOT NULL;  -- the other 5

SELECT name FROM customers WHERE city <> 'Mumbai';

SELECT name FROM customers WHERE city <> 'Mumbai' OR city IS NULL;
SELECT name FROM customers WHERE city IS DISTINCT FROM 'Mumbai';   -- Postgres: NULL-safe "not equal"

SELECT 5 + NULL;            -- NULL
SELECT 'Hello ' || NULL;    -- NULL  (|| joins text)

SELECT name, COALESCE(city, 'Unknown') AS city FROM customers;   -- first non-NULL value
SELECT NULLIF(0, 0);                                             -- NULL if both are equal, else the first

SELECT COUNT(*) AS all_rows, COUNT(city) AS rows_with_city FROM customers;

SELECT 1 WHERE 1 NOT IN (2, 3);         -- returns a row
SELECT 1 WHERE 1 NOT IN (2, 3, NULL);   -- returns nothing!


-- ============================================================
-- 11. The order Postgres runs your query
-- ============================================================

-- ERROR DEMO: SELECT price * 0.18 AS gst FROM products WHERE gst > 100;  -- ERROR: gst doesn't exist yet at WHERE
SELECT price * 0.18 AS gst FROM products WHERE price * 0.18 > 100;  -- OK
SELECT price * 0.18 AS gst FROM products ORDER BY gst;              -- OK: ORDER BY runs after SELECT
