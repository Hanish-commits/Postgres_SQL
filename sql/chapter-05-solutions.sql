-- Chapter 5 practice solutions. Try the problems in chapters/05-window-functions.md first!

-- 1
SELECT name, salary,
       SUM(salary) OVER () AS company_total,
       ROUND(salary * 100.0 / SUM(salary) OVER (), 1) AS pct_of_total
FROM employees;

-- 2
SELECT name, department, salary,
       AVG(salary) OVER (PARTITION BY department) AS dept_avg,
       salary - AVG(salary) OVER (PARTITION BY department) AS diff
FROM employees;

-- 3
SELECT name, department, COUNT(*) OVER (PARTITION BY department) AS dept_size
FROM employees;

-- 4
SELECT name, salary,
       ROW_NUMBER() OVER (ORDER BY salary DESC, name) AS row_num,
       RANK()       OVER (ORDER BY salary DESC)       AS rnk,
       DENSE_RANK() OVER (ORDER BY salary DESC)       AS dense_rnk
FROM employees
ORDER BY salary DESC, name;

-- 5
SELECT name, department, salary,
       RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank_in_dept
FROM employees
ORDER BY department, rank_in_dept, name;

-- 6
SELECT name, salary, NTILE(3) OVER (ORDER BY salary DESC, name) AS bucket
FROM employees
ORDER BY salary DESC, name;

-- 7
WITH ranked AS (
    SELECT name, department, salary,
           ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC, name) AS rn
    FROM employees
)
SELECT department, name, salary FROM ranked WHERE rn <= 2 ORDER BY department, rn;     -- Engineering: Meera, Karan

WITH ranked AS (
    SELECT name, department, salary,
           RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rk
    FROM employees
)
SELECT department, name, salary FROM ranked WHERE rk <= 2 ORDER BY department, rk, name;   -- Engineering: Meera, Karan, Sneha
-- Karan and Sneha tie for rank 2. ROW_NUMBER forces exactly 2 rows; RANK keeps both tied rows.

-- 8
WITH ranked AS (
    SELECT order_id, customer_id, order_date,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
    FROM orders
)
SELECT order_id, customer_id, order_date FROM ranked WHERE rn = 1 ORDER BY customer_id;

-- 9
WITH ranked AS (
    SELECT name, salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS dr
    FROM employees
)
SELECT name, salary FROM ranked WHERE dr = 3;                                          -- Karan, Sneha

-- 10
WITH order_totals AS (
    SELECT o.order_id, o.order_date, SUM(oi.quantity * p.price) AS total
    FROM orders o
    JOIN order_items oi ON oi.order_id  = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    GROUP BY o.order_id, o.order_date
)
SELECT order_id, order_date, total,
       SUM(total) OVER (ORDER BY order_date, order_id) AS running_total
FROM order_totals
ORDER BY order_date, order_id;

-- 11
SELECT customer_id, order_id, order_date,
       order_date - LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS days_since_prev
FROM orders
ORDER BY customer_id, order_date;

-- 12
WITH monthly AS (
    SELECT DATE_TRUNC('month', o.order_date)::date AS month, SUM(oi.quantity * p.price) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id  = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    WHERE o.status = 'delivered'
    GROUP BY 1
)
SELECT month, revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_month,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY month)) * 100.0
             / LAG(revenue) OVER (ORDER BY month), 2) AS growth_pct
FROM monthly
ORDER BY month;

-- 13
SELECT name, hire_date, LAG(name, 1, 'nobody') OVER (ORDER BY hire_date) AS hired_just_before
FROM employees
ORDER BY hire_date;

-- 14
SELECT name, department, salary,
       FIRST_VALUE(name) OVER w AS top_earner,
       LAST_VALUE(name)  OVER (PARTITION BY department ORDER BY salary DESC, name
                               ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS lowest_earner
FROM employees
WINDOW w AS (PARTITION BY department ORDER BY salary DESC, name)
ORDER BY department, salary DESC, name;

-- 15
WITH order_totals AS (
    SELECT o.order_id, o.order_date, SUM(oi.quantity * p.price) AS total
    FROM orders o
    JOIN order_items oi ON oi.order_id  = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    GROUP BY o.order_id, o.order_date
)
SELECT order_id, order_date, total,
       ROUND(AVG(total) OVER (ORDER BY order_date, order_id
                              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3
FROM order_totals
ORDER BY order_date, order_id;

-- 16
SELECT p.category,
       SUM(oi.quantity * p.price) AS revenue,
       ROUND(100.0 * SUM(oi.quantity * p.price) / SUM(SUM(oi.quantity * p.price)) OVER (), 1) AS pct_of_total,
       RANK() OVER (ORDER BY SUM(oi.quantity * p.price) DESC) AS rk
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY revenue DESC;

-- 17
WITH raw(id, email, created_at) AS (
    VALUES (1, 'a@x.com', DATE '2024-01-01'), (2, 'a@x.com', DATE '2024-02-01'),
           (3, 'b@x.com', DATE '2024-01-15'), (4, 'a@x.com', DATE '2024-03-01'),
           (5, 'c@x.com', DATE '2024-01-20'), (6, 'b@x.com', DATE '2024-01-16')
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_at DESC) AS rn
    FROM raw
)
SELECT id, email, created_at FROM ranked WHERE rn = 1 ORDER BY id;                     -- ids 4, 5, 6

-- 18
WITH logins(d) AS (
    VALUES (DATE '2024-04-10'), (DATE '2024-04-11'), (DATE '2024-04-12'), (DATE '2024-04-13'),
           (DATE '2024-04-20'), (DATE '2024-04-21'), (DATE '2024-04-25')
),
grouped AS (
    SELECT d, d - (ROW_NUMBER() OVER (ORDER BY d))::int AS grp FROM logins
)
SELECT MIN(d) AS streak_start, MAX(d) AS streak_end, COUNT(*) AS days
FROM grouped
GROUP BY grp
ORDER BY streak_start;                                                                 -- 10-13 (4), 20-21 (2), 25 (1)

-- 19
WITH customer_spend AS (
    SELECT c.name, SUM(oi.quantity * p.price) AS spend
    FROM customers c
    JOIN orders o       ON o.customer_id = c.customer_id AND o.status = 'delivered'
    JOIN order_items oi ON oi.order_id   = o.order_id
    JOIN products p     ON p.product_id  = oi.product_id
    GROUP BY c.customer_id, c.name
)
SELECT name, spend,
       RANK() OVER (ORDER BY spend DESC) AS rk,
       ROUND(100.0 * spend / SUM(spend) OVER (), 1) AS pct,
       ROUND(100.0 * SUM(spend) OVER (ORDER BY spend DESC) / SUM(spend) OVER (), 1) AS cumulative_pct
FROM customer_spend
ORDER BY spend DESC;

-- 20
WITH x AS (
    SELECT name, department, salary, AVG(salary) OVER (PARTITION BY department) AS dept_avg
    FROM employees
)
SELECT name, department, salary FROM x WHERE salary > dept_avg ORDER BY name;          -- Imran, Meera

-- 21
SELECT name, salary,
       SUM(salary) OVER (ORDER BY salary) AS default_frame,
       SUM(salary) OVER (ORDER BY salary ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rows_frame
FROM employees
WHERE department = 'Engineering'
ORDER BY salary, name;
-- Karan and Sneha both earn 90000 (peers). The default frame (RANGE) includes both peers for each,
-- so both show 180000. The ROWS frame counts by position: Karan 90000, Sneha 180000 (or the reverse,
-- since the order between tied rows is not defined).

-- 22
-- (a) window functions can't go in WHERE. Compute in a CTE, then filter:
WITH ranked AS (
    SELECT name, department, RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rk
    FROM employees
)
SELECT name, department FROM ranked WHERE rk = 1;
-- (b) the default frame ends at the current row (plus any tied peers), so LAST_VALUE returns the current row's name
--     (or a tied peer's), not the department's last row. Widen the frame:
SELECT name, department,
       LAST_VALUE(name) OVER (PARTITION BY department ORDER BY salary DESC, name
                              ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS lowest_earner
FROM employees;
-- (c) ROW_NUMBER needs an ORDER BY to define the numbering; without it the numbers are arbitrary:
SELECT name, department,
       ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC, name) AS position
FROM employees;
