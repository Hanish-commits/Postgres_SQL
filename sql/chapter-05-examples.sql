-- Chapter 5: all lesson examples, in lesson order.
-- Run one statement at a time and study the result.
-- Lines starting with '-- ERROR DEMO' are deliberate mistakes: remove the leading '--' to see the error.


-- ============================================================
-- 2. OVER() with aggregates
-- ============================================================

SELECT name, salary,
       SUM(salary) OVER () AS company_total,
       ROUND(salary * 100.0 / SUM(salary) OVER (), 1) AS pct_of_total
FROM employees
ORDER BY employee_id;


-- ============================================================
-- 3. PARTITION BY: windows per group
-- ============================================================

SELECT name, department, salary,
       ROUND(AVG(salary) OVER (PARTITION BY department), 0) AS dept_avg,
       salary - AVG(salary) OVER (PARTITION BY department)  AS diff_from_avg
FROM employees
ORDER BY employee_id;

-- GROUP BY: 4 rows, one per department
SELECT department, COUNT(*) AS headcount FROM employees GROUP BY department ORDER BY department;

-- Window: 7 rows, every employee keeps their row and also sees the headcount
SELECT name, department, COUNT(*) OVER (PARTITION BY department) AS dept_size
FROM employees
ORDER BY employee_id;


-- ============================================================
-- 4. ORDER BY inside OVER: running totals
-- ============================================================

WITH order_totals AS (
    SELECT o.order_id, o.order_date, o.status, SUM(oi.quantity * p.price) AS total
    FROM orders o
    JOIN order_items oi ON oi.order_id  = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    GROUP BY o.order_id, o.order_date, o.status
)
SELECT order_id, order_date, total,
       SUM(total) OVER (ORDER BY order_date, order_id) AS running_total
FROM order_totals
ORDER BY order_date, order_id;

SELECT name, salary,
       SUM(salary) OVER (PARTITION BY department ORDER BY salary) AS default_frame,
       SUM(salary) OVER (PARTITION BY department ORDER BY salary
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rows_frame
FROM employees
WHERE department = 'Engineering'
ORDER BY salary, name;


-- ============================================================
-- 5. Ranking functions
-- ============================================================

SELECT name, department, salary,
       ROW_NUMBER() OVER (ORDER BY salary DESC, name) AS row_num,
       RANK()       OVER (ORDER BY salary DESC)       AS rnk,
       DENSE_RANK() OVER (ORDER BY salary DESC)       AS dense_rnk
FROM employees
ORDER BY salary DESC, name;

SELECT name, department, salary,
       RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank_in_dept
FROM employees
ORDER BY department, rank_in_dept, name;

SELECT name, salary, NTILE(3) OVER (ORDER BY salary DESC, name) AS bucket
FROM employees
ORDER BY salary DESC, name;

SELECT name, salary,
       ROUND(PERCENT_RANK() OVER (ORDER BY salary)::numeric, 2) AS pct_rank,
       ROUND(CUME_DIST()    OVER (ORDER BY salary)::numeric, 2) AS cume_dist
FROM employees
ORDER BY salary, name;


-- ============================================================
-- 6. Top N per group (and why you need a CTE)
-- ============================================================

-- ERROR DEMO: SELECT name FROM employees WHERE ROW_NUMBER() OVER (ORDER BY salary) = 1;
-- ERROR: window functions are not allowed in WHERE

WITH ranked AS (
    SELECT name, department, salary,
           ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC, name) AS rn
    FROM employees
)
SELECT department, name, salary, rn
FROM ranked
WHERE rn <= 2
ORDER BY department, rn;

WITH ranked AS (
    SELECT name, department, salary,
           RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rk
    FROM employees
)
SELECT department, name, salary, rk
FROM ranked
WHERE rk <= 2
ORDER BY department, rk, name;

WITH product_rev AS (
    SELECT p.category, p.name, SUM(oi.quantity * p.price) AS revenue
    FROM products p
    JOIN order_items oi ON oi.product_id = p.product_id
    GROUP BY p.product_id, p.category, p.name
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rk
    FROM product_rev
)
SELECT category, name, revenue
FROM ranked
WHERE rk = 1
ORDER BY category;

WITH ranked AS (
    SELECT order_id, customer_id, order_date,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
    FROM orders
)
SELECT order_id, customer_id, order_date
FROM ranked
WHERE rn = 1
ORDER BY customer_id;

WITH ranked AS (
    SELECT name, salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS dr
    FROM employees
)
SELECT name, salary FROM ranked WHERE dr = 3;                  -- Karan, Sneha (90000)


-- ============================================================
-- 7. LAG and LEAD: looking at neighbouring rows
-- ============================================================

SELECT customer_id, order_id, order_date,
       LAG(order_date)  OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_order,
       order_date - LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS days_since_prev,
       LEAD(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS next_order
FROM orders
ORDER BY customer_id, order_date;

SELECT name, hire_date, LAG(name, 1, 'nobody') OVER (ORDER BY hire_date) AS hired_just_before
FROM employees
ORDER BY hire_date;

WITH monthly AS (
    SELECT DATE_TRUNC('month', o.order_date)::date AS month,
           SUM(oi.quantity * p.price) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id  = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    WHERE o.status = 'delivered'
    GROUP BY 1
)
SELECT month, revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_month,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY month)) * 100.0
             / LAG(revenue) OVER (ORDER BY month), 2) AS growth_pct,
       SUM(revenue) OVER (ORDER BY month) AS cumulative
FROM monthly
ORDER BY month;

SELECT name, salary, salary - LAG(salary) OVER (ORDER BY salary, name) AS step_up
FROM employees
ORDER BY salary, name;


-- ============================================================
-- 8. FIRST_VALUE, LAST_VALUE, NTH_VALUE
-- ============================================================

SELECT name, department, salary,
       FIRST_VALUE(name) OVER (PARTITION BY department ORDER BY salary DESC, name) AS top_earner,
       LAST_VALUE(name)  OVER (PARTITION BY department ORDER BY salary DESC, name) AS last_default,
       LAST_VALUE(name)  OVER (PARTITION BY department ORDER BY salary DESC, name
                               ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS lowest_earner
FROM employees
WHERE department IN ('Engineering', 'Sales')
ORDER BY department, salary DESC, name;

SELECT name, salary,
       NTH_VALUE(name, 2) OVER (ORDER BY salary DESC, name
                                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS second_name
FROM employees
ORDER BY salary DESC, name
LIMIT 2;


-- ============================================================
-- 9. Frames: choosing exactly which rows to look at
-- ============================================================

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


-- ============================================================
-- 10. Windows over grouped data, and named windows
-- ============================================================

SELECT p.category,
       SUM(oi.quantity * p.price) AS revenue,
       ROUND(100.0 * SUM(oi.quantity * p.price) / SUM(SUM(oi.quantity * p.price)) OVER (), 1) AS pct_of_total,
       RANK() OVER (ORDER BY SUM(oi.quantity * p.price) DESC) AS rk
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY revenue DESC;

SELECT name, department, salary,
       RANK()       OVER w AS rank_in_dept,
       SUM(salary)  OVER w AS running_total
FROM employees
WINDOW w AS (PARTITION BY department ORDER BY salary DESC)
ORDER BY department, rank_in_dept, name;


-- ============================================================
-- 11. Classic patterns
-- ============================================================

WITH raw(id, email, created_at) AS (
    VALUES (1, 'a@x.com', DATE '2024-01-01'),
           (2, 'a@x.com', DATE '2024-02-01'),
           (3, 'b@x.com', DATE '2024-01-15'),
           (4, 'a@x.com', DATE '2024-03-01'),
           (5, 'c@x.com', DATE '2024-01-20'),
           (6, 'b@x.com', DATE '2024-01-16')
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_at DESC) AS rn
    FROM raw
)
SELECT id, email, created_at
FROM ranked
WHERE rn = 1
ORDER BY id;

WITH logins(d) AS (
    VALUES (DATE '2024-03-01'), (DATE '2024-03-02'), (DATE '2024-03-03'),
           (DATE '2024-03-05'), (DATE '2024-03-06'),
           (DATE '2024-03-09')
),
grouped AS (
    SELECT d, d - (ROW_NUMBER() OVER (ORDER BY d))::int AS grp
    FROM logins
)
SELECT MIN(d) AS streak_start, MAX(d) AS streak_end, COUNT(*) AS days
FROM grouped
GROUP BY grp
ORDER BY streak_start;

-- employees earning above their department's average (no correlated subquery needed)
WITH x AS (
    SELECT name, department, salary,
           AVG(salary) OVER (PARTITION BY department) AS dept_avg
    FROM employees
)
SELECT name, department, salary
FROM x
WHERE salary > dept_avg
ORDER BY name;                                                   -- Imran, Meera

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
