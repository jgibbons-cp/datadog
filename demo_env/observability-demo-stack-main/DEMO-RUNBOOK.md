# Demo runbook — the demo storefront, database slowness

A 25-minute walkthrough built for Satish and his delivery/dev leads. It moves
from "a customer is having a bad time" to "here is the exact line of SQL and the
exact fix" — which is the argument that a homegrown tool cannot make.

Before you start: the stack has been running for at least 15 minutes, the load
generator is on, and everything on the pre-flight list in `README.md` is green.
Have the storefront on one screen, the control panel on another, and Datadog on
the shared screen.

---

## 0 — Frame it (2 min)

Do not open Datadog yet. Open the storefront and click around. Add something to
the cart. Everything is fast.

Say what the stack is: a D2C storefront on three services in three languages,
talking to MySQL and PostgreSQL — roughly the shape of the 20–30 business-critical
apps they described. Point out that nothing is mocked.

---

## 1 — Baseline: what "healthy" looks like (3 min)

**APM → Service Map.** Trace the request path with your cursor:
browser → BFF → orders/catalog → the two databases. Note that nobody drew this;
it came from the traces.

**APM → Service page for `${DEMO_NAME}-orders`.** Latency, throughput, error rate,
and the resource breakdown. Baseline p95 should be comfortable.

Anchor for later: *this is the picture we compare against.*

---

## 2 — Scenario: the missing index (7 min) ← the centrepiece

Go to **My Orders** on the storefront and search for
`customer1@demo.example`. Note the timing badge — fast, and the mode
says `indexed`.

Now on the control panel, enable **Slow query — unsargable predicates**.

Search again. The badge turns red and the mode reads `full_table_scan`.

Then, in Datadog:

1. **APM → Traces**, filter to `${DEMO_NAME}-orders`. Open a slow
   `/api/orders/search` trace. The flame graph shows almost all the time inside a
   single `mysql.query` span.
2. Click through from the span to **Database Monitoring**. Same query, now with
   execution counts and per-call latency across the whole fleet.
3. Open **Query Samples** and show the **explain plan**: full table scan,
   ~400,000 rows examined, no index used.

Then say the important part: *we went from a customer complaint to the exact
statement and its execution plan without logging into the database server, and
without anyone writing a dashboard for it.*

**Now fix it live.** On the control panel, click **Add MySQL orders index**.
Search again on the storefront — back to milliseconds. Return to DBM and show
the plan change on the next sample.

Drop the index again and turn the scenario off before moving on.

---

## 3 — Scenario: N+1 queries (4 min)

Enable **N+1 queries**. Open the storefront's **My Orders** tab and watch
"Recent orders across the store" get slow; the mode badge reads `n_plus_one`.

**APM → Traces** → open a `/api/orders/recent` trace. The flame graph is a wall
of ~100 tiny `mysql.query` spans. Every individual query is sub-millisecond, so
per-query monitoring would never flag this — only the trace shows it.

This is worth dwelling on with dev leads: it is the single most common
performance defect that survives code review, and it is invisible without
distributed tracing.

Turn it off.

---

## 4 — Scenario: lock contention and pool exhaustion (5 min)

Enable **Row-lock contention**. On the storefront, click "Add to cart" on two or
three products quickly — every checkout is now serialising on one hot SKU.

**DBM → Query Activity** for `${DEMO_NAME}-mysql-prod`: sessions in lock wait, and
the blocking session that everything is queued behind.

Then enable **Connection pool exhaustion** and watch the pool readout on the
control panel — `waiting` climbs above zero. In **APM**, the orders service
latency spikes while database time does not, which is the diagnostic signature
that separates "the database is slow" from "we cannot get to the database."

That distinction is the one their team is currently guessing at.

Turn both off.

---

## 5 — Scenario: the customer's view (4 min)

Set **Frontend error rate** to about 30% and add ~800 ms of **injected latency**.

**RUM → Sessions.** Find a session with errors and open the **Session Replay** —
watch an actual customer click a button and get a failure.

From that same session, jump to the **backend trace** for the failed request.
Frontend to database in two clicks, one continuous story.

This is the part that lands with a non-technical approver like Abhishek: it is
not a metric, it is a recording of a customer losing an order.

Reset everything.

---

## 6 — Close: what this cost to build (2 min)

Be direct. The stack in front of them took a few hours to instrument: an agent
container, one JVM flag, one Node require, one Python wrapper, and a browser
snippet. No dashboards were authored. Everything shown — the service map, the
explain plans, the lock waits, the replays — was there by default.

Contrast that honestly with the internal tooling their team is building. The
question is not whether their team is capable; it is whether distributed tracing,
query-plan capture and session replay are what they want to spend the next two
years maintaining.

Then hand over: offer the trial, and ask which two applications they would
instrument first.

---

## Numbers to collect while you have the room

Work these into the conversation rather than reading them out as a list. Ayon
needs them for the ROI case:

- Incidents per month on the 20–30 critical apps, and average MTTR
- How many engineers get pulled into a typical incident, and for how long
- Duration and business impact of the last major outage
- Hours per week spent hunting through logs or building internal tooling


## Known gap — answer it honestly if asked

This stack covers APM, RUM and DBM. It does not demonstrate Fabric or OneLake
monitoring, which is where Rakuten struggled and where Satish's data team lives.
Check internally what Datadog covers there today before the call. Overpromising
on this point is exactly how the previous vendor lost the account.
