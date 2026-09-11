"""
__DEMO_BRAND__ -- product catalog service (FastAPI + PostgreSQL).

Failure scenarios are driven by flags in Redis so they can be toggled live
from the operator control panel during a demo.
"""
import logging
import os
import time
from contextlib import contextmanager

import psycopg2
import psycopg2.extras
import redis
from fastapi import FastAPI, HTTPException
from psycopg2.pool import ThreadedConnectionPool

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [dd.trace_id=%(dd.trace_id)s dd.span_id=%(dd.span_id)s] %(name)s - %(message)s",
)
log = logging.getLogger("__DEMO_NAME__-catalog")

POOL_MAX = int(os.getenv("DB_POOL_MAX", "10"))

pool = ThreadedConnectionPool(
    minconn=2,
    maxconn=POOL_MAX,
    host=os.getenv("PGHOST", "localhost"),
    port=int(os.getenv("PGPORT", "5432")),
    dbname=os.getenv("PGDATABASE", "__DEMO_NAME___catalog"),
    user=os.getenv("PGUSER", "__DEMO_NAME__"),
    password=os.getenv("PGPASSWORD", "__DEMO_NAME___app_pw"),
)

rds = redis.Redis(
    host=os.getenv("REDIS_HOST", "localhost"),
    port=int(os.getenv("REDIS_PORT", "6379")),
    decode_responses=True,
    socket_timeout=2,
)

app = FastAPI(title="__DEMO_BRAND__ Catalog Service", version="1.4.0")


def flag(name: str) -> bool:
    try:
        return rds.get(f"chaos:{name}") == "1"
    except Exception as exc:  # Redis being down must not break the catalog
        log.warning("chaos flag lookup failed for %s: %s", name, exc)
        return False


def int_flag(name: str, fallback: int) -> int:
    try:
        value = rds.get(f"chaos:{name}")
        return int(value) if value else fallback
    except Exception:
        return fallback


@contextmanager
def db():
    conn = pool.getconn()
    try:
        conn.autocommit = True
        yield conn
    finally:
        pool.putconn(conn)


def query(sql: str, params=None):
    with db() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params or ())
            if cur.description is None:      # DDL / no result set
                return []
            return [dict(row) for row in cur.fetchall()]


def burn_database_work(cur, seconds: int) -> int:
    """
    Run genuinely expensive aggregates until the requested time has elapsed,
    holding whatever locks and connections the caller owns.

    Each iteration range-scans a 200k-row slice of product_views and hashes every
    session id, so Database Monitoring records a real statement with a real plan
    and real rows examined -- not an obviously synthetic pg_sleep.
    """
    deadline = time.time() + seconds
    batches = 0
    while time.time() < deadline:
        lo = 1 + ((batches * 200_000) % 800_000)
        cur.execute(
            """
            SELECT count(*) AS views,
                   count(DISTINCT session_id) AS sessions,
                   max(viewed_at) AS latest
            FROM product_views
            WHERE id BETWEEN %s AND %s
              AND md5(session_id || channel) LIKE %s
            """,
            (lo, lo + 200_000, "%ab%"),
        )
        cur.fetchall()
        batches += 1
    return batches


@app.get("/health")
def health():
    query("SELECT 1")
    return {"status": "ok", "service": "__DEMO_NAME__-catalog"}


@app.get("/api/products")
def list_products(category: int | None = None, limit: int = 24):
    limit = min(limit, 100)
    if category:
        rows = query(
            """
            SELECT p.id, p.sku, p.name, p.price, p.rating, p.in_stock, c.name AS category
            FROM products p JOIN categories c ON c.id = p.category_id
            WHERE p.category_id = %s
            ORDER BY p.rating DESC, p.id
            LIMIT %s
            """,
            (category, limit),
        )
    else:
        rows = query(
            """
            SELECT p.id, p.sku, p.name, p.price, p.rating, p.in_stock, c.name AS category
            FROM products p JOIN categories c ON c.id = p.category_id
            ORDER BY p.id
            LIMIT %s
            """,
            (limit,),
        )
    return {"count": len(rows), "products": rows}


@app.get("/api/products/{product_id}")
def product_detail(product_id: int):
    rows = query(
        """
        SELECT p.id, p.sku, p.name, p.price, p.rating, p.in_stock, p.description,
               c.name AS category
        FROM products p JOIN categories c ON c.id = p.category_id
        WHERE p.id = %s
        """,
        (product_id,),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="product not found")
    product = rows[0]

    product["reviews"] = query(
        """
        SELECT rating, title, body, created_at
        FROM reviews WHERE product_id = %s
        ORDER BY created_at DESC LIMIT 5
        """,
        (product_id,),
    )

    # product_views has no index on product_id, so this is a sequential scan
    # over 800k rows on every product page view -- until you add the index
    # from the control panel and watch the same query drop to single digits.
    started = time.time()
    views = query(
        """
        SELECT count(*) AS views, count(DISTINCT session_id) AS sessions
        FROM product_views
        WHERE product_id = %s AND viewed_at > now() - interval '30 days'
        """,
        (product_id,),
    )
    took_ms = int((time.time() - started) * 1000)
    if took_ms > 150:
        log.warning("Product view rollup for %s took %sms", product_id, took_ms)

    product["view_stats"] = views[0] if views else {}
    product["view_stats_took_ms"] = took_ms
    return product


@app.get("/api/search")
def search(q: str = "neem", limit: int = 20):
    limit = min(limit, 50)
    products = query(
        """
        SELECT id, sku, name, price, rating
        FROM products
        WHERE name ILIKE %s
        ORDER BY rating DESC
        LIMIT %s
        """,
        (f"%{q}%", limit),
    )

    if flag("n_plus_one"):
        # One review-aggregate round trip per search result.
        for product in products:
            agg = query(
                """
                SELECT count(*) AS review_count, coalesce(avg(rating), 0) AS avg_rating
                FROM reviews WHERE product_id = %s
                """,
                (product["id"],),
            )
            product["review_count"] = agg[0]["review_count"]
            product["avg_rating"] = float(agg[0]["avg_rating"])
        mode = "n_plus_one"
    else:
        if products:
            ids = tuple(p["id"] for p in products)
            aggs = query(
                """
                SELECT product_id, count(*) AS review_count, avg(rating) AS avg_rating
                FROM reviews WHERE product_id IN %s
                GROUP BY product_id
                """,
                (ids,),
            )
            by_id = {a["product_id"]: a for a in aggs}
            for product in products:
                agg = by_id.get(product["id"], {})
                product["review_count"] = agg.get("review_count", 0)
                product["avg_rating"] = float(agg.get("avg_rating") or 0)
        mode = "batched"

    return {"mode": mode, "query": q, "count": len(products), "products": products}


@app.get("/api/analytics/trending")
def trending():
    """Heavy aggregate over the 800k-row product_views table."""
    started = time.time()
    if flag("slow_query"):
        sql = """
            SELECT p.id, p.name, count(*) AS views, count(DISTINCT v.session_id) AS sessions
            FROM product_views v JOIN products p ON p.id = v.product_id
            WHERE v.viewed_at::date >= (now() - interval '30 days')::date
            GROUP BY p.id, p.name
            ORDER BY views DESC
            LIMIT 10
        """
    else:
        sql = """
            SELECT p.id, p.name, count(*) AS views, count(DISTINCT v.session_id) AS sessions
            FROM product_views v JOIN products p ON p.id = v.product_id
            WHERE v.viewed_at >= now() - interval '2 days'
            GROUP BY p.id, p.name
            ORDER BY views DESC
            LIMIT 10
        """
    rows = query(sql)
    took_ms = int((time.time() - started) * 1000)
    if took_ms > 1000:
        log.warning("Trending aggregation took %sms", took_ms)
    return {"took_ms": took_ms, "products": rows}


@app.post("/api/admin/hold-connection")
def hold_connection():
    """Pool-exhaustion scenario: hold a pooled connection doing real work."""
    seconds = int_flag("hold_seconds", 4)
    with db() as conn:
        with conn.cursor() as cur:
            batches = burn_database_work(cur, seconds)
    log.warning("Held a pooled connection for %ss across %s analytical batches", seconds, batches)
    return {"held_seconds": seconds, "batches": batches, "pool_max": POOL_MAX}


@app.post("/api/admin/long-transaction")
def long_transaction():
    """Lock-contention scenario: idle-in-transaction holding a row lock."""
    seconds = int_flag("hold_seconds", 4)
    conn = pool.getconn()
    broken = False
    try:
        conn.autocommit = False
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM products WHERE id = 1 FOR UPDATE")
            cur.execute("UPDATE products SET rating = rating WHERE id = 1")
            # Hold the row lock with real work rather than a sleep, so the
            # blocking session in Query Activity shows a legitimate statement.
            batches = burn_database_work(cur, seconds)
        conn.commit()
        log.warning("Held a row lock for %ss across %s analytical batches", seconds, batches)
    except Exception:
        broken = True
        raise
    finally:
        # Never hand a connection with an open transaction back to the pool.
        try:
            conn.rollback()
            conn.autocommit = True
        except Exception:
            broken = True
        pool.putconn(conn, close=broken)
    return {"held_seconds": seconds, "locked_row": 1}


@app.post("/api/admin/index/{action}")
def toggle_index(action: str):
    """Live remediation for the missing index DBM surfaces."""
    try:
        # Two indexes: one for the per-product rollup on the product page, one
        # for the time-window filter behind the trending aggregate.
        if action == "create":
            query("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_product_views_product "
                  "ON product_views (product_id, viewed_at)")
            query("CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_product_views_viewed_at "
                  "ON product_views (viewed_at)")
            return {"status": "created",
                    "indexes": ["idx_product_views_product", "idx_product_views_viewed_at"]}
        if action == "drop":
            query("DROP INDEX CONCURRENTLY IF EXISTS idx_product_views_product")
            query("DROP INDEX CONCURRENTLY IF EXISTS idx_product_views_viewed_at")
            return {"status": "dropped",
                    "indexes": ["idx_product_views_product", "idx_product_views_viewed_at"]}
        raise HTTPException(status_code=400, detail="action must be 'create' or 'drop'")
    except psycopg2.Error as exc:
        raise HTTPException(status_code=500, detail=str(exc))
