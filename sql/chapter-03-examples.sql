-- Chapter 3: all lesson examples, in lesson order.
-- Run one statement at a time and study the result.
-- Lines starting with '-- ERROR DEMO' are deliberate mistakes: remove the leading '--' to see the error.


-- ============================================================
-- 1. Why tables are split, and keys
-- ============================================================

-- ERROR DEMO: INSERT INTO orders (customer_id, order_date, status) VALUES (999, '2024-08-01', 'pending');
-- ERROR: insert or update on table "orders" violates foreign key constraint "orders_customer_id_fkey"


-- ============================================================
-- 2. Two tiny tables to see every join
-- ============================================================

-- INNER: only matches
SELECT l.x, r.y
FROM (VALUES (1), (2), (3)) AS l(x)
JOIN (VALUES (2), (3), (4)) AS r(y) ON l.x = r.y;

-- LEFT: all of L, with NULL where R has no match
SELECT l.x, r.y
FROM (VALUES (1), (2), (3)) AS l(x)
LEFT JOIN (VALUES (2), (3), (4)) AS r(y) ON l.x = r.y
ORDER BY l.x;

-- RIGHT: all of R, with NULL where L has no match
SELECT l.x, r.y
FROM (VALUES (1), (2), (3)) AS l(x)
RIGHT JOIN (VALUES (2), (3), (4)) AS r(y) ON l.x = r.y
ORDER BY r.y;

-- FULL: everything from both sides
SELECT l.x, r.y
FROM (VALUES (1), (2), (3)) AS l(x)
FULL JOIN (VALUES (2), (3), (4)) AS r(y) ON l.x = r.y
ORDER BY COALESCE(l.x, r.y);


-- ============================================================
-- 3. INNER JOIN
-- ============================================================

SELECT o.order_id, c.name, o.order_date, o.status
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
ORDER BY o.order_id;

-- ERROR DEMO: SELECT customer_id, name FROM customers c JOIN orders o ON c.customer_id = o.customer_id;
-- ERROR: column reference "customer_id" is ambiguous

SELECT customer_id, c.name, o.order_id
FROM customers c
JOIN orders o USING (customer_id)
ORDER BY o.order_id
LIMIT 2;

SELECT o.order_id, c.name AS customer, p.name AS product,
       oi.quantity, oi.quantity * p.price AS line_total
FROM order_items oi
JOIN orders o    ON o.order_id    = oi.order_id
JOIN customers c ON c.customer_id = o.customer_id
JOIN products p  ON p.product_id  = oi.product_id
WHERE o.order_id IN (1, 2)
ORDER BY oi.order_item_id;

SELECT p.name, SUM(oi.quantity) AS units, SUM(oi.quantity * p.price) AS revenue
FROM products p
JOIN order_items oi ON oi.product_id = p.product_id
GROUP BY p.product_id, p.name
ORDER BY revenue DESC;

SELECT c.name, o.order_id
FROM customers c, orders o
WHERE c.customer_id = o.customer_id;


-- ============================================================
-- 4. LEFT JOIN (and finding what's missing)
-- ============================================================

SELECT c.name, o.order_id, o.status
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
ORDER BY c.customer_id, o.order_id;

SELECT c.name, COUNT(o.order_id) AS orders, COUNT(*) AS wrong_count
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.name
ORDER BY c.customer_id;

SELECT c.name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

-- Version A: condition in ON
SELECT c.name, o.order_id, o.status
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.status = 'delivered'
ORDER BY c.customer_id, o.order_id;

-- Version B: condition in WHERE
SELECT c.name, o.order_id, o.status
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.status = 'delivered'
ORDER BY c.customer_id, o.order_id;

SELECT c.name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.status = 'delivered'
WHERE o.order_id IS NULL
ORDER BY c.customer_id;

SELECT c.name, COALESCE(SUM(oi.quantity * p.price), 0) AS delivered_revenue
FROM customers c
LEFT JOIN orders o       ON o.customer_id = c.customer_id AND o.status = 'delivered'
LEFT JOIN order_items oi ON oi.order_id   = o.order_id
LEFT JOIN products p     ON p.product_id  = oi.product_id
GROUP BY c.customer_id, c.name
ORDER BY c.customer_id;


-- ============================================================
-- 5. RIGHT and FULL JOIN
-- ============================================================

SELECT c.name, o.order_id
FROM orders o
RIGHT JOIN customers c ON c.customer_id = o.customer_id
ORDER BY c.customer_id;


-- ============================================================
-- 6. CROSS JOIN
-- ============================================================

SELECT s.size, c.colour
FROM (VALUES ('S'), ('M'), ('L')) AS s(size)
CROSS JOIN (VALUES ('Red'), ('Blue')) AS c(colour);


-- ============================================================
-- 7. Self joins
-- ============================================================

SELECT e.name AS employee, m.name AS manager
FROM employees e
LEFT JOIN employees m ON m.employee_id = e.manager_id
ORDER BY e.employee_id;

-- how much less does each person earn than their manager?
SELECT e.name, COALESCE(m.name, 'None') AS manager, m.salary - e.salary AS gap
FROM employees e
LEFT JOIN employees m ON m.employee_id = e.manager_id
ORDER BY e.employee_id;

-- how many direct reports does each manager have?
SELECT m.name AS manager, COUNT(*) AS reports
FROM employees e
JOIN employees m ON m.employee_id = e.manager_id
GROUP BY m.employee_id, m.name
ORDER BY reports DESC, m.name;

SELECT a.name AS person_1, b.name AS person_2, a.department
FROM employees a
JOIN employees b ON a.department = b.department
                AND a.employee_id < b.employee_id
ORDER BY a.employee_id, b.employee_id;


-- ============================================================
-- 8. Join traps to avoid
-- ============================================================

SELECT COUNT(*) FROM customers c, orders o;     -- 42 rows!  (6 customers × 7 orders)

SELECT c.name,
       COUNT(*)                   AS wrong_orders,
       COUNT(DISTINCT o.order_id) AS real_orders,
       SUM(oi.quantity)           AS items
FROM customers c
JOIN orders o       ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
GROUP BY c.customer_id, c.name
ORDER BY c.customer_id;


-- ============================================================
-- 9. Set operations: UNION, INTERSECT, EXCEPT
-- ============================================================

SELECT customer_id FROM orders WHERE order_date >= '2024-06-01' AND order_date < '2024-07-01'
UNION
SELECT customer_id FROM orders WHERE order_date >= '2024-07-01' AND order_date < '2024-08-01'
ORDER BY customer_id;

SELECT customer_id FROM orders WHERE order_date >= '2024-06-01' AND order_date < '2024-07-01'
UNION ALL
SELECT customer_id FROM orders WHERE order_date >= '2024-07-01' AND order_date < '2024-08-01'
ORDER BY customer_id;

SELECT customer_id FROM orders WHERE order_date >= '2024-06-01' AND order_date < '2024-07-01'
INTERSECT
SELECT customer_id FROM orders WHERE order_date >= '2024-07-01' AND order_date < '2024-08-01';

SELECT customer_id FROM orders WHERE order_date >= '2024-06-01' AND order_date < '2024-07-01'
EXCEPT
SELECT customer_id FROM orders WHERE order_date >= '2024-07-01' AND order_date < '2024-08-01'
ORDER BY customer_id;

SELECT customer_id FROM customers
EXCEPT
SELECT customer_id FROM orders;       -- 6 (Farhan)
