-- Chapter 4: all lesson examples, in lesson order.
-- Run one statement at a time and study the result.
-- Lines starting with '-- ERROR DEMO' are deliberate mistakes: remove the leading '--' to see the error.


-- ============================================================
-- 2. Scalar subqueries: one value
-- ============================================================

-- products priced above the average
SELECT name, price
FROM products
WHERE price > (SELECT AVG(price) FROM products)
ORDER BY price DESC;

-- employees earning more than the company average (92142.86)
SELECT name, salary
FROM employees
WHERE salary > (SELECT AVG(salary) FROM employees)
ORDER BY salary DESC;

-- the most expensive product(s)
SELECT name, price
FROM products
WHERE price = (SELECT MAX(price) FROM products);

-- ERROR DEMO: SELECT name FROM products WHERE price > (SELECT price FROM products WHERE category = 'Electronics');
-- ERROR: more than one row returned by a subquery used as an expression

SELECT name FROM products WHERE price > (SELECT MAX(price) FROM products WHERE category = 'Electronics');   -- above every Electronics price: none
SELECT name FROM products WHERE price > (SELECT MIN(price) FROM products WHERE category = 'Electronics');   -- above the cheapest Electronics item


-- ============================================================
-- 3. Subqueries that return a list: IN and NOT IN
-- ============================================================

-- customers who have placed at least one order
SELECT name
FROM customers
WHERE customer_id IN (SELECT customer_id FROM orders)
ORDER BY customer_id;

-- customers who have never ordered
SELECT name FROM customers WHERE customer_id NOT IN (SELECT customer_id FROM orders);   -- Farhan

SELECT name FROM customers WHERE name NOT IN (SELECT city FROM customers);

-- Fix 1: keep NULLs out of the list
SELECT name FROM customers
WHERE name NOT IN (SELECT city FROM customers WHERE city IS NOT NULL)
ORDER BY customer_id;                                                     -- all 6 names

-- Fix 2: use NOT EXISTS (section 7), which isn't fooled by NULLs


-- ============================================================
-- 4. Subqueries in FROM (derived tables)
-- ============================================================

SELECT AVG(n) AS avg_orders_per_customer
FROM (
    SELECT customer_id, COUNT(*) AS n
    FROM orders
    GROUP BY customer_id
) AS t;


-- ============================================================
-- 5. Subqueries in SELECT
-- ============================================================

-- each product, and how far it is from the average price
SELECT name, price,
       ROUND(price - (SELECT AVG(price) FROM products), 2) AS diff_from_avg
FROM products
ORDER BY price;


-- ============================================================
-- 6. Correlated subqueries
-- ============================================================

-- how many orders has each customer placed?
SELECT c.name,
       (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) AS orders
FROM customers c
ORDER BY c.customer_id;

-- employees who earn more than the average of their OWN department
SELECT e.name, e.department, e.salary
FROM employees e
WHERE e.salary > (SELECT AVG(x.salary)
                  FROM employees x
                  WHERE x.department = e.department)
ORDER BY e.employee_id;

-- products priced above the average of their own category
SELECT p.name, p.category, p.price
FROM products p
WHERE p.price > (SELECT AVG(x.price) FROM products x WHERE x.category = p.category)
ORDER BY p.product_id;                                          -- Laptop, Phone, Notebook

-- each customer's most recent order
SELECT o.order_id, o.customer_id, o.order_date
FROM orders o
WHERE o.order_date = (SELECT MAX(x.order_date)
                      FROM orders x
                      WHERE x.customer_id = o.customer_id)
ORDER BY o.customer_id;


-- ============================================================
-- 7. EXISTS and NOT EXISTS
-- ============================================================

-- customers who have at least one order
SELECT c.name
FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id)
ORDER BY c.customer_id;                                         -- Asha, Ben, Chitra, Dev, Esha

-- customers with no orders
SELECT c.name
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);   -- Farhan

-- customers who bought at least one Electronics product
SELECT c.name
FROM customers c
WHERE EXISTS (
    SELECT 1
    FROM orders o
    JOIN order_items oi ON oi.order_id   = o.order_id
    JOIN products p     ON p.product_id  = oi.product_id
    WHERE o.customer_id = c.customer_id
      AND p.category = 'Electronics'
)
ORDER BY c.customer_id;                                         -- Asha, Ben, Chitra, Dev, Esha

-- customers who have NEVER bought Stationery
SELECT c.name
FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    JOIN order_items oi ON oi.order_id   = o.order_id
    JOIN products p     ON p.product_id  = oi.product_id
    WHERE o.customer_id = c.customer_id
      AND p.category = 'Stationery'
)
ORDER BY c.customer_id;                                         -- Ben, Dev, Esha, Farhan

-- 1. LEFT JOIN + IS NULL
SELECT c.name FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id WHERE o.order_id IS NULL;

-- 2. NOT EXISTS
SELECT c.name FROM customers c WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);

-- 3. NOT IN (only safe when the subquery can't return NULL)
SELECT c.name FROM customers c WHERE c.customer_id NOT IN (SELECT customer_id FROM orders);

-- 4. EXCEPT (returns only the key column)
SELECT customer_id FROM customers EXCEPT SELECT customer_id FROM orders;


-- ============================================================
-- 8. ANY and ALL
-- ============================================================

-- products costlier than EVERY stationery item (Pen 10, Notebook 60)
SELECT name, price
FROM products
WHERE price > ALL (SELECT price FROM products WHERE category = 'Stationery')
ORDER BY price;

-- customers in the same city as Asha
SELECT name FROM customers WHERE city = ANY (SELECT city FROM customers WHERE name = 'Asha');   -- Asha, Chitra


-- ============================================================
-- 9. The Nth highest value pattern
-- ============================================================

SELECT MAX(salary) AS second_highest
FROM employees
WHERE salary < (SELECT MAX(salary) FROM employees);              -- 120000

SELECT DISTINCT salary
FROM employees
ORDER BY salary DESC
LIMIT 1 OFFSET 2;                                                -- 3rd highest: 90000

-- and who earns it? (both tied employees come back)
SELECT name, salary
FROM employees
WHERE salary = (SELECT DISTINCT salary FROM employees ORDER BY salary DESC LIMIT 1 OFFSET 2);   -- Karan, Sneha


-- ============================================================
-- 10. CTEs: queries as recipe steps
-- ============================================================

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
WHERE spend > (SELECT AVG(spend) FROM customer_spend)
ORDER BY spend DESC;

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


-- ============================================================
-- 11. Recursive CTEs: walking hierarchies
-- ============================================================

WITH RECURSIVE nums AS (
    SELECT 1 AS n                          -- anchor: start at 1
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 5     -- recursive: add one, stop at 5
)
SELECT n FROM nums;

WITH RECURSIVE org AS (
    -- anchor: the top boss (no manager)
    SELECT employee_id, name, 1 AS level, name::text AS path
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- recursive: find the people who report to anyone already in the chart
    SELECT e.employee_id, e.name, o.level + 1, o.path || ' > ' || e.name
    FROM employees e
    JOIN org o ON e.manager_id = o.employee_id
)
SELECT REPEAT('    ', level - 1) || name AS org_chart, level, path
FROM org
ORDER BY path;

WITH RECURSIVE chain AS (
    SELECT employee_id, name, manager_id, 0 AS steps_up
    FROM employees
    WHERE name = 'Priya'

    UNION ALL

    SELECT m.employee_id, m.name, m.manager_id, c.steps_up + 1
    FROM employees m
    JOIN chain c ON m.employee_id = c.manager_id
)
SELECT name, steps_up FROM chain ORDER BY steps_up;

WITH RECURSIVE team AS (
    SELECT employee_id, name FROM employees WHERE name = 'Meera'
    UNION ALL
    SELECT e.employee_id, e.name FROM employees e JOIN team t ON e.manager_id = t.employee_id
)
SELECT COUNT(*) - 1 AS people_under_meera FROM team;            -- 2  (the -1 removes Meera herself)
