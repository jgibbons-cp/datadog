# Playbook — demonstrating database slowness end to end

The arc is always the same six beats: a customer feels it, the trace localises it,
Database Monitoring names the exact statement, the explain plan says why, you fix
it live, and the fix is visible in seconds. Everything below is real — no staged
screenshots, no pre-recorded data.

Keep three things open: the storefront, the control panel (`/control.html`), and
Datadog. Leave the load generator running throughout so the graphs have signal.

---

## Before you start

```bash
curl -s -X POST localhost:3000/api/chaos/reset
curl -s localhost:3000/api/chaos          # everything false / 0
```

Confirm the MySQL index is absent, so the fix is available to make live:

```bash
curl -s -X POST localhost:3000/api/admin/index/orders/drop
```

---

## Scenario A — Missing index on MySQL (the centrepiece)

**The story:** customer service reports that looking up a customer's orders takes
seconds. Nobody deployed anything. The database "looks fine."

### 1. Establish the baseline (30 seconds)

On the storefront, go to **My Orders** and search
`customer1@demo.example`. Note the timing badge — double digits of
milliseconds — and that the mode reads `indexed`.

```bash
curl -s -w 'total: %{time_total}s\n' -o /dev/null \
  "localhost:3000/api/orders/search?email=customer1@demo.example"
```

Say: *this is what good looks like. Remember the number.*

### 2. Break it

On the control panel, enable **Slow query — unsargable predicates**. Then
generate enough traffic for DBM to sample:

```bash
for i in $(seq 1 30); do
  curl -s -o /dev/null "localhost:3000/api/orders/search?email=customer$i@demo.example"
done
```

Search again on the storefront. The badge turns red and the mode reads
`full_table_scan`. Let them see the page hang — that pause is the entire point,
and it is worth sitting through in silence.

### 3. Localise it — APM

**APM → Traces**, filter `service:${DEMO_NAME}-orders`, resource
`GET /api/orders/search`. Open a slow trace.

The flame graph shows one `mysql.query` span consuming nearly the whole request.
Say: *we now know it is not the network, not the JVM, not the frontend. It is one
statement.*

### 4. Name it — Database Monitoring

Click the `mysql.query` span → **SQL Queries** tab → follow through to Database
Monitoring. Or go directly: **APM → Databases → ${DEMO_NAME}-mysql-prod**.

You are looking at:

```sql
SELECT id, customer_email, status, channel, total_amount, placed_at
FROM orders WHERE customer_email = ? ORDER BY placed_at DESC LIMIT 50
```

Show the per-call latency and the execution count across the fleet. Say: *nobody
instrumented this query. We did not add a metric or write a dashboard.*

### 5. Explain why — the plan

Open **Query Samples** for that statement and show the **explain plan**:

- access type: full table scan
- rows examined: ~400,000
- key used: none

Say: *there is no index on `customer_email`. The plan is telling us the fix.*

This is the moment the demo exists for. Do not rush it.

### 6. Fix it live

On the control panel, click **Add MySQL orders index**. Or:

```bash
curl -s -X POST localhost:3000/api/admin/index/orders/create
```

Search again on the storefront. Back to milliseconds, in front of them.

Return to DBM and show the next sample's plan: `access_type: ref`, using
`idx_orders_customer_email`, rows examined in the tens.

Then reset:

```bash
curl -s -X POST localhost:3000/api/admin/index/orders/drop
curl -s -X POST localhost:3000/api/chaos/reset
```

> **Small honesty note.** The `mode` field in the API response is a scenario
> label, not a live read of the execution plan — after you add the index it still
> says `full_table_scan` while the query is in fact using the index. Rely on the
> timing badge and the DBM plan. If a dev lead spots it, say so plainly; it costs
> you nothing and buys credibility.

---

## Proving the application slowness was *caused* by the query

Showing a slow endpoint and a slow query is correlation. Four moves turn it into
causation, and the fourth is the one that actually settles it.

### 1. Let Datadog attribute the time, rather than asserting it

**APM → Service `${DEMO_NAME}-orders` → Resource `GET /api/orders/search`.** The
latency breakdown attributes the request's duration by span type, and
`mysql.query` will own almost all of it. You are not claiming the database is at
fault; the product is.

### 2. Show the span-to-statement link

Open a slow trace, click the `mysql.query` span, and open the **SQL Queries**
tab. Because `DD_DBM_PROPAGATION_MODE=full` is enabled, the tracer injects the
service, environment and database identity into the SQL comment:

```
/*ddps='${DEMO_NAME}-orders',dde='demo',ddpv='1.4.0',dddbs='mysql',dddb='${DEMO_NAME}_orders'*/
```

So the DBM metrics shown on that tab belong to the exact statement *this exact
request* executed — not a statement that happened to run at a similar time. Say
that out loud; it is the difference between joining on identity and joining on
timestamp, and it is the thing homegrown tooling almost never gets right.

### 3. Reverse the direction

On the database page, open **Calling Services**. From the database's point of
view, show which services depend on it and what latency they are experiencing.
Symptom to cause, then cause back to symptom.

### 4. Run the experiment

Correlation becomes causation when you change one variable and both independent
measurements move together. Before you start, put two graphs side by side —
a notebook is the easiest place:

- **APM:** p95 latency for resource `GET /api/orders/search`
- **DBM:** average duration for that statement on `${DEMO_NAME}-mysql-prod`

Then add the index live. Both drop within a minute, measured by two different
collectors that share no code path. Drop the index; both climb again. Repeat it
once if the room is quiet — repeatability is what makes it an experiment rather
than an anecdote.

Say: *we changed one thing. The query got fast and the endpoint got fast at the
same moment. That is the causal chain, measured rather than inferred.*

### Corroborating evidence from inside the database

On the database Overview, the **Average Load by Wait Event** chart should be
dominated by `wait/io/table/sql/handler` — table I/O. MySQL is telling you it is
reading rows, not waiting on locks and not CPU-bound. That is independent
confirmation of a scan problem from inside the engine itself, and it is the level
of specificity that distinguishes this from a wall of graphs.

---

## Scenario B — Sequential scan on PostgreSQL

Same shape, different engine, and it proves the workflow is not MySQL-specific.

The product page counts views from `product_views` — 800,000 rows, no index on
`product_id`. It is slow by default; no flag required.

```bash
for i in $(seq 100 130); do curl -s -o /dev/null "localhost:3000/api/products/$i"; done
```

**APM → Databases → ${DEMO_NAME}-postgres-prod**, find:

```sql
SELECT count(*), count(DISTINCT session_id) FROM product_views
WHERE product_id = %s AND viewed_at > now() - interval '30 days'
```

The plan shows a sequential scan over the whole table. Fix it from the control
panel with **Add PG product_views index**, or:

```bash
curl -s -X POST localhost:3000/api/admin/index/catalog/create
```

Worth saying: the index is created `CONCURRENTLY`, so nothing blocked while you
did it — which is the question a competent DBA will ask.

---

## Scenario C — Slow queries that no per-query metric would catch

Enable **N+1 queries** and open **My Orders** on the storefront.

**APM → Traces** → a `/api/orders/recent` trace. The flame graph is a wall of
roughly a hundred `mysql.query` spans. Every one is sub-millisecond and perfectly
healthy in isolation.

Say: *query-level monitoring would show nothing wrong here. Every statement is
fast. Only the trace shows that we ran a hundred of them to render one page.*

For an audience of delivery leads this often lands harder than the missing index,
because they recognise the pattern from their own ORM code.

---

## Scenario D — When the database is not the problem

Enable **Connection pool exhaustion** and click "Add to cart" a few times.

Show **APM** latency on `${DEMO_NAME}-orders` climbing while database time stays
flat, and the pool readout on the control panel showing `waiting` above zero.

Say: *the application is slow, the database is idle. Without this you would spend
the afternoon tuning a database that was never the bottleneck.*

Then enable **Row-lock contention** and show **DBM → Query Activity** with
sessions in lock wait and the blocking session tree.

Worth pointing at explicitly: the blocking session is running a real aggregate
over `order_items`, with its own plan and rows-examined count — not a `SLEEP`.
Someone will check, and it holds up.

---

## Closing the loop — the customer's view

With a scenario still active, set **Frontend error rate** to ~30%, click around
the storefront, then open **Digital Experience → Sessions**, find a session with
errors, and play the **Session Replay**.

From that session, jump to the backend trace, then to the query, then to the plan.

Say: *this is one continuous story — a customer clicking a button, and the exact
line of SQL that let them down. No correlation by timestamp, no switching tools.*

Reset everything before you close.

```bash
curl -s -X POST localhost:3000/api/chaos/reset
curl -s -X POST localhost:3000/api/admin/index/orders/drop
curl -s -X POST localhost:3000/api/admin/index/catalog/drop
```

---

## Timing cheat sheet

Fill this in during rehearsal so you know what you are promising:

| Scenario | Endpoint | Baseline | Degraded | After fix |
|---|---|---|---|---|
| Missing index (MySQL) | `/api/orders/search` | | | |
| Sequential scan (PG) | `/api/products/{id}` | | | |
| N+1 | `/api/orders/recent` | | | n/a |
| Pool exhaustion | `/api/checkout` | | | n/a |

If any degraded number is under ~500ms it will not read as a problem on a shared
screen. Raise `hold_seconds`, add load generator concurrency, or lean on the N+1
scenario, which stays dramatic regardless of hardware.
