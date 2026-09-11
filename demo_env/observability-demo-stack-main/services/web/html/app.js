/* __DEMO_BRAND__ storefront -- talks to the BFF through the nginx /api proxy. */

const $ = (sel) => document.querySelector(sel);
const fmtINR = (v) => '₹' + Number(v).toLocaleString('en-IN', { maximumFractionDigits: 0 });

function toast(message, isError) {
  const el = document.createElement('div');
  el.className = 'toast' + (isError ? ' error' : '');
  el.textContent = message;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 4200);
}

function showTiming(selector, ms, threshold) {
  const el = $(selector);
  if (!el) return;
  el.textContent = ms + ' ms';
  el.className = 'timing' + (ms > (threshold || 800) ? ' slow' : '');
}

async function api(path, options) {
  const started = performance.now();
  const res = await fetch(path, options);
  const took = Math.round(performance.now() - started);
  if (!res.ok) {
    let detail = res.statusText;
    try { detail = (await res.json()).error || detail; } catch (_) {}
    const err = new Error(detail);
    err.took = took;
    err.status = res.status;
    // Surface the failure to RUM as a handled error with useful context.
    if (window.DD_RUM) {
      window.DD_RUM.addError(err, { path, status: res.status, duration_ms: took });
    }
    throw err;
  }
  const data = await res.json();
  return { data, took };
}

// ------------------------------------------------------------------- shop
async function loadProducts(query) {
  try {
    const path = query ? `/api/search?q=${encodeURIComponent(query)}` : '/api/products?limit=16';
    const { data, took } = await api(path);
    showTiming('#products-timing', took, 600);
    renderProducts(data.products || []);
  } catch (err) {
    toast('Could not load products: ' + err.message, true);
  }
}

function renderProducts(products) {
  const grid = $('#product-grid');
  grid.innerHTML = '';
  products.forEach((p) => {
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `
      <div class="cat">${p.category || 'Ayurveda'}</div>
      <div class="name">${p.name}</div>
      <div class="price">${fmtINR(p.price)}</div>
      <div class="rating">${'★'.repeat(Math.round(p.rating || 4))} ${p.rating || ''}</div>
      <button class="buy" data-sku="${p.sku}">Add to cart</button>`;
    card.querySelector('.buy').addEventListener('click', (ev) => {
      ev.stopPropagation();
      checkout(p.sku, ev.target);
    });
    card.addEventListener('click', () => openProduct(p.id));
    grid.appendChild(card);
  });
}

async function openProduct(id) {
  try {
    const { data, took } = await api(`/api/products/${id}`);
    const stats = data.view_stats || {};
    toast(`${data.name} — ${stats.views || 0} views / ${stats.sessions || 0} sessions ` +
          `(page load ${took} ms, view rollup ${data.view_stats_took_ms} ms)`);
  } catch (err) {
    toast('Product page failed: ' + err.message, true);
  }
}

async function checkout(sku, button) {
  button.disabled = true;
  button.textContent = 'Placing order…';
  try {
    const { data, took } = await api('/api/checkout', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ sku, qty: 1, email: 'customer1@demo.example' }),
    });
    if (window.DD_RUM) {
      window.DD_RUM.addAction('checkout_completed', {
        sku, order_id: data.order_id, duration_ms: took,
      });
    }
    toast(`Order #${data.order_id} placed in ${took} ms`);
  } catch (err) {
    toast(`Checkout failed after ${err.took} ms: ${err.message}`, true);
  } finally {
    button.disabled = false;
    button.textContent = 'Add to cart';
  }
}

async function loadTrending() {
  try {
    const { data, took } = await api('/api/analytics/trending');
    showTiming('#trending-timing', took, 900);
    const tbody = $('#trending-table tbody');
    tbody.innerHTML = (data.products || [])
      .map((p) => `<tr><td>${p.name}</td><td>${p.views}</td><td>${p.sessions}</td></tr>`)
      .join('');
  } catch (err) {
    toast('Trending failed: ' + err.message, true);
  }
}

// ----------------------------------------------------------------- orders
async function searchOrders() {
  const email = $('#order-email').value.trim();
  try {
    const { data, took } = await api(`/api/orders/search?email=${encodeURIComponent(email)}`);
    showTiming('#order-search-timing', took, 500);
    $('#order-search-timing').textContent += ` · ${data.mode}`;
    $('#orders-table tbody').innerHTML = (data.orders || [])
      .map((o) => `<tr>
        <td>#${o.id}</td><td>${o.customer_email}</td><td>${o.status}</td>
        <td>${o.channel || ''}</td><td>${fmtINR(o.total_amount)}</td>
        <td>${new Date(o.placed_at).toLocaleString()}</td></tr>`)
      .join('');
  } catch (err) {
    toast('Order search failed: ' + err.message, true);
  }
}

async function loadRecent() {
  try {
    const { data, took } = await api('/api/orders/recent?limit=15');
    showTiming('#recent-timing', took, 800);
    $('#recent-timing').textContent += ` · ${data.mode}`;
    $('#recent-table tbody').innerHTML = (data.orders || [])
      .map((o) => `<tr>
        <td>#${o.id}</td><td>${o.status}</td><td>${(o.items || []).length}</td>
        <td>${fmtINR(o.total_amount)}</td><td>${o.shipping_city || ''}</td></tr>`)
      .join('');
  } catch (err) {
    toast('Recent orders failed: ' + err.message, true);
  }
}

// --------------------------------------------------------------- insights
async function loadInsights() {
  try {
    const { data, took } = await api('/api/analytics/top-products');
    showTiming('#top-timing', took, 1200);
    $('#top-timing').textContent += ` · ${data.mode}`;
    $('#top-table tbody').innerHTML = (data.products || [])
      .map((p) => `<tr>
        <td>${p.sku}</td><td>${p.product_name}</td><td>${p.units}</td>
        <td>${fmtINR(p.revenue)}</td><td>${p.buyers}</td></tr>`)
      .join('');
  } catch (err) {
    toast('Insights failed: ' + err.message, true);
  }

  try {
    const { data } = await api('/api/admin/pool');
    $('#pool-stats').textContent =
      `orders service (HikariCP)\n` +
      `  active  : ${data.active}\n` +
      `  idle    : ${data.idle}\n` +
      `  waiting : ${data.waiting}\n` +
      `  max     : ${data.max}`;
  } catch (err) {
    $('#pool-stats').textContent = 'pool stats unavailable: ' + err.message;
  }
}

// -------------------------------------------------------------------- tabs
document.querySelectorAll('nav button[data-tab]').forEach((btn) => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('nav button[data-tab]').forEach((b) => b.classList.remove('active'));
    btn.classList.add('active');
    const tab = btn.dataset.tab;
    ['shop', 'orders', 'insights'].forEach((name) => {
      document.getElementById('tab-' + name).classList.toggle('hidden', name !== tab);
    });
    if (window.DD_RUM) window.DD_RUM.startView({ name: tab });
    if (tab === 'orders') loadRecent();
    if (tab === 'insights') loadInsights();
  });
});

let searchTimer;
$('#search-box').addEventListener('input', (ev) => {
  clearTimeout(searchTimer);
  const q = ev.target.value.trim();
  searchTimer = setTimeout(() => loadProducts(q.length > 1 ? q : null), 350);
});

$('#order-search-btn').addEventListener('click', searchOrders);

loadProducts();
loadTrending();
setInterval(loadTrending, 30000);
