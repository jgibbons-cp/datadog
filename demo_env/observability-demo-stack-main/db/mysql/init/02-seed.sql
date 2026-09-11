USE __DEMO_NAME___orders;
SET SESSION cte_max_recursion_depth = 1000000;

-- ------------------------------------------------------------- product master
INSERT INTO inventory (sku, slot, product_name, warehouse, unit_price, on_hand, reserved, updated_at) VALUES
 ('WEL-SKN-0001', 0,'Herbal Purifying Face Wash 150ml',       'Bengaluru-DC', 190.00, 50400, 0, NOW()),
 ('WEL-SKN-0002', 1,'Clarifying Clay Face Pack 100g',        'Bengaluru-DC', 175.00, 37200, 0, NOW()),
 ('WEL-SKN-0003', 2,'Aloe Hydrating Face Wash 150ml',     'Bengaluru-DC', 165.00, 33000, 0, NOW()),
 ('WEL-SKN-0004', 3,'Almond & Rose Bathing Bar 125g',              'Nashik-DC',     70.00, 105600, 0, NOW()),
 ('WEL-SKN-0005', 4,'Herbal Neem Bathing Bar 125g',             'Nashik-DC',     65.00, 112800, 0, NOW()),
 ('WEL-HAI-0001', 5,'Anti-Hair Fall Shampoo 400ml',         'Bengaluru-DC', 420.00, 22800, 0, NOW()),
 ('WEL-HAI-0002', 6,'Protein Repair Shampoo 400ml',      'Bengaluru-DC', 385.00, 19800, 0, NOW()),
 ('WEL-HAI-0003', 7,'Anti-Dandruff Hair Oil 200ml',         'Dehradun-DC',  310.00, 16800, 0, NOW()),
 ('WEL-SUP-0001', 8,'Liver Support Tablets (60)',               'Dehradun-DC',  185.00,  7440, 0, NOW()),
 ('WEL-SUP-0002', 9,'Immunity Support Tablets (60)',                'Dehradun-DC',  165.00,  6960, 0, NOW()),
 ('WEL-SUP-0003',10,'Ashwagandha Root Tablets (60)',             'Dehradun-DC',  245.00,  8880, 0, NOW()),
 ('WEL-SUP-0004',11,'Urinary Health Tablets (60)',                 'Dehradun-DC',  195.00,  6120, 0, NOW()),
 ('WEL-SUP-0005',12,'Glucose Balance Tablets (60)',             'Dehradun-DC',  275.00,  5160, 0, NOW()),
 ('WEL-SUP-0006',13,'Ginger Throat Lozenges (24)',             'Nashik-DC',     55.00, 39600, 0, NOW()),
 ('WEL-BAB-0001',14,'Gentle Baby Wash 400ml',          'Nashik-DC',    290.00, 25200, 0, NOW()),
 ('WEL-BAB-0002',15,'Baby Dusting Powder 400g',                     'Nashik-DC',    255.00, 29400, 0, NOW()),
 ('WEL-BAB-0003',16,'Baby Moisturising Lotion 400ml',                    'Nashik-DC',    280.00, 23760, 0, NOW()),
 ('WEL-BAB-0004',17,'Infant Digestive Drops 30ml',                  'Dehradun-DC',  110.00,  10680, 0, NOW()),
 ('WEL-NUT-0001',18,'Whey Protein Blend 1kg',          'Bengaluru-DC',2450.00,  3120, 0, NOW()),
 ('WEL-PAI-0001',19,'Fast Relief Pain Balm 45g',                 'Nashik-DC',     95.00, 61200, 0, NOW());

-- ---------------------------------------------------------------- customers
INSERT INTO customers (email, full_name, city, loyalty_tier, created_at)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 20000)
SELECT CONCAT('customer', n, '@demo.example'),
       CONCAT('Customer ', n),
       ELT(1 + (n % 8), 'Bengaluru','Mumbai','New Delhi','Chennai','Hyderabad','Pune','Kolkata','Ahmedabad'),
       ELT(1 + (n % 3), 'bronze','silver','gold'),
       NOW() - INTERVAL (n % 900) DAY
FROM seq;

-- ------------------------------------------------------------------- orders
INSERT INTO orders (customer_id, customer_email, status, channel, total_amount, payment_method, shipping_city, placed_at)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 400000)
SELECT c.id,
       c.email,
       ELT(1 + (n % 6), 'DELIVERED','DELIVERED','SHIPPED','PACKED','PLACED','CANCELLED'),
       ELT(1 + (n % 4), 'web','android','ios','marketplace'),
       ROUND(180 + (n % 2600) + ((n % 97) / 3), 2),
       ELT(1 + (n % 5), 'UPI','CARD','NETBANKING','COD','WALLET'),
       c.city,
       NOW() - INTERVAL (n % 129600) MINUTE
FROM seq
JOIN customers c ON c.id = 1 + (n % 20000);

-- -------------------------------------------------------------- order items
-- Split into four statements rather than one 1.3M-row insert, to keep each
-- transaction (and its undo log) small enough for a laptop.
INSERT INTO order_items (order_id, sku, product_name, qty, unit_price)
SELECT o.id, i.sku, i.product_name, 1 + ((o.id + 1) % 3), i.unit_price
FROM orders o JOIN inventory i ON i.slot = ((o.id * 7 + 13) % 20)
WHERE ((o.id + 1) % 5) <> 0;

INSERT INTO order_items (order_id, sku, product_name, qty, unit_price)
SELECT o.id, i.sku, i.product_name, 1 + ((o.id + 2) % 3), i.unit_price
FROM orders o JOIN inventory i ON i.slot = ((o.id * 7 + 26) % 20)
WHERE ((o.id + 2) % 5) <> 0;

INSERT INTO order_items (order_id, sku, product_name, qty, unit_price)
SELECT o.id, i.sku, i.product_name, 1 + ((o.id + 3) % 3), i.unit_price
FROM orders o JOIN inventory i ON i.slot = ((o.id * 7 + 39) % 20)
WHERE ((o.id + 3) % 5) <> 0;

INSERT INTO order_items (order_id, sku, product_name, qty, unit_price)
SELECT o.id, i.sku, i.product_name, 1 + ((o.id + 4) % 3), i.unit_price
FROM orders o JOIN inventory i ON i.slot = ((o.id * 7 + 52) % 20)
WHERE ((o.id + 4) % 5) <> 0;

ANALYZE TABLE customers, orders, order_items, inventory;
