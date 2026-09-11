# Live demo script — the demo storefront, database slowness

Everything below is verified against the running stack. Numbers in brackets are
what was actually measured, so you know what to expect on screen.

Three windows: **storefront** (localhost:8080), **control panel**
(localhost:8080/control.html), **Datadog**. Share only Datadog and the
storefront; keep the control panel on your own screen.

---

## T-15 — before they join

```bash
# 1. Healthy starting state, and the fix must NOT be applied yet
curl -s -X POST localhost:3000/api/chaos/reset
curl -s -X POST localhost:3000/api/admin/index/orders/drop
curl -s localhost:3000/api/chaos          # all false, latency_ms 0

# 2. Everything running
kubectl get pods -n ${DEMO_NAME}              # 8/8 Running
kubectl get pods -n datadog               # 3 agents + cluster agent
```

Open these tabs in order, so you never navigate from scratch on the call:

1. APM → Service Map (`env:demo`)
2. APM → Service `${DEMO_NAME}-orders`
3. APM → Traces, filtered `service:${DEMO_NAME}-orders`
4. APM → Databases → `${DEMO_NAME}-mysql-prod`
5. Monitors → filtered `tag:"demo:${DEMO_NAME}"` — confirm all OK
6. Digital Experience → Sessions

**Click around the storefront for two minutes.** RUM only records real browser
sessions; the load generator produces none. Do this now so you have a warm
session before you need one.

---

## 0:00 — Frame it (2 min) · storefront only

Do not open Datadog yet. Browse products, run an order search, add to cart.
Everything is fast.

> "This is a D2C storefront. Three services in three languages, MySQL and
> PostgreSQL behind them — roughly the shape of the twenty to thirty critical
> applications you described. Nothing here is mocked or pre-recorded."

---

## 0:02 — Baseline (3 min) · APM

**Service Map.** Trace the path with your cursor: browser → BFF → orders and
catalog → the two databases.

> "Nobody drew this. It came from the traces."

**Service page for `${DEMO_NAME}-orders`.** Latency, throughput, error rate.

> "This is what healthy looks like. Remember the shape."

---

## 0:05 — Break it (2 min) · control panel

Control panel → enable **Slow query — unsargable predicates**.

```bash
for i in $(seq 1 30); do
  curl -s -o /dev/null "localhost:3000/api/orders/search?email=customer$i@demo.example"
done
```

Storefront → **My Orders** → search `customer1@demo.example`.
The badge turns red, mode reads `full_table_scan`. **[~675ms p95]**

Let the page hang. Say nothing for a beat — that pause is the demo.

---

## 0:07 — The platform notices (3 min) · Monitors

Wait for the evaluation windows. Within about five minutes:

- `[${DEMO_NAME}] APM P95 — orders search endpoint` → **Alert**
- `[${DEMO_NAME}] Log — Slow order search` → **Alert**
- `[${DEMO_NAME}] Composite — orders search: API + DB correlated` → **Alert**

> "Three different products noticed independently — request metrics, database
> telemetry and application logs. Nobody built a dashboard for this."

Open the composite and read its message aloud: impact, sub-monitors, next steps.
If a Bits AI investigation has been triggered, open it here.

---

## 0:10 — Localise it (4 min) · APM

**APM → Traces** → `service:${DEMO_NAME}-orders`, resource `GET /api/orders/search`.
Open a slow trace.

- Flame graph: one `mysql.query` span owns nearly the whole request
- Resource page: latency attributed by span type, `mysql.query` dominating

> "Not the network, not the JVM, not the frontend. One statement."

---

## 0:14 — Name it and explain it (4 min) · DBM

Click the `mysql.query` span → **SQL Queries** tab → through to Database
Monitoring.

The statement:

```sql
SELECT id, customer_email, status, channel, total_amount, placed_at
FROM orders WHERE customer_email = ? ORDER BY placed_at DESC LIMIT ?
```

Open **Query Samples** → the **explain plan**: **[cost 497,699 · access_type ALL
· 404,574 rows examined · no index used]**

Then the **wait event** chart on the database overview:
**[dominated by `wait/io/table/sql/handler` — table I/O]**

> "MySQL is telling us it is reading rows, not waiting on locks and not
> CPU-bound. That is independent confirmation from inside the engine."

Point at the SQL comment on the sample:

```
/*ddps='${DEMO_NAME}-orders',dde='demo',dddbs='mysql',traceparent='00-6a8403e8...'*/
```

> "This joins the trace to the query on identity, not on timestamp. That
> distinction is the thing homegrown tooling almost never gets right."

**This is the beat the demo exists for. Do not rush it.**

---

## 0:18 — Corroborate (2 min, optional) · Profiler

**APM → Profiles** for `${DEMO_NAME}-orders` during the slow window. Look at thread
state — time parked in socket reads inside the JDBC driver.

> "The thread is not computing. It is waiting. Three separate collectors, no
> shared code path, same conclusion."

Skip this if you are behind time.

---

## 0:20 — Fix it live (3 min)

Control panel → **Add MySQL orders index**, or:

```bash
curl -s -X POST localhost:3000/api/admin/index/orders/create
```

Search again on the storefront. **[~1ms — back to instant]**

Back in DBM, the next sample's plan: **[cost 7.35 · access_type ref · key
idx_orders_customer_email · 42 rows examined]**

Watch the monitors recover to OK.

> "We changed one thing. The query got fast and the endpoint got fast at the
> same moment, measured by two collectors that share no code. That is the causal
> chain, measured rather than inferred."

---

## 0:23 — The customer's view (4 min) · RUM

```bash
curl -s -X POST localhost:3000/api/chaos \
  -H 'content-type: application/json' -d '{"error_rate":30}'
```

Click around the storefront until something fails.

**Digital Experience → Sessions** → open a session with errors → **Session
Replay**. Watch a real customer click a button and get an error.

From that session, jump to the backend trace.

> "This is one continuous story — a customer clicking a button, and the exact
> line of SQL that let them down. No correlating by timestamp, no switching
> tools."

This is the part that lands with whoever has to approve the spend.

---

## 0:27 — Close (3 min)

```bash
curl -s -X POST localhost:3000/api/chaos/reset
curl -s -X POST localhost:3000/api/admin/index/orders/drop
```

> "Instrumenting this took an agent container, one JVM flag, one Node require,
> one Python wrapper and a browser snippet. I authored no dashboards. The
> service map, the explain plans, the wait events, the replays — all default.
>
> The question isn't whether your team could build some of this. It's whether
> distributed tracing, query-plan capture and session replay are what you want
> to spend the next two years maintaining."

Then hand over: offer the trial, and ask **which two applications they would
instrument first.**

---

## Bench — if they ask for more

**N+1 queries.** Enable it, open My Orders, open a `/api/orders/recent` trace.
A wall of ~100 `mysql.query` spans, each sub-millisecond.

> "Query-level monitoring shows nothing wrong. Every statement is fast. Only the
> trace shows we ran a hundred of them to render one page."

Best scenario for dev leads — they recognise it from their own ORM code.

**Lock contention.** Enable it, click Add to cart repeatedly, show
**DBM → Query Activity**: sessions in lock wait, and the blocking session tree.
The blocker is a real aggregate over `order_items`, not a sleep.

**Pool exhaustion.** Enable it; APM latency on `${DEMO_NAME}-orders` climbs while
database time stays flat, and `waiting` on the control panel rises above zero.

> "The application is slow and the database is idle. Without this you would
> spend the afternoon tuning a database that was never the bottleneck."

**Injected latency.** Only if asked, and never alongside a database scenario —
it puts the time in the BFF, which contradicts the story you just told.

---

## If something goes wrong

| Symptom | Do this |
|---|---|
| Monitors won't fire | Keep going with traces and DBM; don't wait on screen |
| Storefront looks slow for no reason | `curl -s localhost:3000/api/chaos` — check `latency_ms` is 0 |
| No RUM session to show | You have saved replays; open one from Sessions |
| Explain plan missing on a sample | Open a different sample; not every one carries a plan |
| A pod is unhealthy | `kubectl get pods -n ${DEMO_NAME}`, and fall back to talking through the trace you already have open |

Never debug live for more than about thirty seconds. Move to the next beat and
come back to it afterwards if it matters.
