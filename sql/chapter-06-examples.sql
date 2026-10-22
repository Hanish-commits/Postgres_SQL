-- Chapter 6: all lesson examples, in lesson order.
-- These examples BUILD ON EACH OTHER: reset first by running schema.sql, then run top to bottom.
-- Lines starting with '-- ERROR DEMO' are deliberate mistakes: remove the leading '--' to see the error.


-- ============================================================
-- 1. INSERT: adding rows
-- ============================================================

INSERT INTO customers (name, city, signup_date) VALUES ('Gita', 'Pune', '2024-06-01');

INSERT INTO customers (name, city, signup_date)
VALUES ('Harsh', 'Pune', '2024-06-10'),
       ('Isha',  NULL,   '2024-06-20');                  -- INSERT 0 2

INSERT INTO customers (name) VALUES ('Jay');              -- city and signup_date become NULL

INSERT INTO customers (name, city) VALUES ('Kiran', 'Chennai')
RETURNING customer_id, name, city;

CREATE TABLE city_customers (name TEXT, city TEXT);

INSERT INTO city_customers
SELECT name, city FROM customers WHERE city = 'Mumbai';   -- INSERT 0 2

-- ERROR DEMO: INSERT INTO customers (city) VALUES ('Pune');
-- ERROR: null value in column "name" of relation "customers" violates not-null constraint
-- ERROR DEMO: INSERT INTO customers (name, city) VALUES ('Leela');
-- ERROR: INSERT has more target columns than expressions

INSERT INTO customers (name) VALUES ('Mani') RETURNING customer_id;


-- ============================================================
-- 2. UPDATE: changing rows
-- ============================================================

UPDATE customers SET city = 'Pune' WHERE name = 'Jay';                                 -- UPDATE 1
UPDATE customers SET city = 'Goa', signup_date = '2024-06-15' WHERE name = 'Isha';     -- several columns at once

UPDATE products
SET price = price * 1.10
WHERE category = 'Stationery'
RETURNING name, price;

UPDATE employees
SET salary = CASE WHEN department = 'Engineering' THEN salary * 1.05
                  WHEN department = 'Sales'       THEN salary * 1.03
                  ELSE salary END
RETURNING name, department, salary;

-- cancel pending orders belonging to customers with no city on file
UPDATE orders o
SET status = 'cancelled'
FROM customers c
WHERE c.customer_id = o.customer_id
  AND c.city IS NULL
  AND o.status = 'pending'
RETURNING o.order_id, c.name, o.status;

BEGIN;                                                    -- start a safety bubble
UPDATE products SET price = 0;                            -- UPDATE 6   (six! that's wrong!)
SELECT name, price FROM products ORDER BY product_id;     -- everything is 0.00. Oops.
ROLLBACK;                                                 -- undo everything since BEGIN
SELECT name, price FROM products ORDER BY product_id;     -- prices are back


-- ============================================================
-- 3. DELETE: removing rows
-- ============================================================

DELETE FROM customers WHERE name = 'Mani';                -- DELETE 1

-- ERROR DEMO: DELETE FROM customers WHERE name = 'Asha';
-- ERROR: update or delete on table "customers" violates foreign key constraint "orders_customer_id_fkey" on table "orders"
-- DETAIL: Key (customer_id)=(1) is still referenced from table "orders".

-- remove the line items of cancelled orders
DELETE FROM order_items
WHERE order_id IN (SELECT order_id FROM orders WHERE status = 'cancelled')
RETURNING *;

DELETE FROM city_customers WHERE name = 'Asha';           -- DELETE 1: one row gone, one left

BEGIN;
TRUNCATE city_customers;                                  -- empties the table instantly
SELECT COUNT(*) FROM city_customers;                      -- 0
ROLLBACK;                                                 -- Postgres lets you undo even TRUNCATE
SELECT COUNT(*) FROM city_customers;                      -- 1 again

TRUNCATE city_customers;                                  -- empty it for real
DROP TABLE city_customers;                                -- remove the table itself

CREATE TABLE emails (id INT PRIMARY KEY, email TEXT NOT NULL, created_at DATE NOT NULL);
INSERT INTO emails VALUES
    (1, 'a@x.com', '2024-01-01'), (2, 'a@x.com', '2024-02-01'), (3, 'b@x.com', '2024-01-15'),
    (4, 'a@x.com', '2024-03-01'), (5, 'c@x.com', '2024-01-20'), (6, 'b@x.com', '2024-01-16');

CREATE TABLE emails_archive (LIKE emails);                -- same columns as emails, empty

WITH dupes AS (
    SELECT id
    FROM (SELECT id, ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_at DESC) AS rn
          FROM emails) AS t
    WHERE rn > 1                                          -- everything except the newest per email
),
moved AS (
    DELETE FROM emails
    WHERE id IN (SELECT id FROM dupes)
    RETURNING *                                           -- hand the deleted rows to the next step
)
INSERT INTO emails_archive SELECT * FROM moved;           -- INSERT 0 3

SELECT * FROM emails ORDER BY id;                         -- ids 4, 5, 6
SELECT * FROM emails_archive ORDER BY id;                 -- ids 1, 2, 3


-- ============================================================
-- 4. CREATE TABLE and constraints: designing tables
-- ============================================================

CREATE TABLE product_stock (
    product_id    INT PRIMARY KEY REFERENCES products(product_id) ON DELETE CASCADE,
    quantity      INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    last_updated  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE reviews (
    review_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  INT NOT NULL REFERENCES customers(customer_id),
    product_id   INT NOT NULL REFERENCES products(product_id),
    rating       INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment      TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (customer_id, product_id)            -- one review per customer per product
);

INSERT INTO reviews (customer_id, product_id, rating, comment) VALUES (1, 1, 5, 'Great laptop');     -- works

-- ERROR DEMO: INSERT INTO reviews (customer_id, product_id, rating, comment) VALUES (1, 1, 4, 'Second thoughts');
-- ERROR: duplicate key value violates unique constraint "reviews_customer_id_product_id_key"
-- ERROR DEMO: INSERT INTO reviews (customer_id, product_id, rating, comment) VALUES (2, 1, 6, 'Too good');
-- ERROR: new row for relation "reviews" violates check constraint "reviews_rating_check"
-- ERROR DEMO: INSERT INTO reviews (customer_id, product_id, rating, comment) VALUES (999, 1, 3, 'Ghost');
-- ERROR: insert or update on table "reviews" violates foreign key constraint "reviews_customer_id_fkey"
-- ERROR DEMO: INSERT INTO reviews (customer_id, product_id, comment) VALUES (2, 1, 'No rating');
-- ERROR: null value in column "rating" of relation "reviews" violates not-null constraint
-- ERROR DEMO: INSERT INTO reviews (review_id, customer_id, product_id, rating) VALUES (50, 2, 1, 3);
-- ERROR: cannot insert a non-DEFAULT value into column "review_id"

INSERT INTO reviews (customer_id, product_id, rating) VALUES (2, 1, 4)
RETURNING review_id, created_at IS NOT NULL AS has_timestamp;

ALTER TABLE reviews ADD COLUMN helpful_votes INT NOT NULL DEFAULT 0;             -- add a column
ALTER TABLE reviews RENAME COLUMN comment TO review_text;                        -- rename a column
ALTER TABLE reviews ADD CONSTRAINT helpful_nonneg CHECK (helpful_votes >= 0);    -- add a rule
ALTER TABLE reviews ALTER COLUMN rating TYPE SMALLINT;                           -- change a type
ALTER TABLE reviews DROP COLUMN helpful_votes;                                   -- remove a column (and its constraint)

-- ERROR DEMO: UPDATE reviews SET helpful_votes = -1 WHERE review_id = 1;
-- ERROR: new row for relation "reviews" violates check constraint "helpful_nonneg"

INSERT INTO products (name, category, price) VALUES ('Test Gadget', 'Electronics', 999);

INSERT INTO product_stock (product_id, quantity)
SELECT product_id, 5 FROM products WHERE name = 'Test Gadget';       -- stock row for the gadget

DELETE FROM products WHERE name = 'Test Gadget';                     -- DELETE 1 ... and its stock row goes too
SELECT COUNT(*) FROM product_stock;                                  -- 0

-- ERROR DEMO: DELETE FROM products WHERE name = 'Laptop';
-- ERROR: update or delete on table "products" violates foreign key constraint "order_items_product_id_fkey" on table "order_items"

CREATE TABLE electronics_copy AS
SELECT * FROM products WHERE category = 'Electronics';

SELECT COUNT(*) FROM electronics_copy;                    -- 3

DROP TABLE electronics_copy;
DROP TABLE IF EXISTS electronics_copy;                    -- no error if it's already gone


-- ============================================================
-- 5. UPSERT: insert or update
-- ============================================================

INSERT INTO product_stock (product_id, quantity) VALUES (1, 10), (2, 25);         -- INSERT 0 2

INSERT INTO product_stock (product_id, quantity) VALUES (1, 99)
ON CONFLICT (product_id) DO NOTHING;                                              -- INSERT 0 0 (skipped)

INSERT INTO product_stock (product_id, quantity)
VALUES (1, 5), (3, 40)
ON CONFLICT (product_id)
DO UPDATE SET quantity     = product_stock.quantity + EXCLUDED.quantity,
              last_updated = NOW()
RETURNING product_id, quantity;

SELECT product_id, quantity FROM product_stock ORDER BY product_id;               -- 1: 15, 2: 25, 3: 40

INSERT INTO reviews (customer_id, product_id, rating, review_text)
VALUES (1, 1, 3, 'Changed my mind')
ON CONFLICT (customer_id, product_id)
DO UPDATE SET rating = EXCLUDED.rating, review_text = EXCLUDED.review_text
RETURNING review_id, rating, review_text;

-- ERROR DEMO: INSERT INTO product_stock (product_id, quantity) VALUES (1, 5) ON CONFLICT (quantity) DO NOTHING;
-- ERROR: there is no unique or exclusion constraint matching the ON CONFLICT specification
-- ERROR DEMO: INSERT INTO product_stock (product_id, quantity) VALUES (1, 5) ON CONFLICT DO UPDATE SET quantity = 0;
-- ERROR: ON CONFLICT DO UPDATE requires inference specification or constraint name


-- ============================================================
-- 6. Normalization: organizing data well
-- ============================================================

CREATE TABLE orders_flat (
    order_id       INT,
    customer_name  TEXT,
    customer_city  TEXT,
    product_name   TEXT,
    product_price  NUMERIC(10,2),
    quantity       INT
);

INSERT INTO orders_flat VALUES
    (1, 'Asha',   'Mumbai', 'Laptop',     55000, 1),
    (1, 'Asha',   'Mumbai', 'Headphones',  2500, 2),
    (2, 'Asha',   'Mumbai', 'Notebook',      60, 10),
    (3, 'Ben',    'Delhi',  'Phone',      30000, 1),
    (4, 'Chitra', 'Mumbai', 'Headphones',  2500, 1);

UPDATE orders_flat SET customer_city = 'Pune' WHERE order_id = 1 AND product_name = 'Laptop';

SELECT DISTINCT customer_name, customer_city FROM orders_flat ORDER BY 1, 2;


-- ============================================================
-- 7. Transactions and ACID
-- ============================================================

CREATE TABLE accounts (
    account_id  INT PRIMARY KEY,
    owner       TEXT NOT NULL,
    balance     NUMERIC(12,2) NOT NULL CHECK (balance >= 0)
);

INSERT INTO accounts VALUES (1, 'Asha', 1000), (2, 'Ben', 500);

BEGIN;
UPDATE accounts SET balance = balance - 200 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 200 WHERE account_id = 2;
COMMIT;

SELECT * FROM accounts ORDER BY account_id;

BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE account_id = 1;
SELECT balance FROM accounts WHERE account_id = 1;        -- 700.00 (visible inside YOUR transaction)
ROLLBACK;
SELECT balance FROM accounts WHERE account_id = 1;        -- 800.00 (undone)

BEGIN;
INSERT INTO accounts VALUES (3, 'Chitra', 100);
SAVEPOINT after_chitra;
INSERT INTO accounts VALUES (4, 'Dev', 200);
ROLLBACK TO SAVEPOINT after_chitra;                       -- undo only Dev
COMMIT;                                                   -- Chitra is saved

SELECT * FROM accounts ORDER BY account_id;               -- accounts 1, 2 and 3 (no Dev)

BEGIN;
CREATE TABLE temp_demo (x INT);
ROLLBACK;
SELECT to_regclass('temp_demo') AS exists_now;            -- NULL: the table never came to exist
