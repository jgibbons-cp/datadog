/* Demo control panel -- writes chaos flags through the BFF into Redis. */

const TOGGLES = ['slow_query', 'n_plus_one', 'pool_exhaustion', 'lock_contention'];
const SLIDERS = { latency_ms: ' ms', error_rate: ' %', hold_seconds: ' s' };

function toast(message, isError) {
  const el = document.createElement('div');
  el.className = 'toast' + (isError ? ' error' : '');
  el.textContent = message;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 3600);
}

async function push(payload) {
  const res = await fetch('/api/chaos', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

async function refresh() {
  try {
    const state = await (await fetch('/api/chaos')).json();
    TOGGLES.forEach((name) => {
      const box = document.getElementById(name);
      if (!box) return;
      box.checked = !!state[name];
      const label = document.getElementById(name + '-state');
      label.textContent = state[name] ? 'ACTIVE' : 'off';
      label.className = state[name] ? 'state-on' : 'state-off';
    });
    Object.keys(SLIDERS).forEach((name) => {
      const slider = document.getElementById(name);
      if (!slider) return;
      slider.value = state[name];
      document.getElementById(name + '-value').textContent = state[name] + SLIDERS[name];
    });
  } catch (err) {
    console.error('failed to read chaos state', err);
  }
}

TOGGLES.forEach((name) => {
  document.getElementById(name).addEventListener('change', async (ev) => {
    try {
      await push({ [name]: ev.target.checked });
      toast(`${name.replace(/_/g, ' ')} ${ev.target.checked ? 'enabled' : 'disabled'}`);
      refresh();
    } catch (err) {
      toast('Failed: ' + err.message, true);
    }
  });
});

Object.keys(SLIDERS).forEach((name) => {
  const slider = document.getElementById(name);
  slider.addEventListener('input', () => {
    document.getElementById(name + '-value').textContent = slider.value + SLIDERS[name];
  });
  slider.addEventListener('change', async () => {
    try {
      await push({ [name]: parseInt(slider.value, 10) });
      toast(`${name.replace(/_/g, ' ')} set to ${slider.value}${SLIDERS[name]}`);
    } catch (err) {
      toast('Failed: ' + err.message, true);
    }
  });
});

document.querySelectorAll('button[data-index]').forEach((btn) => {
  btn.addEventListener('click', async () => {
    const [target, action] = btn.dataset.index.split('/');
    btn.disabled = true;
    const original = btn.textContent;
    btn.textContent = 'Working…';
    try {
      const res = await fetch(`/api/admin/index/${target}/${action}`, { method: 'POST' });
      const body = await res.json();
      toast(body.error ? 'Error: ' + body.error : `${target}: index ${body.status}`, !!body.error);
    } catch (err) {
      toast('Failed: ' + err.message, true);
    } finally {
      btn.disabled = false;
      btn.textContent = original;
    }
  });
});

document.getElementById('reset-btn').addEventListener('click', async () => {
  await fetch('/api/chaos/reset', { method: 'POST' });
  toast('All scenarios reset to healthy');
  refresh();
});

async function pollPool() {
  try {
    const res = await fetch('/api/admin/pool');
    const p = await res.json();
    document.getElementById('pool-stats').textContent =
      `__DEMO_NAME__-orders (HikariCP)\n` +
      `  active  : ${p.active}\n` +
      `  idle    : ${p.idle}\n` +
      `  waiting : ${p.waiting}${p.waiting > 0 ? '   <-- requests queued' : ''}\n` +
      `  max     : ${p.max}`;
  } catch (err) {
    document.getElementById('pool-stats').textContent = 'unavailable: ' + err.message;
  }
}

refresh();
pollPool();
setInterval(pollPool, 2000);
setInterval(refresh, 10000);
