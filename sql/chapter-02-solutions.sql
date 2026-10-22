-- Chapter 2 practice solutions. Try the problems in chapters/02-shaping-data.md first!

-- 1
SELECT COUNT(*) FROM customers;                                          -- 6

-- 2
SELECT SUM(price) AS total, AVG(price) AS average, MIN(price) AS lowest, MAX(price) AS highest
FROM products;

-- 3
SELECT category, COUNT(*) AS products FROM products GROUP BY category;

-- 4
SELECT department, AVG(salary) AS avg_salary FROM employees GROUP BY department;

-- 5
SELECT status, COUNT(*) AS orders FROM orders GROUP BY status;

-- 6
SELECT MAX(salary) AS highest, MIN(salary) AS lowest FROM employees;     -- 150000, 60000

-- 7
SELECT UPPER(name) AS name, LENGTH(name) AS letters FROM customers;

-- 8
SELECT name, TO_CHAR(signup_date, 'DD Mon YYYY') AS joined FROM customers;

-- 9
SELECT department, COUNT(*) AS headcount
FROM employees
GROUP BY department
HAVING COUNT(*) > 1;                                                     -- Engineering (3), Sales (2)

-- 10
SELECT category, AVG(price) AS avg_price
FROM products
GROUP BY category
HAVING AVG(price) > 1000;                                                -- Electronics, Home

-- 11
SELECT COALESCE(city, 'Unknown') AS city, COUNT(*) AS customers
FROM customers
GROUP BY COALESCE(city, 'Unknown');

-- 12
SELECT DATE_TRUNC('month', order_date)::date AS month, COUNT(*) AS orders
FROM orders
GROUP BY 1
ORDER BY 1;                                                              -- May 1, June 3, July 3

-- 13
SELECT name, price,
       CASE WHEN price < 100 THEN 'Budget'
            WHEN price < 5000 THEN 'Mid'
            ELSE 'Premium' END AS band
FROM products;

-- 14
SELECT CASE WHEN price < 100 THEN 'Budget'
            WHEN price < 5000 THEN 'Mid'
            ELSE 'Premium' END AS band,
       COUNT(*) AS products
FROM products
GROUP BY 1;                                                              -- 2 / 2 / 2

-- 15
SELECT product_id, SUM(quantity) AS total_qty
FROM order_items
GROUP BY product_id
HAVING SUM(quantity) > 5;                                                -- product 4 (15), product 5 (20)

-- 16
SELECT name, EXTRACT(YEAR FROM AGE(DATE '2025-01-01', hire_date)) AS years_served
FROM employees
ORDER BY hire_date;

-- 17
SELECT name, salary, ROUND(salary * 1.1, -2) AS new_salary FROM employees;

-- 18
SELECT EXTRACT(YEAR FROM hire_date) AS hire_year, COUNT(*) AS hired
FROM employees
GROUP BY 1
ORDER BY 1;

-- 19 (two ways)
SELECT SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) AS delivered,
       SUM(CASE WHEN status <> 'delivered' THEN 1 ELSE 0 END) AS not_delivered
FROM orders;

SELECT COUNT(*) FILTER (WHERE status = 'delivered')  AS delivered,
       COUNT(*) FILTER (WHERE status <> 'delivered') AS not_delivered
FROM orders;                                                             -- 5 and 2

-- 20
SELECT department, MAX(salary) - MIN(salary) AS salary_gap
FROM employees
GROUP BY department
HAVING COUNT(*) > 1;                                                     -- Engineering 30000, Sales 5000

-- 21
SELECT name || ' (' || COALESCE(city, 'no city') || ')' AS label FROM customers;

-- 22 (predicted results)
SELECT COUNT(*), COUNT(city), COUNT(DISTINCT city) FROM customers;      -- 6, 5, 3
SELECT AVG(x) FROM (VALUES (10), (20), (NULL)) AS t(x);                  -- 15 (NULL is skipped)
SELECT SUM(price) FROM products WHERE price > 999999;                    -- NULL (no rows to add up)
SELECT 7 / 2, 7 / 2.0;                                                   -- 3 and 3.5

-- 23
-- (a) "name" is neither grouped nor aggregated. Add it to GROUP BY or remove it:
SELECT department, COUNT(*) FROM employees GROUP BY department;
-- (b) aggregates can't go in WHERE. Use HAVING:
SELECT category FROM products GROUP BY category HAVING AVG(price) > 1000;
-- (c) HAVING runs before SELECT, so the alias "n" doesn't exist yet. Repeat the expression:
SELECT category, COUNT(*) AS n FROM products GROUP BY category HAVING COUNT(*) > 1;
