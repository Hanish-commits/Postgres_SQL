-- Chapter 2: all lesson examples, in lesson order.
-- Run one statement at a time and study the result.
-- Lines starting with '-- ERROR DEMO' are deliberate mistakes: remove the leading '--' to see the error.


-- ============================================================
-- 1. Aggregate functions
-- ============================================================

SELECT COUNT(*)   AS how_many,
       SUM(price) AS total,
       AVG(price) AS average,
       MIN(price) AS cheapest,
       MAX(price) AS priciest
FROM products;

SELECT COUNT(*), AVG(price) FROM products WHERE category = 'Electronics';

SELECT COUNT(*)            AS all_rows,
       COUNT(city)         AS rows_with_city,
       COUNT(DISTINCT city) AS different_cities
FROM customers;

SELECT AVG(x) FROM (VALUES (10), (20), (NULL)) AS t(x);

SELECT SUM(price) AS total, COUNT(*) AS n FROM products WHERE price > 999999;

-- ERROR DEMO: SELECT name, COUNT(*) FROM customers;
-- ERROR: column "customers.name" must appear in the GROUP BY clause or be used in an aggregate function


-- ============================================================
-- 2. GROUP BY
-- ============================================================

SELECT category, COUNT(*) AS products, AVG(price) AS avg_price
FROM products
GROUP BY category;

SELECT department, COUNT(*) AS headcount, AVG(salary) AS avg_salary
FROM employees
GROUP BY department;

SELECT status, COUNT(*) AS orders
FROM orders
GROUP BY status
ORDER BY orders DESC;

-- ERROR DEMO: SELECT department, name, AVG(salary) FROM employees GROUP BY department;
-- ERROR: column "employees.name" must appear in the GROUP BY clause or be used in an aggregate function

SELECT category, price > 1000 AS is_premium, COUNT(*) AS products
FROM products
GROUP BY category, price > 1000;

SELECT city, COUNT(*) FROM customers GROUP BY city;

SELECT COALESCE(city, 'Unknown') AS city, COUNT(*) AS customers
FROM customers
GROUP BY COALESCE(city, 'Unknown');

SELECT department, COUNT(*) AS headcount
FROM employees
GROUP BY 1          -- 1 = the first column in SELECT
ORDER BY headcount DESC;

SELECT department, COUNT(*) AS headcount
FROM employees
WHERE salary > 60000
GROUP BY department;


-- ============================================================
-- 3. HAVING: filtering groups
-- ============================================================

-- ERROR DEMO: SELECT department FROM employees WHERE AVG(salary) > 80000 GROUP BY department;
-- ERROR: aggregate functions are not allowed in WHERE

SELECT department, AVG(salary) AS avg_salary
FROM employees
GROUP BY department
HAVING AVG(salary) > 80000;

-- departments with more than one employee
SELECT department, COUNT(*) AS headcount
FROM employees
GROUP BY department
HAVING COUNT(*) > 1;

-- all three together: filter rows, group, then filter groups
SELECT category, AVG(price) AS avg_price
FROM products
WHERE price > 50
GROUP BY category
HAVING COUNT(*) >= 1
ORDER BY avg_price DESC;

-- ERROR DEMO: SELECT department, AVG(salary) AS avg_sal FROM employees GROUP BY department HAVING avg_sal > 80000;
-- ERROR: column "avg_sal" does not exist


-- ============================================================
-- 4. The full order Postgres runs your query
-- ============================================================

SELECT department, AVG(salary) AS avg_salary
FROM employees
WHERE hire_date >= '2019-01-01'
GROUP BY department
HAVING COUNT(*) > 1
ORDER BY avg_salary DESC
LIMIT 1;


-- ============================================================
-- 5. String functions
-- ============================================================

SELECT UPPER('asha'), LOWER('ASHA'), LENGTH('Mumbai'), TRIM('  hi  '),
       LEFT('Mumbai', 3), RIGHT('Mumbai', 3),
       SUBSTRING('Postgres' FROM 1 FOR 4), REPLACE('a-b-c', '-', '/'),
       POSITION('a' IN 'Asha'), INITCAP('hello world'), SPLIT_PART('x@gmail.com', '@', 2);

SELECT name, UPPER(name) AS shouting, LENGTH(name) AS letters FROM customers;
SELECT name FROM customers WHERE LOWER(name) = 'asha';     -- case-insensitive match

SELECT name || ' from ' || city          AS with_pipes,
       CONCAT(name, ' from ', city)      AS with_concat,
       CONCAT_WS(', ', name, city)       AS with_separator
FROM customers
WHERE name IN ('Asha', 'Dev');


-- ============================================================
-- 6. Numeric functions
-- ============================================================

SELECT ROUND(3.14159, 2), ROUND(2.5), CEIL(4.2), FLOOR(4.8), ABS(-5), MOD(10, 3), POWER(2, 10);

-- 10% raise, rounded to the nearest 100
SELECT name, salary, ROUND(salary * 1.1, -2) AS new_salary FROM employees;

-- GST with 2 decimals
SELECT name, ROUND(price * 0.18, 2) AS gst FROM products;

SELECT 7 / 2 AS int_divide, 7 / 2.0 AS decimal_divide, 7::numeric / 2 AS cast_divide, 7 % 2 AS remainder;

-- ERROR DEMO: SELECT ROUND(3.14159::float8, 2);
-- ERROR: function round(double precision, integer) does not exist
SELECT ROUND(3.14159::numeric, 2);     -- works: 3.14


-- ============================================================
-- 7. Date and time functions
-- ============================================================

SELECT CURRENT_DATE AS today, NOW() AS right_now;

SELECT EXTRACT(YEAR  FROM DATE '2024-07-20') AS yr,
       EXTRACT(MONTH FROM DATE '2024-07-20') AS mon,
       EXTRACT(DAY   FROM DATE '2024-07-20') AS day,
       EXTRACT(DOW   FROM DATE '2024-07-20') AS weekday;   -- 0 = Sunday ... 6 = Saturday

-- how many employees were hired each year?
SELECT EXTRACT(YEAR FROM hire_date) AS hire_year, COUNT(*) AS hired
FROM employees
GROUP BY 1
ORDER BY 1;

SELECT DATE_TRUNC('month', order_date)::date AS month, COUNT(*) AS orders
FROM orders
GROUP BY 1
ORDER BY 1;

SELECT DATE '2024-07-20' - DATE '2024-05-01'   AS days_between,    -- date minus date = number of days
       DATE '2024-01-15' + 30                  AS plus_30_days,    -- date plus integer = date
       DATE '2024-01-15' + INTERVAL '1 month'  AS plus_1_month;    -- date plus interval = timestamp

SELECT AGE(DATE '2025-01-01', DATE '2024-01-15');     -- 11 mons 17 days

-- full years of service as of 1 Jan 2025
SELECT name, EXTRACT(YEAR FROM AGE(DATE '2025-01-01', hire_date)) AS years_served
FROM employees
ORDER BY hire_date;

SELECT name, TO_CHAR(signup_date, 'DD Mon YYYY') AS joined FROM customers;   -- 15 Jan 2024


-- ============================================================
-- 8. CASE WHEN: if/else inside SQL
-- ============================================================

SELECT name, price,
       CASE
           WHEN price < 100  THEN 'Budget'
           WHEN price < 5000 THEN 'Mid'
           ELSE 'Premium'
       END AS price_band
FROM products
ORDER BY price;

SELECT CASE WHEN price < 100 THEN 'Budget'
            WHEN price < 5000 THEN 'Mid'
            ELSE 'Premium' END AS price_band,
       COUNT(*) AS products
FROM products
GROUP BY 1;

SELECT SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) AS delivered,
       SUM(CASE WHEN status <> 'delivered' THEN 1 ELSE 0 END) AS not_delivered
FROM orders;

SELECT COUNT(*) FILTER (WHERE status = 'delivered')  AS delivered,
       COUNT(*) FILTER (WHERE status <> 'delivered') AS not_delivered
FROM orders;

SELECT COALESCE(city, 'Unknown') FROM customers;     -- first non-NULL value
SELECT 10 / NULLIF(0, 0);                            -- NULLIF turns a 0 into NULL, so no "division by zero" error


-- ============================================================
-- 9. Casting: converting types
-- ============================================================

SELECT '123'::int + 1;                  -- Postgres shorthand: value::type  -> 124
SELECT CAST('2024-01-15' AS DATE);      -- standard SQL spelling

SELECT '3.7'::numeric,            -- 3.7
       10.5::int,                 -- 11  (rounds to the nearest whole number)
       2500.00::int,              -- 2500
       5::text || 'x';            -- '5x'  (number to text, so || works)

SELECT 7::numeric / 2;   -- 3.5

-- ERROR DEMO: SELECT 'abc'::int;
-- ERROR: invalid input syntax for type integer: "abc"
