-- Chapter 6 practice solutions. Run schema.sql first for a clean slate, then run in order.
-- Try the problems in chapters/06-writing-and-designing.md first!

-- 1
INSERT INTO customers (name, city, signup_date) VALUES ('Gita', 'Pune', '2024-06-01')
RETURNING customer_id;

-- 2
INSERT INTO products (name, category, price)
VALUES ('Mouse', 'Electronics', 800), ('Stapler', 'Stationery', 150);

-- 3
UPDATE customers SET city = 'Hyderabad' WHERE name = 'Gita';

-- 4
UPDATE products SET price = price * 1.10 WHERE category = 'Stationery' RETURNING name, price;

-- 5
DELETE FROM customers WHERE name = 'Gita';

-- 6
DELETE FROM products WHERE name = 'Stapler';

-- 7
CREATE TABLE wishlist (
    wishlist_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  INT NOT NULL REFERENCES customers(customer_id),
    product_id   INT NOT NULL REFERENCES products(product_id),
    added_on     DATE NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE (customer_id, product_id)
);
INSERT INTO wishlist (customer_id, product_id) VALUES (1, 2);
-- INSERT INTO wishlist (customer_id, product_id) VALUES (1, 2);
-- ERROR: duplicate key value violates unique constraint "wishlist_customer_id_product_id_key"

-- 8
ALTER TABLE wishlist ADD COLUMN priority INT NOT NULL DEFAULT 1 CHECK (priority BETWEEN 1 AND 3);

-- 9
INSERT INTO wishlist (customer_id, product_id, priority) VALUES (1, 2, 3)
ON CONFLICT (customer_id, product_id) DO UPDATE SET priority = EXCLUDED.priority;

-- 10
UPDATE orders SET status = 'delivered'
WHERE status = 'pending' AND order_date < '2024-07-02'
RETURNING order_id, order_date, status;                                   -- order 5

-- 11
DELETE FROM order_items
WHERE order_id IN (SELECT order_id FROM orders WHERE status = 'cancelled')
RETURNING *;                                                              -- order 3's item (order 5 is now delivered)

-- 12
CREATE TABLE electronics_copy AS SELECT * FROM products WHERE category = 'Electronics';
SELECT COUNT(*) FROM electronics_copy;                                    -- 4: Laptop, Phone, Headphones, and Mouse from problem 2

-- 13
UPDATE employees SET salary = salary * 1.05
WHERE department = 'Engineering'
RETURNING name, salary;

-- 14
CREATE TABLE accounts (account_id INT PRIMARY KEY, owner TEXT NOT NULL,
                       balance NUMERIC(12,2) NOT NULL CHECK (balance >= 0));
INSERT INTO accounts VALUES (1, 'Asha', 1000), (2, 'Ben', 500);

BEGIN;
UPDATE accounts SET balance = balance - 300 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 300 WHERE account_id = 2;
COMMIT;
SELECT * FROM accounts ORDER BY account_id;                               -- Asha 700, Ben 800

-- 15
-- BEGIN;
-- UPDATE accounts SET balance = balance - 5000 WHERE account_id = 1;
-- ERROR: new row for relation "accounts" violates check constraint "accounts_balance_check"
-- UPDATE accounts SET balance = balance + 5000 WHERE account_id = 2;
-- ERROR: current transaction is aborted, commands ignored until end of transaction block
-- ROLLBACK;
-- The debit would make Asha's balance -4300, violating CHECK (balance >= 0), so the transaction is aborted.
-- Every later statement is ignored until ROLLBACK, and neither account changes: Asha 700, Ben 800.
SELECT * FROM accounts ORDER BY account_id;                               -- unchanged

-- 16
BEGIN;
INSERT INTO wishlist (customer_id, product_id) VALUES (2, 1), (2, 3);
SAVEPOINT after_two;
INSERT INTO wishlist (customer_id, product_id) VALUES (3, 1);
ROLLBACK TO SAVEPOINT after_two;
COMMIT;
SELECT customer_id, product_id FROM wishlist ORDER BY wishlist_id;        -- (1,2), (2,1), (2,3); the (3,1) row is gone

-- 17
CREATE TABLE emails (id INT PRIMARY KEY, email TEXT NOT NULL, created_at DATE NOT NULL);
INSERT INTO emails VALUES (1,'a@x.com','2024-01-01'), (2,'a@x.com','2024-02-01'), (3,'b@x.com','2024-01-15'),
                          (4,'a@x.com','2024-03-01'), (5,'c@x.com','2024-01-20'), (6,'b@x.com','2024-01-16');
CREATE TABLE emails_archive (LIKE emails);

WITH dupes AS (
    SELECT id
    FROM (SELECT id, ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_at DESC) AS rn FROM emails) AS t
    WHERE rn > 1
),
moved AS (
    DELETE FROM emails WHERE id IN (SELECT id FROM dupes) RETURNING *
)
INSERT INTO emails_archive SELECT * FROM moved;

SELECT * FROM emails ORDER BY id;                                         -- ids 4, 5, 6
SELECT * FROM emails_archive ORDER BY id;                                 -- ids 1, 2, 3

-- 18
-- Violations: the key is (order_id, product_name).
--   2NF: customer_name and customer_city depend only on order_id; product_price depends only on product_name.
--   3NF: customer_city depends on customer_name (a non-key column), not on the key.
CREATE TABLE orders_flat (order_id INT, customer_name TEXT, customer_city TEXT,
                          product_name TEXT, product_price NUMERIC(10,2), quantity INT);
INSERT INTO orders_flat VALUES
    (1,'Asha','Mumbai','Laptop',55000,1), (1,'Asha','Mumbai','Headphones',2500,2),
    (2,'Asha','Mumbai','Notebook',60,10), (3,'Ben','Delhi','Phone',30000,1),
    (4,'Chitra','Mumbai','Headphones',2500,1);

CREATE TABLE flat_customers (
    customer_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         TEXT NOT NULL UNIQUE,
    city         TEXT
);
CREATE TABLE flat_products (
    product_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    price       NUMERIC(10,2) NOT NULL CHECK (price >= 0)
);
CREATE TABLE flat_orders (
    order_id     INT PRIMARY KEY,
    customer_id  INT NOT NULL REFERENCES flat_customers(customer_id)
);
CREATE TABLE flat_order_items (
    order_id    INT REFERENCES flat_orders(order_id),
    product_id  INT REFERENCES flat_products(product_id),
    quantity    INT NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (order_id, product_id)
);

INSERT INTO flat_customers (name, city)
SELECT DISTINCT customer_name, customer_city FROM orders_flat;

INSERT INTO flat_products (name, price)
SELECT DISTINCT product_name, product_price FROM orders_flat;

INSERT INTO flat_orders (order_id, customer_id)
SELECT DISTINCT f.order_id, c.customer_id
FROM orders_flat f
JOIN flat_customers c ON c.name = f.customer_name;

INSERT INTO flat_order_items (order_id, product_id, quantity)
SELECT f.order_id, p.product_id, f.quantity
FROM orders_flat f
JOIN flat_products p ON p.name = f.product_name;

-- check: rebuild the flat view by joining back (should be 5 rows)
SELECT o.order_id, c.name AS customer, c.city, p.name AS product, p.price, oi.quantity
FROM flat_order_items oi
JOIN flat_orders o    ON o.order_id    = oi.order_id
JOIN flat_customers c ON c.customer_id = o.customer_id
JOIN flat_products p  ON p.product_id  = oi.product_id
ORDER BY o.order_id, p.name;

-- 19 (predicted errors, shown as comments)
-- (a) duplicate key value violates unique constraint "accounts_pkey"                  (account_id 1 already exists)
-- (b) new row for relation "accounts" violates check constraint "accounts_balance_check"   (balance can't be negative)
-- (c) insert or update on table "wishlist" violates foreign key constraint "wishlist_customer_id_fkey"   (no customer 999)
-- (d) update or delete on table "customers" violates foreign key constraint "orders_customer_id_fkey"    (customer 1 has orders)

-- 20
-- (a) no WHERE: every employee would get 70000. Add the condition:
UPDATE employees SET salary = 70000 WHERE name = 'Priya';
-- (b) two columns, one value. Supply both:
INSERT INTO customers (name, city) VALUES ('Leela', 'Surat');
-- (c) priority isn't unique, so it can't be the conflict target. The unique rule is (customer_id, product_id):
INSERT INTO wishlist (customer_id, product_id, priority) VALUES (1, 2, 2)
ON CONFLICT (customer_id, product_id) DO UPDATE SET priority = 2;
