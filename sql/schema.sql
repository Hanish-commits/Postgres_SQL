-- PostgreSQL Mastery: practice database
-- 1) CREATE DATABASE shop;   (run once, then connect to shop)
-- 2) Run this whole file. Safe to re-run: it resets the tables.

DROP TABLE IF EXISTS order_items, orders, products, customers, employees CASCADE;

-- Also remove any extra tables created in Chapter 6 so this script is a full reset
DROP TABLE IF EXISTS flat_order_items, flat_orders, flat_products, flat_customers, orders_flat,
                     wishlist, reviews, product_stock, electronics_copy, city_customers,
                     emails, emails_archive, accounts, temp_demo CASCADE;


CREATE TABLE customers (
    customer_id  SERIAL PRIMARY KEY,
    name         TEXT NOT NULL,
    city         TEXT,
    signup_date  DATE
);

CREATE TABLE products (
    product_id  SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    category    TEXT,
    price       NUMERIC(10,2)
);

CREATE TABLE orders (
    order_id     SERIAL PRIMARY KEY,
    customer_id  INT REFERENCES customers(customer_id),
    order_date   DATE,
    status       TEXT
);

CREATE TABLE order_items (
    order_item_id  SERIAL PRIMARY KEY,
    order_id       INT REFERENCES orders(order_id),
    product_id     INT REFERENCES products(product_id),
    quantity       INT
);

CREATE TABLE employees (
    employee_id  SERIAL PRIMARY KEY,
    name         TEXT NOT NULL,
    department   TEXT,
    salary       NUMERIC(10,2),
    manager_id   INT REFERENCES employees(employee_id),
    hire_date    DATE
);

INSERT INTO customers (name, city, signup_date) VALUES
('Asha',   'Mumbai',    '2024-01-15'),
('Ben',    'Delhi',     '2024-02-20'),
('Chitra', 'Mumbai',    '2024-03-05'),
('Dev',    NULL,        '2024-03-18'),
('Esha',   'Bengaluru', '2024-04-02'),
('Farhan', 'Delhi',     '2024-05-11');

INSERT INTO products (name, category, price) VALUES
('Laptop',     'Electronics', 55000.00),
('Phone',      'Electronics', 30000.00),
('Headphones', 'Electronics',  2500.00),
('Notebook',   'Stationery',     60.00),
('Pen',        'Stationery',     10.00),
('Desk Lamp',  'Home',         1200.00);

INSERT INTO orders (customer_id, order_date, status) VALUES
(1, '2024-05-01', 'delivered'),
(1, '2024-06-10', 'delivered'),
(2, '2024-06-12', 'cancelled'),
(3, '2024-06-15', 'delivered'),
(4, '2024-07-01', 'pending'),
(5, '2024-07-04', 'delivered'),
(3, '2024-07-20', 'delivered');

INSERT INTO order_items (order_id, product_id, quantity) VALUES
(1, 1, 1), (1, 3, 2),
(2, 4, 10), (2, 5, 20),
(3, 2, 1),
(4, 6, 2),
(5, 3, 1),
(6, 2, 1), (6, 3, 1),
(7, 1, 1), (7, 4, 5);

INSERT INTO employees (name, department, salary, manager_id, hire_date) VALUES
('Rohan',  'Management',  150000, NULL, '2018-01-10'),
('Meera',  'Engineering', 120000, 1,    '2019-03-15'),
('Karan',  'Engineering',  90000, 2,    '2020-07-01'),
('Sneha',  'Engineering',  90000, 2,    '2021-02-20'),
('Imran',  'Sales',        70000, 1,    '2020-11-05'),
('Priya',  'Sales',        65000, 5,    '2022-01-17'),
('Tanvi',  'HR',           60000, 1,    '2021-09-09');
