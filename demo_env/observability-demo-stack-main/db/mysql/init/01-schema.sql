-- ---------------------------------------------------------------------------
-- __DEMO_BRAND__  --  order management domain (MySQL)
-- ---------------------------------------------------------------------------
USE __DEMO_NAME___orders;

CREATE TABLE customers (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email        VARCHAR(160) NOT NULL,
  full_name    VARCHAR(120) NOT NULL,
  city         VARCHAR(60)  NOT NULL,
  loyalty_tier VARCHAR(16)  NOT NULL DEFAULT 'bronze',
  created_at   DATETIME     NOT NULL,
  UNIQUE KEY uk_customers_email (email)
) ENGINE=InnoDB;

-- NOTE: customer_email is deliberately left UNINDEXED. The "missing index"
-- demo scenario searches on this column and forces a full table scan.
CREATE TABLE orders (
  id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  customer_id    INT UNSIGNED   NOT NULL,
  customer_email VARCHAR(160)   NOT NULL,
  status         VARCHAR(20)    NOT NULL,
  channel        VARCHAR(20)    NOT NULL,
  total_amount   DECIMAL(10,2)  NOT NULL,
  payment_method VARCHAR(24)    NOT NULL,
  shipping_city  VARCHAR(60)    NOT NULL,
  placed_at      DATETIME       NOT NULL,
  KEY idx_orders_customer (customer_id),
  KEY idx_orders_placed_at (placed_at)
) ENGINE=InnoDB;

CREATE TABLE order_items (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id     BIGINT UNSIGNED NOT NULL,
  sku          VARCHAR(32)     NOT NULL,
  product_name VARCHAR(120)    NOT NULL,
  qty          INT             NOT NULL,
  unit_price   DECIMAL(10,2)   NOT NULL,
  KEY idx_order_items_order (order_id)
) ENGINE=InnoDB;

CREATE TABLE inventory (
  sku          VARCHAR(32) PRIMARY KEY,
  slot         INT          NOT NULL,
  product_name VARCHAR(120) NOT NULL,
  warehouse    VARCHAR(40)  NOT NULL,
  unit_price   DECIMAL(10,2) NOT NULL,
  on_hand      INT          NOT NULL,
  reserved     INT          NOT NULL DEFAULT 0,
  updated_at   DATETIME     NOT NULL,
  UNIQUE KEY uk_inventory_slot (slot)
) ENGINE=InnoDB;
