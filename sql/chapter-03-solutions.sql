-- Chapter 3 practice solutions. Try the problems in chapters/03-joins.md first!

-- 1
SELECT o.order_id, c.name, o.order_date, o.status
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id;

-- 2
SELECT oi.order_id, p.name AS product, oi.quantity
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id;

-- 3
SELECT c.name, COUNT(o.order_id) AS orders
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.name;

-- 4
SELECT c.name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;                                         -- Farhan

-- 5
SELECT e.name AS employee, COALESCE(m.name, 'None') AS manager
FROM employees e
LEFT JOIN employees m ON m.employee_id = e.manager_id;

-- 6
SELECT s.size, c.colour
FROM (VALUES ('S'), ('M'), ('L')) AS s(size)
CROSS JOIN (VALUES ('Red'), ('Blue'), ('Green')) AS c(colour);    -- 3 x 3 = 9 rows

-- 7
SELECT c.name AS customer, p.name AS product, oi.quantity, oi.quantity * p.price AS line_total
FROM orders o
JOIN customers c   ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id  = o.order_id
JOIN products p    ON p.product_id  = oi.product_id
WHERE o.status = 'delivered';

-- 8
SELECT p.name, SUM(oi.quantity * p.price) AS revenue
FROM products p
JOIN order_items oi ON oi.product_id = p.product_id
GROUP BY p.product_id, p.name
ORDER BY revenue DESC;

-- 9
SELECT c.name, COALESCE(SUM(oi.quantity * p.price), 0) AS delivered_revenue
FROM customers c
LEFT JOIN orders o       ON o.customer_id = c.customer_id AND o.status = 'delivered'
LEFT JOIN order_items oi ON oi.order_id   = o.order_id
LEFT JOIN products p     ON p.product_id  = oi.product_id
GROUP BY c.customer_id, c.name;                                   -- Asha 60800, Chitra 57700, Esha 32500, others 0

-- 10
SELECT c.name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.status = 'delivered'
WHERE o.order_id IS NULL;                                         -- Ben, Dev, Farhan

-- 11
SELECT m.name AS manager, COUNT(*) AS reports
FROM employees e
JOIN employees m ON m.employee_id = e.manager_id
GROUP BY m.employee_id, m.name;                                   -- Rohan 3, Meera 2, Imran 1

-- 12
SELECT a.name AS person_1, b.name AS person_2, a.department
FROM employees a
JOIN employees b ON a.department = b.department AND a.employee_id < b.employee_id;   -- 4 pairs

-- 13
SELECT p.name, SUM(oi.quantity) AS units
FROM products p
JOIN order_items oi ON oi.product_id = p.product_id
GROUP BY p.product_id, p.name
ORDER BY units DESC, p.name
LIMIT 1;                                                          -- Pen (20)

-- 14
SELECT COALESCE(c.city, 'Unknown') AS city, COUNT(*) AS orders
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY COALESCE(c.city, 'Unknown')
ORDER BY orders DESC, city;                                       -- Mumbai 4, Bengaluru 1, Delhi 1, Unknown 1

-- 15
SELECT customer_id FROM orders WHERE order_date >= '2024-06-01' AND order_date < '2024-07-01'
UNION
SELECT customer_id FROM orders WHERE order_date >= '2024-07-01' AND order_date < '2024-08-01';      -- 5 rows

SELECT customer_id FROM orders WHERE order_date >= '2024-06-01' AND order_date < '2024-07-01'
UNION ALL
SELECT customer_id FROM orders WHERE order_date >= '2024-07-01' AND order_date < '2024-08-01';      -- 6 rows
-- Customer 3 ordered in both months. UNION keeps one copy; UNION ALL keeps both.

-- 16
SELECT customer_id FROM orders WHERE order_date >= '2024-06-01' AND order_date < '2024-07-01'
EXCEPT
SELECT customer_id FROM orders WHERE order_date >= '2024-07-01' AND order_date < '2024-08-01';      -- 1, 2

-- 17
SELECT c.name,
       COUNT(DISTINCT o.order_id) AS orders,
       SUM(oi.quantity)           AS items
FROM customers c
JOIN orders o       ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
GROUP BY c.customer_id, c.name;                                   -- Asha 2/33, Ben 1/1, Chitra 2/8, Dev 1/1, Esha 1/2

-- 18
SELECT e.name, m.salary - e.salary AS gap
FROM employees e
LEFT JOIN employees m ON m.employee_id = e.manager_id
ORDER BY e.employee_id;

-- 19
SELECT DISTINCT c.name
FROM customers c
JOIN orders o       ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
JOIN products p     ON p.product_id  = oi.product_id
WHERE p.category = 'Electronics'
ORDER BY c.name;                                                  -- Asha, Ben, Chitra, Dev, Esha

-- 20 (predicted results)
SELECT COUNT(*) FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id;        -- 8 (7 orders + Farhan's NULL row)
SELECT COUNT(o.order_id) FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id; -- 7 (NULL not counted)
SELECT COUNT(*) FROM customers c JOIN orders o ON o.customer_id = c.customer_id;             -- 7
SELECT COUNT(*) FROM customers c CROSS JOIN orders o;                                        -- 42 (6 x 7)

-- 21
-- (a) "customer_id" exists in both tables, so it's ambiguous. Prefix it:
SELECT c.customer_id, c.name FROM customers c JOIN orders o ON c.customer_id = o.customer_id;
-- (b) WHERE on the right table removes customers with no pending order. Move it into ON:
SELECT c.name, o.order_id FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.status = 'pending';
-- (c) COUNT(*) counts Farhan's NULL row as 1. Count a right-table column:
SELECT c.name, COUNT(o.order_id) AS orders FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.name;
