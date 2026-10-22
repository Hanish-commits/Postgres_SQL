-- Chapter 4 practice solutions. Try the problems in chapters/04-subqueries-and-ctes.md first!

-- 1
SELECT name, price FROM products WHERE price > (SELECT AVG(price) FROM products);              -- Laptop, Phone

-- 2
SELECT name, salary FROM employees WHERE salary > (SELECT AVG(salary) FROM employees);         -- Rohan, Meera

-- 3
SELECT name, price FROM products WHERE price = (SELECT MAX(price) FROM products);              -- Laptop

-- 4
SELECT name FROM customers WHERE customer_id IN (SELECT customer_id FROM orders);

-- 5
SELECT name FROM customers WHERE customer_id NOT IN (SELECT customer_id FROM orders);         -- Farhan

-- 6
SELECT c.name FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);

SELECT c.name FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);                 -- Farhan

-- 7
SELECT AVG(n) AS avg_orders_per_customer
FROM (SELECT customer_id, COUNT(*) AS n FROM orders GROUP BY customer_id) AS t;                -- 1.4

-- 8
SELECT name, price, ROUND(price - (SELECT AVG(price) FROM products), 2) AS diff_from_avg
FROM products;

-- 9
SELECT e.name, e.department, e.salary
FROM employees e
WHERE e.salary > (SELECT AVG(x.salary) FROM employees x WHERE x.department = e.department);   -- Meera, Imran

-- 10
SELECT p.name, p.category, p.price
FROM products p
WHERE p.price > (SELECT AVG(x.price) FROM products x WHERE x.category = p.category);           -- Laptop, Phone, Notebook

-- 11
SELECT o.order_id, o.customer_id, o.order_date
FROM orders o
WHERE o.order_date = (SELECT MAX(x.order_date) FROM orders x WHERE x.customer_id = o.customer_id);

-- 12
SELECT c.name
FROM customers c
WHERE EXISTS (
    SELECT 1
    FROM orders o
    JOIN order_items oi ON oi.order_id  = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    WHERE o.customer_id = c.customer_id AND p.category = 'Electronics'
);                                                                                             -- Asha, Ben, Chitra, Dev, Esha

-- 13
SELECT c.name
FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    JOIN order_items oi ON oi.order_id  = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    WHERE o.customer_id = c.customer_id AND p.category = 'Stationery'
);                                                                                             -- Ben, Dev, Esha, Farhan

-- 14
SELECT MAX(salary) AS second_highest
FROM employees
WHERE salary < (SELECT MAX(salary) FROM employees);                                            -- 120000

SELECT name, salary
FROM employees
WHERE salary = (SELECT DISTINCT salary FROM employees ORDER BY salary DESC LIMIT 1 OFFSET 2);  -- Karan, Sneha (90000)

-- 15
SELECT name, price
FROM products
WHERE price > ALL (SELECT price FROM products WHERE category = 'Stationery');                  -- Desk Lamp, Headphones, Phone, Laptop

-- 16
WITH customer_spend AS (
    SELECT c.customer_id, c.name, SUM(oi.quantity * p.price) AS spend
    FROM customers c
    JOIN orders o       ON o.customer_id = c.customer_id AND o.status = 'delivered'
    JOIN order_items oi ON oi.order_id   = o.order_id
    JOIN products p     ON p.product_id  = oi.product_id
    GROUP BY c.customer_id, c.name
)
SELECT name, spend
FROM customer_spend
WHERE spend > (SELECT AVG(spend) FROM customer_spend);                                         -- Asha, Chitra

-- 17
WITH product_rev AS (
    SELECT p.name, SUM(oi.quantity * p.price) AS revenue
    FROM products p
    JOIN order_items oi ON oi.product_id = p.product_id
    GROUP BY p.product_id, p.name
),
total AS (
    SELECT SUM(revenue) AS total_rev FROM product_rev
)
SELECT pr.name, pr.revenue, ROUND(pr.revenue * 100.0 / t.total_rev, 2) AS pct_of_total
FROM product_rev pr
CROSS JOIN total t
ORDER BY pr.revenue DESC;

-- 18
WITH RECURSIVE nums AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 10
)
SELECT n, n * n AS square FROM nums;

-- 19
WITH RECURSIVE org AS (
    SELECT employee_id, name, 1 AS level, name::text AS path
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.employee_id, e.name, o.level + 1, o.path || ' > ' || e.name
    FROM employees e
    JOIN org o ON e.manager_id = o.employee_id
)
SELECT REPEAT('    ', level - 1) || name AS org_chart, level
FROM org
ORDER BY path;

-- 20
WITH RECURSIVE chain AS (
    SELECT employee_id, name, manager_id, 0 AS steps_up
    FROM employees
    WHERE name = 'Priya'
    UNION ALL
    SELECT m.employee_id, m.name, m.manager_id, c.steps_up + 1
    FROM employees m
    JOIN chain c ON m.employee_id = c.manager_id
)
SELECT name, steps_up FROM chain ORDER BY steps_up;                                            -- Priya, Imran, Rohan

-- 21 (predicted results)
SELECT name FROM customers WHERE name NOT IN (SELECT city FROM customers);                     -- 0 rows (the NULL city poisons NOT IN)
SELECT name FROM customers WHERE name NOT IN (SELECT city FROM customers WHERE city IS NOT NULL);  -- all 6 names
SELECT name FROM customers c WHERE NOT EXISTS (SELECT 1 FROM customers x WHERE x.city = c.name);   -- all 6 names (NOT EXISTS ignores NULLs)

-- 22
-- (a) the subquery returns several rows. Say "above ALL of them" (or use MAX):
SELECT name FROM products WHERE price > ALL (SELECT price FROM products WHERE category = 'Electronics');
-- (b) aggregates can't go in WHERE. Use a subquery:
SELECT name FROM employees WHERE salary = (SELECT MAX(salary) FROM employees);
-- (c) the NULL city poisons NOT IN. Filter NULLs out, or use NOT EXISTS:
SELECT name FROM customers WHERE name NOT IN (SELECT city FROM customers WHERE city IS NOT NULL);
