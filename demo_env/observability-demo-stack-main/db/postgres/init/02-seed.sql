INSERT INTO categories (name, slug) VALUES
 ('Skin Care','skin-care'), ('Hair Care','hair-care'), ('Wellness','wellness'),
 ('Baby Care','baby-care'), ('Nutrition','nutrition'), ('Pain Relief','pain-relief');

-- The 20 hero products mirror the MySQL inventory SKUs so traces line up.
INSERT INTO products (sku, name, category_id, price, rating, in_stock, description) VALUES
 ('WEL-SKN-0001','Herbal Purifying Face Wash 150ml',1, 190.00,4.4,TRUE,'Soap-free herbal formulation with botanical extracts.'),
 ('WEL-SKN-0002','Clarifying Clay Face Pack 100g',1, 175.00,4.3,TRUE,'Clarifying pack for acne-prone skin.'),
 ('WEL-SKN-0003','Aloe Hydrating Face Wash 150ml',1,165.00,4.2,TRUE,'Gentle daily cleanser with aloe vera and cucumber.'),
 ('WEL-SKN-0004','Almond & Rose Bathing Bar 125g',1,        70.00,4.5,TRUE,'Nourishing bathing bar with almond oil.'),
 ('WEL-SKN-0005','Herbal Neem Bathing Bar 125g',1,       65.00,4.4,TRUE,'Antibacterial bathing bar with neem.'),
 ('WEL-HAI-0001','Anti-Hair Fall Shampoo 400ml',2,  420.00,4.1,TRUE,'Strengthens hair from the root with bhringaraja.'),
 ('WEL-HAI-0002','Protein Repair Shampoo 400ml',2,385.00,4.2,TRUE,'Repairs damaged hair with chickpea and amla.'),
 ('WEL-HAI-0003','Anti-Dandruff Hair Oil 200ml',2,  310.00,4.0,TRUE,'Controls dandruff with tea tree oil and rosemary.'),
 ('WEL-SUP-0001','Liver Support Tablets (60)',3,        185.00,4.6,TRUE,'Hepatoprotective formulation for liver health.'),
 ('WEL-SUP-0002','Immunity Support Tablets (60)',3,         165.00,4.4,TRUE,'Supports the body natural immune response.'),
 ('WEL-SUP-0003','Ashwagandha Root Tablets (60)',3,      245.00,4.5,TRUE,'Adaptogen that helps the body manage stress.'),
 ('WEL-SUP-0004','Urinary Health Tablets (60)',3,          195.00,4.3,TRUE,'Supports urinary tract health.'),
 ('WEL-SUP-0005','Glucose Balance Tablets (60)',3,      275.00,4.2,TRUE,'Botanical support for healthy glucose metabolism.'),
 ('WEL-SUP-0006','Ginger Throat Lozenges (24)',3,       55.00,4.1,TRUE,'Soothes throat irritation and dry cough.'),
 ('WEL-BAB-0001','Gentle Baby Wash 400ml',4,   290.00,4.7,TRUE,'Tear-free wash with chickpea and green gram.'),
 ('WEL-BAB-0002','Baby Dusting Powder 400g',4,              255.00,4.6,TRUE,'Keeps baby skin dry with khus grass and zinc.'),
 ('WEL-BAB-0003','Baby Moisturising Lotion 400ml',4,             280.00,4.6,TRUE,'Light daily moisturiser with olive oil.'),
 ('WEL-BAB-0004','Infant Digestive Drops 30ml',4,           110.00,4.5,TRUE,'Gentle digestive support for infants.'),
 ('WEL-NUT-0001','Whey Protein Blend 1kg',5,  2450.00,4.3,TRUE,'Whey protein blend with botanical extracts.'),
 ('WEL-PAI-0001','Fast Relief Pain Balm 45g',6,           95.00,4.4,TRUE,'Fast relief from headache and body ache.');

-- Long tail: pack sizes and variants, to give the catalog realistic volume.
INSERT INTO products (sku, name, category_id, price, rating, in_stock, description)
SELECT 'WEL-VAR-' || lpad(n::text, 5, '0'),
       (ARRAY['Neem','Aloe Vera','Ashwagandha','Tulsi','Amla','Brahmi','Shatavari','Turmeric'])[1 + (n % 8)]
         || ' ' || (ARRAY['Face Wash','Capsules','Hair Oil','Body Lotion','Soap','Tablets','Serum','Powder'])[1 + (n % 8)]
         || ' - Pack of ' || (1 + (n % 4)),
       1 + (n % 6),
       round((49 + (n % 1900))::numeric, 2),
       round((3.2 + ((n % 18) / 10.0))::numeric, 1),
       (n % 17) <> 0,
       'Herbal formulation, variant ' || n || '.'
FROM generate_series(1, 4980) AS n;

-- ------------------------------------------------------------------ reviews
INSERT INTO reviews (product_id, customer_email, rating, title, body, created_at)
SELECT 1 + (n % 5000),
       'customer' || (1 + (n % 20000)) || '@demo.example',
       1 + (n % 5),
       (ARRAY['Works well','Good value','Will buy again','Average','Not for me','Excellent'])[1 + (n % 6)],
       'Used this for ' || (1 + (n % 12)) || ' weeks. ' ||
       (ARRAY['Noticed a clear difference.','Packaging could be better.','Delivery was quick.',
              'Smells great.','Mild on the skin.','Reordering this month.'])[1 + (n % 6)],
       now() - ((n % 500) || ' days')::interval
FROM generate_series(1, 400000) AS n;

-- ------------------------------------------------------------ product views
INSERT INTO product_views (product_id, session_id, channel, referrer, viewed_at)
SELECT 1 + (n % 5000),
       md5(n::text),
       (ARRAY['web','android','ios','marketplace'])[1 + (n % 4)],
       (ARRAY['google','instagram','direct','email','affiliate'])[1 + (n % 5)],
       now() - ((n % 129600) || ' minutes')::interval
FROM generate_series(1, 800000) AS n;

ANALYZE;
