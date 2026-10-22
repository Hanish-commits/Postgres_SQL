# PostgreSQL Mastery

A learn-by-doing guide to PostgreSQL, from zero to advanced. Every concept comes with a plain-English idea, a diagram, a runnable example, and the mistakes to avoid.

## Table of contents

| # | Chapter | What you'll learn | Status |
|---|---|---|---|
| 1 | [Foundations](chapters/01-foundations.md) | Tables, data types, `SELECT`, `WHERE`, `ORDER BY`, `LIMIT`, `DISTINCT`, `IN`, `BETWEEN`, `LIKE`, `NULL` | Ready |
| 2 | [Shaping Data](chapters/02-shaping-data.md) | Aggregates, `GROUP BY`, `HAVING`, string/number/date functions, `CASE`, `FILTER`, casting | Ready |
| 3 | [Joins](chapters/03-joins.md) | Keys, `INNER`/`LEFT`/`RIGHT`/`FULL`/`CROSS`, self joins, anti-joins, `UNION`/`INTERSECT`/`EXCEPT` | Ready |
| 4 | [Subqueries and CTEs](chapters/04-subqueries-and-ctes.md) | Scalar/list/derived subqueries, correlated, `EXISTS` vs `IN`, `WITH`, recursive CTEs | Ready |
| 5 | [Window Functions](chapters/05-window-functions.md) | `OVER`, `PARTITION BY`, ranking, `LAG`/`LEAD`, running totals, frames, top-N, dedupe, streaks | Ready |
| 6 | [Writing and Designing](chapters/06-writing-and-designing.md) | `INSERT`/`UPDATE`/`DELETE`, upsert, `CREATE TABLE`, constraints, normalization, transactions and ACID | Ready |

## How to use this repo

1. Install PostgreSQL and a client (DataGrip, pgAdmin, DBeaver or `psql`).
2. Run `CREATE DATABASE shop;`, connect to it, then run [`sql/schema.sql`](sql/schema.sql). It builds the practice database and is safe to re-run: it also wipes anything Chapter 6 created, so re-running it is a full reset.
3. For each chapter: read it, type every example yourself, attempt the practice problems, then check the solutions.

```
  READ the idea  ->  TYPE the example  ->  BREAK it on purpose  ->  PRACTICE  ->  CHECK solution
```

## Repo layout

```
chapters/    the lessons, one file per chapter
sql/         schema.sql plus runnable examples and solutions for each chapter
```
