/**
 * __DEMO_BRAND__ -- backend-for-frontend.
 *
 * Fans out to the orders service (Java/MySQL) and the catalog service
 * (Python/PostgreSQL), and owns the chaos flags that every service reads.
 */
const express = require('express');
const Redis = require('ioredis');

const PORT = parseInt(process.env.PORT || '3000', 10);
const ORDERS_URL = process.env.ORDERS_URL || 'http://localhost:8081';
const CATALOG_URL = process.env.CATALOG_URL || 'http://localhost:8082';

const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379', 10),
  lazyConnect: false,
  maxRetriesPerRequest: 2,
});
redis.on('error', (err) => console.error('[redis]', err.message));

const app = express();
app.use(express.json());

const FLAGS = [
  'slow_query',
  'n_plus_one',
  'pool_exhaustion',
  'lock_contention',
  'frontend_errors',
];

// ---------------------------------------------------------------- helpers
async function flag(name) {
  try {
    return (await redis.get(`chaos:${name}`)) === '1';
  } catch (err) {
    console.warn(`[chaos] lookup failed for ${name}: ${err.message}`);
    return false;
  }
}

async function intFlag(name, fallback) {
  try {
    const value = await redis.get(`chaos:${name}`);
    return value ? parseInt(value, 10) : fallback;
  } catch {
    return fallback;
  }
}

async function call(base, path, options = {}) {
  const started = Date.now();
  const res = await fetch(`${base}${path}`, {
    headers: { 'content-type': 'application/json' },
    ...options,
  });
  const tookMs = Date.now() - started;
  if (!res.ok) {
    const body = await res.text();
    const err = new Error(`upstream ${base}${path} returned ${res.status}: ${body.slice(0, 300)}`);
    err.status = res.status;
    throw err;
  }
  if (tookMs > 1000) console.warn(`[upstream] ${base}${path} took ${tookMs}ms`);
  return res.json();
}

const orders = (path, options) => call(ORDERS_URL, path, options);
const catalog = (path, options) => call(CATALOG_URL, path, options);

// Injected latency and error rate, applied to every storefront request.
app.use('/api', async (req, res, next) => {
  if (req.path.startsWith('/chaos') || req.path === '/health') return next();

  const latencyMs = await intFlag('latency_ms', 0);
  if (latencyMs > 0) await new Promise((r) => setTimeout(r, latencyMs));

  const errorRate = await intFlag('error_rate', 0);
  if (errorRate > 0 && Math.random() * 100 < errorRate) {
    console.error(`[chaos] injected 503 on ${req.method} ${req.path}`);
    return res.status(503).json({
      error: 'Upstream service unavailable',
      hint: 'injected by the demo control panel',
      path: req.path,
    });
  }
  return next();
});

// ------------------------------------------------------------------ routes
app.get('/api/health', async (_req, res) => {
  const [ordersHealth, catalogHealth] = await Promise.allSettled([
    orders('/api/health'),
    catalog('/health'),
  ]);
  res.json({
    status: 'ok',
    service: '__DEMO_NAME__-bff',
    upstreams: {
      orders: ordersHealth.status === 'fulfilled' ? 'up' : 'down',
      catalog: catalogHealth.status === 'fulfilled' ? 'up' : 'down',
    },
  });
});

app.get('/api/home', async (_req, res, next) => {
  try {
    const [products, trending, recent] = await Promise.all([
      catalog('/api/products?limit=12'),
      catalog('/api/analytics/trending'),
      orders('/api/orders/recent?limit=8'),
    ]);
    res.json({
      products: products.products,
      trending: trending.products,
      trendingTookMs: trending.took_ms,
      recentOrders: recent.orders,
      recentMode: recent.mode,
    });
  } catch (err) {
    next(err);
  }
});

app.get('/api/products', async (req, res, next) => {
  try {
    const limit = parseInt(req.query.limit || '24', 10);
    const category = req.query.category ? `&category=${encodeURIComponent(req.query.category)}` : '';
    res.json(await catalog(`/api/products?limit=${limit}${category}`));
  } catch (err) { next(err); }
});

app.get('/api/products/:id', async (req, res, next) => {
  try {
    res.json(await catalog(`/api/products/${encodeURIComponent(req.params.id)}`));
  } catch (err) { next(err); }
});

app.get('/api/search', async (req, res, next) => {
  try {
    const q = encodeURIComponent(req.query.q || 'neem');
    res.json(await catalog(`/api/search?q=${q}`));
  } catch (err) { next(err); }
});

app.get('/api/analytics/trending', async (_req, res, next) => {
  try { res.json(await catalog('/api/analytics/trending')); } catch (err) { next(err); }
});

app.get('/api/analytics/top-products', async (_req, res, next) => {
  try { res.json(await orders('/api/analytics/top-products')); } catch (err) { next(err); }
});

app.get('/api/orders/recent', async (req, res, next) => {
  try {
    const limit = parseInt(req.query.limit || '20', 10);
    res.json(await orders(`/api/orders/recent?limit=${limit}`));
  } catch (err) { next(err); }
});

app.get('/api/orders/search', async (req, res, next) => {
  try {
    const email = encodeURIComponent(req.query.email || 'customer1@demo.example');
    res.json(await orders(`/api/orders/search?email=${email}`));
  } catch (err) { next(err); }
});

app.get('/api/orders/:id', async (req, res, next) => {
  try { res.json(await orders(`/api/orders/${encodeURIComponent(req.params.id)}`)); }
  catch (err) { next(err); }
});

app.get('/api/inventory', async (_req, res, next) => {
  try { res.json(await orders('/api/inventory')); } catch (err) { next(err); }
});

app.post('/api/checkout', async (req, res, next) => {
  try {
    const payload = {
      sku: req.body.sku || 'WEL-SKN-0001',
      qty: req.body.qty || 1,
      email: req.body.email || 'customer1@demo.example',
    };
    const result = await orders('/api/checkout', {
      method: 'POST',
      body: JSON.stringify(payload),
    });

    // When the pool-exhaustion scenario is active, also squeeze the catalog
    // service's PostgreSQL pool so the whole storefront degrades, not just orders.
    if (await flag('pool_exhaustion')) {
      catalog('/api/admin/hold-connection', { method: 'POST' }).catch(() => {});
    }
    if (await flag('lock_contention')) {
      catalog('/api/admin/long-transaction', { method: 'POST' }).catch(() => {});
    }

    res.json(result);
  } catch (err) { next(err); }
});

// ------------------------------------------------------------- chaos panel
app.get('/api/chaos', async (_req, res) => {
  const state = {};
  for (const name of FLAGS) state[name] = await flag(name);
  state.latency_ms = await intFlag('latency_ms', 0);
  state.error_rate = await intFlag('error_rate', 0);
  state.hold_seconds = await intFlag('hold_seconds', 4);
  res.json(state);
});

app.post('/api/chaos', async (req, res) => {
  const applied = {};
  for (const [key, value] of Object.entries(req.body || {})) {
    if (FLAGS.includes(key)) {
      await redis.set(`chaos:${key}`, value ? '1' : '0');
      applied[key] = !!value;
    } else if (['latency_ms', 'error_rate', 'hold_seconds'].includes(key)) {
      await redis.set(`chaos:${key}`, String(parseInt(value, 10) || 0));
      applied[key] = parseInt(value, 10) || 0;
    }
  }
  console.warn('[chaos] scenario changed:', JSON.stringify(applied));
  res.json({ applied });
});

app.post('/api/chaos/reset', async (_req, res) => {
  for (const name of FLAGS) await redis.set(`chaos:${name}`, '0');
  await redis.set('chaos:latency_ms', '0');
  await redis.set('chaos:error_rate', '0');
  await redis.set('chaos:hold_seconds', '4');
  console.warn('[chaos] all scenarios reset to healthy');
  res.json({ status: 'reset' });
});

app.post('/api/admin/index/:target/:action', async (req, res, next) => {
  try {
    const { target, action } = req.params;
    if (target === 'orders') {
      res.json(await orders(`/api/admin/index/${action}`, { method: 'POST' }));
    } else {
      res.json(await catalog(`/api/admin/index/${action}`, { method: 'POST' }));
    }
  } catch (err) { next(err); }
});

app.get('/api/admin/pool', async (_req, res, next) => {
  try { res.json(await orders('/api/admin/pool')); } catch (err) { next(err); }
});

// ------------------------------------------------------------ error handler
app.use((err, req, res, _next) => {
  console.error(`[error] ${req.method} ${req.originalUrl}: ${err.message}`);
  res.status(err.status && err.status >= 400 ? err.status : 502).json({
    error: err.message,
    path: req.originalUrl,
  });
});

app.listen(PORT, () => {
  console.log(`__DEMO_NAME__-bff listening on :${PORT} -> orders=${ORDERS_URL} catalog=${CATALOG_URL}`);
});
