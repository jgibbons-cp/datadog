-- ---------------------------------------------------------------------------
-- __DEMO_BRAND__  --  product catalog domain (PostgreSQL)
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

CREATE TABLE categories (
  id     SERIAL PRIMARY KEY,
  name   TEXT NOT NULL,
  slug   TEXT NOT NULL UNIQUE
);

CREATE TABLE products (
  id          SERIAL PRIMARY KEY,
  sku         TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  category_id INT  NOT NULL REFERENCES categories(id),
  price       NUMERIC(10,2) NOT NULL,
  rating      NUMERIC(2,1)  NOT NULL DEFAULT 4.0,
  in_stock    BOOLEAN       NOT NULL DEFAULT TRUE,
  description TEXT          NOT NULL,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX idx_products_category ON products(category_id);

CREATE TABLE reviews (
  id             BIGSERIAL PRIMARY KEY,
  product_id     INT  NOT NULL,
  customer_email TEXT NOT NULL,
  rating         INT  NOT NULL,
  title          TEXT NOT NULL,
  body           TEXT NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_reviews_product ON reviews(product_id);

-- NOTE: product_views has NO index on product_id or viewed_at, on purpose.
-- The "slow query" scenario reads from this table and produces a seq scan.
CREATE TABLE product_views (
  id         BIGSERIAL PRIMARY KEY,
  product_id INT  NOT NULL,
  session_id TEXT NOT NULL,
  channel    TEXT NOT NULL,
  referrer   TEXT NOT NULL,
  viewed_at  TIMESTAMPTZ NOT NULL
);
