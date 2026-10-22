-- Chapter 1 practice solutions. Try the problems in postgres-mastery.md first!

-- 1
SELECT name, price FROM products;

-- 2
SELECT * FROM customers WHERE city = 'Mumbai';                      -- Asha, Chitra

-- 3
SELECT * FROM products WHERE price > 1000;                          -- Laptop, Phone, Headphones, Desk Lamp

-- 4
SELECT * FROM products WHERE category = 'Electronics' AND price < 5000;   -- Headphones

-- 5
SELECT * FROM customers WHERE city IN ('Mumbai', 'Delhi');          -- Asha, Ben, Chitra, Farhan

-- 6
SELECT name, price FROM products WHERE price BETWEEN 50 AND 2500;   -- Headphones, Notebook, Desk Lamp

-- 7
SELECT * FROM customers WHERE name LIKE 'A%';                       -- Asha

-- 8
SELECT * FROM customers WHERE name ILIKE '%a%';                     -- Asha, Chitra, Esha, Farhan

-- 9
SELECT * FROM customers WHERE city IS NULL;                         -- Dev

-- 10
SELECT name, price FROM products ORDER BY price DESC LIMIT 3;       -- Laptop, Phone, Headphones

-- 11
SELECT DISTINCT city FROM customers;
-- 4 rows: Mumbai, Delhi, Bengaluru and NULL. DISTINCT keeps one NULL rather than removing it.

-- 12
SELECT DISTINCT department FROM employees;                          -- 4 rows

-- 13
SELECT * FROM orders WHERE status <> 'delivered';                   -- order 3 (cancelled), order 5 (pending)

-- 14
SELECT * FROM employees WHERE manager_id IS NULL;                   -- Rohan

-- 15
SELECT * FROM customers
WHERE signup_date >= '2024-03-01' AND signup_date < '2024-04-01';   -- Chitra, Dev

-- 16
SELECT name, price, price * 1.18 AS price_with_gst
FROM products
ORDER BY price_with_gst DESC;

-- 17
SELECT name, COALESCE(city, 'Unknown') AS city FROM customers;

-- 18 (two ways)
SELECT name FROM customers WHERE city <> 'Mumbai' OR city IS NULL;
SELECT name FROM customers WHERE city IS DISTINCT FROM 'Mumbai';    -- Ben, Dev, Esha, Farhan

-- 19
SELECT name, salary FROM employees
ORDER BY salary DESC, name
LIMIT 3 OFFSET 1;                                                   -- Meera, Karan, Sneha

-- 20
SELECT name, category, price FROM products
WHERE category = 'Stationery' OR (category = 'Home' AND price > 1000);   -- Notebook, Pen, Desk Lamp

SELECT name, category, price FROM products
WHERE category IN ('Stationery', 'Home') AND price > 1000;               -- Desk Lamp only
-- The first lets ALL Stationery through. The second applies the price filter to both categories.

-- 21
SELECT 1 WHERE NULL = NULL;             -- 0 rows (UNKNOWN is not TRUE)
SELECT 1 WHERE NULL IS NULL;            -- 1 row
SELECT 1 WHERE 5 NOT IN (1, 2, NULL);   -- 0 rows (the NOT IN + NULL trap)
SELECT COUNT(*), COUNT(city) FROM customers;   -- 6 and 5
