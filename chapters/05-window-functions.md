# Chapter 5: Window Functions

**You will learn:** how to calculate across related rows **without collapsing them**, rank rows, build running totals and moving averages, compare each row to the previous or next one, and solve classic problems like top-N per group, de-duplication and streaks.

**Before you start:** be comfortable with `GROUP BY` (Chapter 2), joins (Chapter 3) and CTEs (Chapter 4). Make sure `sql/schema.sql` is loaded.

## Contents
1. [What is a window function?](#1-what-is-a-window-function)
2. [OVER() with aggregates](#2-over-with-aggregates)
3. [PARTITION BY: windows per group](#3-partition-by-windows-per-group)
4. [ORDER BY inside OVER: running totals](#4-order-by-inside-over-running-totals)
5. [Ranking functions](#5-ranking-functions)
6. [Top N per group (and why you need a CTE)](#6-top-n-per-group-and-why-you-need-a-cte)
7. [LAG and LEAD: looking at neighbouring rows](#7-lag-and-lead-looking-at-neighbouring-rows)
8. [FIRST_VALUE, LAST_VALUE, NTH_VALUE](#8-first_value-last_value-nth_value)
9. [Frames: choosing exactly which rows to look at](#9-frames-choosing-exactly-which-rows-to-look-at)
10. [Windows over grouped data, and named windows](#10-windows-over-grouped-data-and-named-windows)
11. [Classic patterns](#11-classic-patterns)
12. [Chapter 5 cheat sheet](#12-chapter-5-cheat-sheet)
13. [Practice problems](#13-practice-problems)
14. [Solutions](#14-solutions)

[← Back to table of contents](../README.md) · SQL files: [`chapter-05-examples.sql`](../sql/chapter-05-examples.sql), [`chapter-05-solutions.sql`](../sql/chapter-05-solutions.sql)

---

## 1. What is a window function?

**The problem.** You want each employee's salary **next to** their department's average. `GROUP BY` can compute the average, but it **collapses** the rows: you lose the individual employees.

```
   GROUP BY department                       Window function (OVER PARTITION BY department)
   7 rows  ───────►  4 rows                  7 rows  ───────►  7 rows
   (one row per department)                  (every employee kept, plus the department figure)

   Engineering | 100000                      Meera  Engineering 120000 | dept avg 100000
   Sales       |  67500                      Karan  Engineering  90000 | dept avg 100000
   ...                                       Sneha  Engineering  90000 | dept avg 100000
                                             ...
```

**Idea:** a window function calculates something over a **set of related rows** (the "window") but **keeps every row** in the result.

**Analogy:** passengers on a bus. `GROUP BY` would give you only the headcount. A window function lets *each passenger* keep their seat and also see the headcount, who sits next to them, and who got on before them.

**The syntax is always:**

```text
   function_name(...)  OVER (  PARTITION BY ...   ORDER BY ...   frame )
                               └─ which group ─┘  └─ in what ─┘  └─ which rows
                                  (optional)         order          around me
                                                     (optional)     (optional)
```

Everything inside `OVER (...)` describes the window. `OVER` is what turns an ordinary function into a window function.

### Where windows fit in the running order

```mermaid
flowchart LR
    A["1. FROM / JOIN"] --> B["2. WHERE"]
    B --> C["3. GROUP BY"]
    C --> D["4. HAVING"]
    D --> E["5. WINDOW functions"]
    E --> F["6. SELECT / DISTINCT"]
    F --> G["7. ORDER BY"]
    G --> H["8. LIMIT"]
    style E fill:#fef9c3,stroke:#ca8a04,color:#000
```

Window functions run **after** `WHERE`, `GROUP BY` and `HAVING`. That has two consequences:
- They only see rows that survived the filters.
- You **cannot** use a window function in `WHERE` (it doesn't exist yet). We'll solve that with a CTE in section 6.

---

## 2. OVER() with aggregates

Any aggregate (`SUM`, `AVG`, `COUNT`, `MIN`, `MAX`) becomes a window function when you add `OVER`. With **empty parentheses**, the window is the **whole result**.

```sql
SELECT name, salary,
       SUM(salary) OVER () AS company_total,
       ROUND(salary * 100.0 / SUM(salary) OVER (), 1) AS pct_of_total
FROM employees
ORDER BY employee_id;
```

| name | salary | company_total | pct_of_total |
|---|---|---|---|
| Rohan | 150000.00 | 645000.00 | 23.3 |
| Meera | 120000.00 | 645000.00 | 18.6 |
| Karan | 90000.00 | 645000.00 | 14.0 |
| Sneha | 90000.00 | 645000.00 | 14.0 |
| Imran | 70000.00 | 645000.00 | 10.9 |
| Priya | 65000.00 | 645000.00 | 10.1 |
| Tanvi | 60000.00 | 645000.00 | 9.3 |

```
   Every row sees the same window (all 7 rows), so SUM(salary) OVER () = 645000 on every row.
   Then each person's salary can be divided by it:  150000 / 645000 = 23.3%
```

Before window functions, this needed a subquery or a self-join. Now it's a single column.

---

## 3. PARTITION BY: windows per group

`PARTITION BY` splits the rows into groups, and the function is calculated **separately inside each group**. It's like `GROUP BY`, except rows aren't collapsed.

```sql
SELECT name, department, salary,
       ROUND(AVG(salary) OVER (PARTITION BY department), 0) AS dept_avg,
       salary - AVG(salary) OVER (PARTITION BY department)  AS diff_from_avg
FROM employees
ORDER BY employee_id;
```

| name | department | salary | dept_avg | diff_from_avg |
|---|---|---|---|---|
| Rohan | Management | 150000.00 | 150000 | 0 |
| Meera | Engineering | 120000.00 | 100000 | 20000 |
| Karan | Engineering | 90000.00 | 100000 | -10000 |
| Sneha | Engineering | 90000.00 | 100000 | -10000 |
| Imran | Sales | 70000.00 | 67500 | 2500 |
| Priya | Sales | 65000.00 | 67500 | -2500 |
| Tanvi | HR | 60000.00 | 60000 | 0 |

```
   PARTITION BY department splits the rows into separate windows:

   ┌─ Engineering window ───────────┐   ┌─ Sales window ──────┐   ┌─ Management ─┐  ┌─ HR ────┐
   │ Meera 120000                   │   │ Imran 70000         │   │ Rohan 150000 │  │ Tanvi   │
   │ Karan  90000   avg = 100000    │   │ Priya 65000         │   │ avg = 150000 │  │ 60000   │
   │ Sneha  90000                   │   │ avg = 67500         │   └──────────────┘  └─────────┘
   └────────────────────────────────┘   └─────────────────────┘
```

(You may recognise this from Chapter 4, where we found "employees above their department's average" with a correlated subquery. A window function is a cleaner way to get the same numbers.)

### GROUP BY vs window: same idea, different output shape

```sql
-- GROUP BY: 4 rows, one per department
SELECT department, COUNT(*) AS headcount FROM employees GROUP BY department ORDER BY department;

-- Window: 7 rows, every employee keeps their row and also sees the headcount
SELECT name, department, COUNT(*) OVER (PARTITION BY department) AS dept_size
FROM employees
ORDER BY employee_id;
```

| | `GROUP BY` | `OVER (PARTITION BY ...)` |
|---|---|---|
| Rows in result | one per group | same as the input |
| Can show individual row details? | No | Yes |
| Typical use | summary reports | comparing a row to its group |

---

## 4. ORDER BY inside OVER: running totals

Adding `ORDER BY` inside `OVER` makes the window **grow row by row**: each row sees itself and **everything before it**. That's a **running total**.

First, a helper: the total value of each order (we'll reuse it).

```sql
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
```

| order_id | order_date | total | running_total |
|---|---|---|---|
| 1 | 2024-05-01 | 60000.00 | 60000.00 |
| 2 | 2024-06-10 | 800.00 | 60800.00 |
| 3 | 2024-06-12 | 30000.00 | 90800.00 |
| 4 | 2024-06-15 | 2400.00 | 93200.00 |
| 5 | 2024-07-01 | 2500.00 | 95700.00 |
| 6 | 2024-07-04 | 32500.00 | 128200.00 |
| 7 | 2024-07-20 | 55300.00 | 183500.00 |

```
   row 1:  [60000]                                     = 60000
   row 2:  [60000, 800]                                = 60800
   row 3:  [60000, 800, 30000]                         = 90800
   ...each row's window = "from the start up to me"
```

The last running total (183500) equals total revenue across all orders, a handy sanity check.

**Always add a tie-breaker** (`order_id`) to the window's `ORDER BY` when the sort column can repeat, so the result is predictable.

### Ties and the default window (a subtle trap)

When `ORDER BY` is present and you give no frame, the default window is **"from the start up to the current row, including its peers"**. A *peer* is a row with the same `ORDER BY` value. Watch what happens when two rows tie:

```sql
SELECT name, salary,
       SUM(salary) OVER (PARTITION BY department ORDER BY salary) AS default_frame,
       SUM(salary) OVER (PARTITION BY department ORDER BY salary
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rows_frame
FROM employees
WHERE department = 'Engineering'
ORDER BY salary, name;
```

| name | salary | default_frame | rows_frame |
|---|---|---|---|
| Karan | 90000.00 | **180000.00** | 90000.00 |
| Sneha | 90000.00 | 180000.00 | 180000.00 |
| Meera | 120000.00 | 300000.00 | 300000.00 |

Karan and Sneha both earn 90000, so they are **peers**. The default frame includes **both** of them for each, so both show 180000. The `ROWS` frame counts strictly by physical row position, giving the "true" step-by-step running total (90000, then 180000).

> **Rule:** for running totals, write `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` (or break ties in `ORDER BY`) so duplicates can't surprise you.

---

## 5. Ranking functions

These number the rows within a window. They need `ORDER BY` inside `OVER`, since "rank" only makes sense with an ordering.

```sql
SELECT name, department, salary,
       ROW_NUMBER() OVER (ORDER BY salary DESC, name) AS row_num,
       RANK()       OVER (ORDER BY salary DESC)       AS rnk,
       DENSE_RANK() OVER (ORDER BY salary DESC)       AS dense_rnk
FROM employees
ORDER BY salary DESC, name;
```

| name | salary | row_num | rnk | dense_rnk |
|---|---|---|---|---|
| Rohan | 150000.00 | 1 | 1 | 1 |
| Meera | 120000.00 | 2 | 2 | 2 |
| Karan | 90000.00 | 3 | 3 | 3 |
| Sneha | 90000.00 | 4 | **3** | **3** |
| Imran | 70000.00 | 5 | **5** | **4** |
| Priya | 65000.00 | 6 | 6 | 5 |
| Tanvi | 60000.00 | 7 | 7 | 6 |

```
   Salaries:       150000  120000  90000  90000  70000  65000  60000
                                    └─ tie ─┘

   ROW_NUMBER:        1       2      3      4      5      6      7     always unique; ties split arbitrarily
   RANK:              1       2      3      3      5      6      7     ties share a rank, then a GAP
   DENSE_RANK:        1       2      3      3      4      5      6     ties share a rank, NO gap
```

| Function | Ties | Gaps after ties? | Use it when |
|---|---|---|---|
| `ROW_NUMBER()` | split arbitrarily (add a tie-breaker!) | n/a | you need exactly one row per position (dedupe, "pick one") |
| `RANK()` | share the rank | Yes (1,2,3,3,5) | competition-style ranking |
| `DENSE_RANK()` | share the rank | No (1,2,3,3,4) | "Nth highest value", categories |

### Ranking within groups

```sql
SELECT name, department, salary,
       RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank_in_dept
FROM employees
ORDER BY department, rank_in_dept, name;
```

| name | department | salary | rank_in_dept |
|---|---|---|---|
| Meera | Engineering | 120000.00 | 1 |
| Karan | Engineering | 90000.00 | 2 |
| Sneha | Engineering | 90000.00 | 2 |
| Tanvi | HR | 60000.00 | 1 |
| Rohan | Management | 150000.00 | 1 |
| Imran | Sales | 70000.00 | 1 |
| Priya | Sales | 65000.00 | 2 |

The ranking restarts at 1 inside each department.

### NTILE: split into equal-sized buckets

```sql
SELECT name, salary, NTILE(3) OVER (ORDER BY salary DESC, name) AS bucket
FROM employees
ORDER BY salary DESC, name;
```

| name | salary | bucket |
|---|---|---|
| Rohan | 150000.00 | 1 |
| Meera | 120000.00 | 1 |
| Karan | 90000.00 | 1 |
| Sneha | 90000.00 | 2 |
| Imran | 70000.00 | 2 |
| Priya | 65000.00 | 3 |
| Tanvi | 60000.00 | 3 |

7 rows into 3 buckets can't split evenly, so the leftover row goes to the **earlier** buckets (sizes 3, 2, 2). Use `NTILE(4)` for quartiles, `NTILE(100)` for percentiles.

### PERCENT_RANK and CUME_DIST

```sql
SELECT name, salary,
       ROUND(PERCENT_RANK() OVER (ORDER BY salary)::numeric, 2) AS pct_rank,
       ROUND(CUME_DIST()    OVER (ORDER BY salary)::numeric, 2) AS cume_dist
FROM employees
ORDER BY salary, name;
```

| name | salary | pct_rank | cume_dist |
|---|---|---|---|
| Tanvi | 60000.00 | 0.00 | 0.14 |
| Priya | 65000.00 | 0.17 | 0.29 |
| Imran | 70000.00 | 0.33 | 0.43 |
| Karan | 90000.00 | 0.50 | 0.71 |
| Sneha | 90000.00 | 0.50 | 0.71 |
| Meera | 120000.00 | 0.83 | 0.86 |
| Rohan | 150000.00 | 1.00 | 1.00 |

- `PERCENT_RANK` = (rank - 1) / (rows - 1): "how far up the list am I?" (0 at the bottom, 1 at the top).
- `CUME_DIST` = rows at or below me / total rows: "what fraction of people earn the same or less than me?"

---

## 6. Top N per group (and why you need a CTE)

**Goal:** the top 2 earners in each department.

The natural attempt fails, because window functions don't exist yet at the `WHERE` step:

```sql
SELECT name FROM employees WHERE ROW_NUMBER() OVER (ORDER BY salary) = 1;
-- ERROR: window functions are not allowed in WHERE
```

**The pattern: compute the rank in a CTE (or subquery), then filter on it outside.**

```sql
WITH ranked AS (
    SELECT name, department, salary,
           ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC, name) AS rn
    FROM employees
)
SELECT department, name, salary, rn
FROM ranked
WHERE rn <= 2
ORDER BY department, rn;
```

| department | name | salary | rn |
|---|---|---|---|
| Engineering | Meera | 120000.00 | 1 |
| Engineering | Karan | 90000.00 | 2 |
| HR | Tanvi | 60000.00 | 1 |
| Management | Rohan | 150000.00 | 1 |
| Sales | Imran | 70000.00 | 1 |
| Sales | Priya | 65000.00 | 2 |

```
   Step 1 (inside the CTE):  number each employee within their department by salary
   Step 2 (outside):         keep rn <= 2
```

### Which ranking function to use? It changes the answer

Engineering has a tie for second place. Compare:

```sql
WITH ranked AS (
    SELECT name, department, salary,
           RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rk
    FROM employees
)
SELECT department, name, salary, rk
FROM ranked
WHERE rk <= 2
ORDER BY department, rk, name;
```

With `RANK`, Engineering returns **three** rows (Meera, Karan, Sneha), since Karan and Sneha both rank 2nd. With `ROW_NUMBER`, it returns exactly **two**, and the tie-breaker (`name`) decides who is left out.

```
   "Give me exactly N rows per group"            ->  ROW_NUMBER  (and choose a tie-breaker)
   "Give me everyone who ranks in the top N"     ->  RANK or DENSE_RANK  (ties may exceed N)
```

### Top 1 per group: best-selling product in each category

```sql
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
```

| category | name | revenue |
|---|---|---|
| Electronics | Laptop | 110000.00 |
| Home | Desk Lamp | 2400.00 |
| Stationery | Notebook | 900.00 |

### Latest row per group (the neat way)

In Chapter 4 we found each customer's latest order with a correlated subquery. With a window function:

```sql
WITH ranked AS (
    SELECT order_id, customer_id, order_date,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
    FROM orders
)
SELECT order_id, customer_id, order_date
FROM ranked
WHERE rn = 1
ORDER BY customer_id;
```

Same result (orders 2, 3, 7, 5, 6), easier to read and to change: want the 2nd most recent? Use `rn = 2`.

### The Nth highest value (the clean way)

In Chapter 4 we used `LIMIT`/`OFFSET` for the 3rd highest salary. With `DENSE_RANK`, ties are handled naturally:

```sql
WITH ranked AS (
    SELECT name, salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS dr
    FROM employees
)
SELECT name, salary FROM ranked WHERE dr = 3;                  -- Karan, Sneha (90000)
```

---

## 7. LAG and LEAD: looking at neighbouring rows

- `LAG(col)` gives the value from the **previous** row.
- `LEAD(col)` gives the value from the **next** row.
- Both use the window's `ORDER BY` to decide what "previous" and "next" mean.

```
   ordered rows:     [row 1]  [row 2]  [row 3]  [row 4]
                                  ▲        ▲
   For row 3:         LAG(col) ───┘        └─── LEAD(col)
                      (previous row)            (next row)
```

```sql
SELECT customer_id, order_id, order_date,
       LAG(order_date)  OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_order,
       order_date - LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS days_since_prev,
       LEAD(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS next_order
FROM orders
ORDER BY customer_id, order_date;
```

| customer_id | order_id | order_date | prev_order | days_since_prev | next_order |
|---|---|---|---|---|---|
| 1 | 1 | 2024-05-01 | NULL | NULL | 2024-06-10 |
| 1 | 2 | 2024-06-10 | 2024-05-01 | 40 | NULL |
| 2 | 3 | 2024-06-12 | NULL | NULL | NULL |
| 3 | 4 | 2024-06-15 | NULL | NULL | 2024-07-20 |
| 3 | 7 | 2024-07-20 | 2024-06-15 | 35 | NULL |
| 4 | 5 | 2024-07-01 | NULL | NULL | NULL |
| 5 | 6 | 2024-07-04 | NULL | NULL | NULL |

`PARTITION BY customer_id` keeps each customer's orders separate, so Chitra's first order doesn't "see" Asha's last one. The first row of each group has no previous row, so `LAG` gives `NULL`.

### Optional arguments: offset and default

```text
LAG(col, 2)            -- two rows back
LAG(col, 1, 'nobody')  -- one row back; use 'nobody' instead of NULL when there is none
```

```sql
SELECT name, hire_date, LAG(name, 1, 'nobody') OVER (ORDER BY hire_date) AS hired_just_before
FROM employees
ORDER BY hire_date;
```

| name | hire_date | hired_just_before |
|---|---|---|
| Rohan | 2018-01-10 | nobody |
| Meera | 2019-03-15 | Rohan |
| Karan | 2020-07-01 | Meera |
| Imran | 2020-11-05 | Karan |
| Sneha | 2021-02-20 | Imran |
| Tanvi | 2021-09-09 | Sneha |
| Priya | 2022-01-17 | Tanvi |

### Month-over-month growth

The most common use of `LAG`. First total each month, then compare with the previous month:

```sql
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
```

| month | revenue | prev_month | growth_pct | cumulative |
|---|---|---|---|---|
| 2024-05-01 | 60000.00 | NULL | NULL | 60000.00 |
| 2024-06-01 | 3200.00 | 60000.00 | -94.67 | 63200.00 |
| 2024-07-01 | 87800.00 | 3200.00 | 2643.75 | 151000.00 |

```
   growth % = (this month - last month) / last month × 100
   June:  (3200 - 60000) / 60000 × 100 = -94.67 %
```

The first month has no previous month, so its growth is `NULL`. (The numbers swing wildly because the sample data is tiny.)

### The difference from the previous row

```sql
SELECT name, salary, salary - LAG(salary) OVER (ORDER BY salary, name) AS step_up
FROM employees
ORDER BY salary, name;
```

Each salary minus the next-lower salary: Tanvi `NULL`, Priya 5000, Imran 5000, Karan 20000, Sneha 0, Meera 30000, Rohan 30000.

---

## 8. FIRST_VALUE, LAST_VALUE, NTH_VALUE

These pick a value from a specific position in the window.

| Function | Returns |
|---|---|
| `FIRST_VALUE(col)` | the first row's value in the window |
| `LAST_VALUE(col)` | the last row's value in the window |
| `NTH_VALUE(col, n)` | the n-th row's value in the window |

```sql
SELECT name, department, salary,
       FIRST_VALUE(name) OVER (PARTITION BY department ORDER BY salary DESC, name) AS top_earner,
       LAST_VALUE(name)  OVER (PARTITION BY department ORDER BY salary DESC, name) AS last_default,
       LAST_VALUE(name)  OVER (PARTITION BY department ORDER BY salary DESC, name
                               ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS lowest_earner
FROM employees
WHERE department IN ('Engineering', 'Sales')
ORDER BY department, salary DESC, name;
```

| name | department | salary | top_earner | last_default | lowest_earner |
|---|---|---|---|---|---|
| Meera | Engineering | 120000.00 | Meera | Meera | Sneha |
| Karan | Engineering | 90000.00 | Meera | Karan | Sneha |
| Sneha | Engineering | 90000.00 | Meera | Sneha | Sneha |
| Imran | Sales | 70000.00 | Imran | Imran | Priya |
| Priya | Sales | 65000.00 | Imran | Priya | Priya |

### The LAST_VALUE trap

Look at `last_default`: it just echoes **each row's own name**, which is not "the last in the department". Why? The default window ends at the **current row** (section 4), so "the last row in my window" is always... me. The fix is to widen the frame to the whole partition, as in `lowest_earner`:

```
   Default frame (ends at me):     [Meera]  [Meera, Karan]  [Meera, Karan, Sneha]
                                       last = Meera   last = Karan   last = Sneha   ✘ not what we wanted

   Full frame (UNBOUNDED FOLLOWING): every row sees [Meera, Karan, Sneha]
                                       last = Sneha for everyone   ✔
```

`FIRST_VALUE` doesn't have this problem, because the window always *starts* at the beginning. `NTH_VALUE` has the same trap as `LAST_VALUE`:

```sql
SELECT name, salary,
       NTH_VALUE(name, 2) OVER (ORDER BY salary DESC, name
                                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS second_name
FROM employees
ORDER BY salary DESC, name
LIMIT 2;
```

Here Rohan's row shows `Meera` (the 2nd highest earner), and Meera's row also shows `Meera`.

---

## 9. Frames: choosing exactly which rows to look at

A **frame** narrows the window to a set of rows **around the current row**. It's the last optional part of `OVER`.

```text
   ROWS BETWEEN  <start>  AND  <end>
```

| Boundary | Meaning |
|---|---|
| `UNBOUNDED PRECEDING` | from the very first row of the partition |
| `n PRECEDING` | n rows before the current row |
| `CURRENT ROW` | the current row |
| `n FOLLOWING` | n rows after the current row |
| `UNBOUNDED FOLLOWING` | to the very last row of the partition |

```
   rows:        r1   r2   r3   r4   r5   r6   r7
                               ▲
                           current row (r4)

   ROWS BETWEEN 2 PRECEDING AND CURRENT ROW         ->        [r2  r3  r4]
   ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING         ->             [r3  r4  r5]
   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ->  [r1  r2  r3  r4]          (running total)
   ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING ->                [r4  r5  r6  r7]
```

### Moving average

A 3-order moving average smooths out the ups and downs. Each row averages itself and the two rows before it:

```sql
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
```

| order_id | order_date | total | moving_avg_3 |
|---|---|---|---|
| 1 | 2024-05-01 | 60000.00 | 60000.00 |
| 2 | 2024-06-10 | 800.00 | 30400.00 |
| 3 | 2024-06-12 | 30000.00 | 30266.67 |
| 4 | 2024-06-15 | 2400.00 | 11066.67 |
| 5 | 2024-07-01 | 2500.00 | 11633.33 |
| 6 | 2024-07-04 | 32500.00 | 12466.67 |
| 7 | 2024-07-20 | 55300.00 | 30100.00 |

```
   Row 4:  AVG of rows 2, 3, 4  =  (800 + 30000 + 2400) / 3  =  11066.67
   Rows 1 and 2 have fewer than 3 rows available, so they average whatever exists.
```

### ROWS vs RANGE vs GROUPS

| Frame type | Counts by | Ties |
|---|---|---|
| `ROWS` | physical row position | each row is separate (predictable) |
| `RANGE` | the **value** of the `ORDER BY` column | rows with equal values (peers) are treated together |
| `GROUPS` | groups of peers | counts whole groups of tied rows |

When you don't write a frame but **do** use `ORDER BY`, the default is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. When you don't use `ORDER BY` at all, the window is the **entire partition**.

```
   OVER ()                                    ->  the whole result
   OVER (PARTITION BY x)                      ->  the whole group
   OVER (ORDER BY y)                          ->  start of group up to me, INCLUDING ties (RANGE)
   OVER (ORDER BY y ROWS BETWEEN ...)         ->  exactly the rows you describe
```

---

## 10. Windows over grouped data, and named windows

### Window functions after GROUP BY

Since windows run after `GROUP BY`, you can apply them **to the grouped results**, even wrapping an aggregate inside a window function:

```sql
SELECT p.category,
       SUM(oi.quantity * p.price) AS revenue,
       ROUND(100.0 * SUM(oi.quantity * p.price) / SUM(SUM(oi.quantity * p.price)) OVER (), 1) AS pct_of_total,
       RANK() OVER (ORDER BY SUM(oi.quantity * p.price) DESC) AS rk
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY revenue DESC;
```

| category | revenue | pct_of_total | rk |
|---|---|---|---|
| Electronics | 180000.00 | 98.1 | 1 |
| Home | 2400.00 | 1.3 | 2 |
| Stationery | 1100.00 | 0.6 | 3 |

```
   SUM(SUM(x)) OVER ()
        │   └─ inner SUM: total per category (the GROUP BY part)
        └───── outer SUM ... OVER (): adds up those category totals across all groups
```

Read `SUM(SUM(x)) OVER ()` from the inside out: first each group is summed, then the window adds up the groups.

### Named windows: avoid repeating yourself

If several functions share the same window, define it once with `WINDOW`:

```sql
SELECT name, department, salary,
       RANK()       OVER w AS rank_in_dept,
       SUM(salary)  OVER w AS running_total
FROM employees
WINDOW w AS (PARTITION BY department ORDER BY salary DESC)
ORDER BY department, rank_in_dept, name;
```

`WINDOW w AS (...)` goes after `FROM`/`WHERE`/`GROUP BY`/`HAVING` and before `ORDER BY`. It's pure convenience: same results, less repetition.

---

## 11. Classic patterns

These recurring problems appear constantly in real work. Each one is a small recipe.

### Pattern A: remove duplicates, keeping one row per key

Suppose a table has repeated emails and you want only the **newest** row per email. Number the rows within each email (newest first) and keep number 1:

```sql
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
```

| id | email | created_at |
|---|---|---|
| 4 | a@x.com | 2024-03-01 |
| 5 | c@x.com | 2024-01-20 |
| 6 | b@x.com | 2024-01-16 |

`rn > 1` would give you the duplicates to delete (Chapter 6 shows `DELETE`). `ROW_NUMBER` is the right choice here because you need **exactly one** row per email.

### Pattern B: consecutive streaks (the "gaps and islands" trick)

**Goal:** find runs of consecutive days in a list of login dates.

**The trick:** subtract each row's position number from its date. Within a run of consecutive days, the date goes up by 1 and the position goes up by 1, so the **difference stays constant**. A gap in the dates changes the difference and starts a new group.

```sql
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
```

| streak_start | streak_end | days |
|---|---|---|
| 2024-03-01 | 2024-03-03 | 3 |
| 2024-03-05 | 2024-03-06 | 2 |
| 2024-03-09 | 2024-03-09 | 1 |

Here is the middle step, so the trick is visible:

| d | row number | d minus row number (grp) |
|---|---|---|
| 2024-03-01 | 1 | 2024-02-29 |
| 2024-03-02 | 2 | 2024-02-29 |
| 2024-03-03 | 3 | 2024-02-29 |
| 2024-03-05 | 4 | 2024-03-01 |
| 2024-03-06 | 5 | 2024-03-01 |
| 2024-03-09 | 6 | 2024-03-03 |

The first three rows share `2024-02-29`, the next two share `2024-03-01`, and the last stands alone. Grouping by that value gives each streak. With several users, add `PARTITION BY user_id` to the `ROW_NUMBER` and group by user as well.

### Pattern C: compare each row to its group

```sql
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
```

### Pattern D: share of total and cumulative share

```sql
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
```

| name | spend | rk | pct | cumulative_pct |
|---|---|---|---|---|
| Asha | 60800.00 | 1 | 40.3 | 40.3 |
| Chitra | 57700.00 | 2 | 38.2 | 78.5 |
| Esha | 32500.00 | 3 | 21.5 | 100.0 |

The cumulative percentage is the basis of "the top 20% of customers produce 80% of revenue" analyses.

### Which tool for which problem?

| Problem | Reach for |
|---|---|
| Rank / "Nth highest" | `DENSE_RANK`, `RANK` |
| Top N per group, latest per group | `ROW_NUMBER` / `RANK` in a CTE, then filter |
| Remove duplicates | `ROW_NUMBER() ... PARTITION BY key` then keep `rn = 1` |
| Running total / moving average | `SUM`/`AVG` with `ORDER BY` and a `ROWS` frame |
| Compare to previous / next row, growth | `LAG` / `LEAD` |
| Share of total | `value / SUM(value) OVER ()` |
| Compare to group average | `AVG(...) OVER (PARTITION BY ...)` |
| Streaks of consecutive values | `value - ROW_NUMBER()` grouping trick |
| Quartiles / buckets | `NTILE(n)` |

---

## 12. Chapter 5 cheat sheet

```sql
function(...) OVER (
    PARTITION BY col          -- optional: separate windows per group
    ORDER BY col              -- optional: order inside the window
    ROWS BETWEEN ... AND ...  -- optional: exactly which rows
)
```

| Group | Functions |
|---|---|
| Aggregates as windows | `SUM`, `AVG`, `COUNT`, `MIN`, `MAX` + `OVER` |
| Ranking | `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE`, `PERCENT_RANK`, `CUME_DIST` |
| Neighbour access | `LAG`, `LEAD` |
| Position access | `FIRST_VALUE`, `LAST_VALUE`, `NTH_VALUE` |

**Things never to forget**
1. Window functions **keep every row**. `GROUP BY` collapses them.
2. They can't be used in `WHERE`. Compute them in a CTE, then filter outside.
3. `PARTITION BY` = separate windows per group. `ORDER BY` inside `OVER` = order within the window and a growing frame.
4. `ROW_NUMBER` is unique, `RANK` leaves gaps after ties, `DENSE_RANK` doesn't. Add a tie-breaker to `ROW_NUMBER`.
5. The default frame with `ORDER BY` ends at the current row and includes peers. For `LAST_VALUE` or exact running totals, spell out the frame with `ROWS BETWEEN ...`.
6. `LAG`/`LEAD` return `NULL` at the edges (or your default).

---

## 13. Practice problems

Type each query yourself. Say it in English first. For anything with a filter on a rank, use a CTE.

### Easy
1. Show each employee with the company's total salary and their percentage share of it.
2. Show each employee with their department's average salary and the difference from it.
3. Show each employee with the size of their department, using a window function (not `GROUP BY`).
4. Show employees ranked by salary with `ROW_NUMBER`, `RANK` and `DENSE_RANK` side by side.
5. Rank employees by salary **within their department**.
6. Split employees into 3 salary buckets using `NTILE`.

### Medium
7. Show the top 2 earners in each department. Do it with `ROW_NUMBER`, then with `RANK`, and explain why the Engineering result differs.
8. Show each customer's most recent order using `ROW_NUMBER`.
9. Find the 3rd highest distinct salary (and who earns it) using `DENSE_RANK`.
10. Show each order with its total value and a running total ordered by date.
11. For each order, show how many days passed since that customer's previous order.
12. Show monthly delivered revenue with the previous month's revenue and the growth percentage.
13. Show each employee with the name of the person hired just before them (use `'nobody'` for the first).
14. For each department, show every employee alongside the department's highest-paid and lowest-paid employee names.
15. Show each order's total and a 3-order moving average, ordered by date.
16. Show revenue by product category with each category's percentage of total revenue and its rank.

### Challenging
17. This list has duplicate emails. Keep only the **newest** row for each email.
    ```sql
    VALUES (1, 'a@x.com', DATE '2024-01-01'), (2, 'a@x.com', DATE '2024-02-01'),
           (3, 'b@x.com', DATE '2024-01-15'), (4, 'a@x.com', DATE '2024-03-01'),
           (5, 'c@x.com', DATE '2024-01-20'), (6, 'b@x.com', DATE '2024-01-16')
    ```
18. Find streaks of consecutive days in this login list, with start, end and length:
    ```sql
    VALUES (DATE '2024-04-10'), (DATE '2024-04-11'), (DATE '2024-04-12'), (DATE '2024-04-13'),
           (DATE '2024-04-20'), (DATE '2024-04-21'), (DATE '2024-04-25')
    ```
19. Show each customer's delivered spend with rank, percentage of total, and cumulative percentage.
20. Find employees earning more than their department's average using a **window function** instead of a correlated subquery.
21. Predict the output first, then run: for Engineering, what does `SUM(salary) OVER (ORDER BY salary)` give for Karan and Sneha, compared with the same expression using `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`?
22. Each of these has a mistake. Explain what's wrong and fix it:
    ```sql
    -- (a) goal: the highest-paid employee in each department
    SELECT name, department FROM employees
    WHERE RANK() OVER (PARTITION BY department ORDER BY salary DESC) = 1;
    -- (b) goal: the lowest earner's name in each department, shown on every row
    SELECT name, department,
           LAST_VALUE(name) OVER (PARTITION BY department ORDER BY salary DESC) AS lowest_earner
    FROM employees;
    -- (c) goal: number each employee within their department from highest to lowest salary
    SELECT name, department,
           ROW_NUMBER() OVER (PARTITION BY department) AS position
    FROM employees;
    ```

**Self-check: you've mastered Chapter 5 when you can explain, without notes:**
- how a window function differs from `GROUP BY`,
- why you can't filter on a window function in `WHERE`, and the CTE pattern that solves it,
- the difference between `ROW_NUMBER`, `RANK` and `DENSE_RANK`,
- what `PARTITION BY`, `ORDER BY` and the frame each control,
- why `LAST_VALUE` needs an explicit frame.

---

## 14. Solutions

<details>
<summary><b>Click to reveal (try first!)</b></summary>

```sql
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
```

</details>

---

*End of Chapter 5.*

**Next:** Chapter 6: Writing and Designing (`INSERT`, `UPDATE`, `DELETE`, upsert, constraints, normalization, and transactions).
