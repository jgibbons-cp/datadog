# Observability Demo Stack — a real application for demonstrating APM, DBM and RUM

A self-contained e-commerce application you run on your own laptop, instrumented
end to end, with failure scenarios you can switch on live in front of a customer.

Nothing is mocked or pre-recorded. The slow queries are genuinely slow, the locks
are genuinely held, and the index you add during a demo genuinely fixes it. There
are no `SLEEP()` calls anywhere — every scenario does real database work, because
the first thing a DBA in the room checks is whether the blocking statement is real.

Rebrand it for your account by editing two lines in `.env`.

---

## What you get

| Component | Technology | Purpose |
|---|---|---|
| Storefront | nginx + vanilla JS | Browser RUM with Session Replay |
| BFF | Node 20 / Express | Fans out to the two backends; owns the scenario flags |
| Orders service | Java 17 / Spring Boot | Order capture, inventory, revenue analytics |
| Catalog service | Python 3.11 / FastAPI | Products, reviews, browse analytics |
| Orders database | MySQL 8 | 400k orders, 1.3M order items, 20k customers |
| Catalog database | PostgreSQL 16 | 5k products, 400k reviews, 800k product views |
| Cache | Redis 7 | Scenario flags, read live by every service |
| Load generator | Python | Continuous baseline traffic |

Three languages so traces cross runtime boundaries, and two database engines so
you can show that the DBM workflow is identical for both. Roughly 2.9 million
rows are seeded, which is enough that a full table scan is genuinely slow rather
than theoretically slow.

**Datadog coverage:** APM with distributed tracing, Continuous Profiler, Database
Monitoring with explain plans on both engines, log collection with trace
correlation, Browser RUM with Session Replay, and — on the Kubernetes path —
Orchestrator Explorer and Software Catalog ownership.

---

## Prerequisites

Docker Desktop is not permitted in many organisations. Colima is the free
alternative and is what this guide assumes.

```bash
brew install colima docker docker-compose kubectl helm kind

mkdir -p ~/.docker/cli-plugins
ln -sfn "$(brew --prefix)/opt/docker-compose/bin/docker-compose" ~/.docker/cli-plugins/docker-compose

colima start --cpu 8 --memory 16 --disk 100 --vm-type vz --mount-type virtiofs
docker ps
```

If Colima insists on installing k3s you do not want, stop it and run
`colima kubernetes delete`, then start again with `--kubernetes=false`.

You also need, in Datadog: an **API key**, an **application key** (only for
registering Software Catalog ownership), and a **Browser RUM application**
(Digital Experience → RUM Applications → New Application → Browser). The RUM
application ID is a UUID — if you paste a name there, RUM silently collects
nothing.

---

## Setup

```bash
unzip observability-demo-stack.zip
cd observability-demo-stack
cp .env.example .env
```

Edit `.env`. The first two lines are what you change per account:

```bash
DEMO_NAME=northwind                 # lowercase; drives every generated name
DEMO_BRAND=Northwind Wellness       # shown in the storefront header
```

`DEMO_NAME` becomes the Kubernetes namespace, the kind cluster name, the Docker
image prefix, the database names, the DBM host identities, the Datadog service
names and the `account:` tag. Two engineers running different `DEMO_NAME` values
can work side by side without colliding.

Then fill in `DD_API_KEY`, `DD_SITE`, `DD_APP_KEY` and the two RUM values.

### Option A — Docker Compose (fastest)

```bash
./render.sh
docker compose -f .rendered/docker-compose.yml --env-file .env up -d --build
docker compose -f .rendered/docker-compose.yml logs -f mysql
```

`render.sh` substitutes `DEMO_NAME` and `DEMO_BRAND` through the SQL init
scripts and application source, which Compose bind-mounts and builds directly.
The Kubernetes path does this internally, so `deploy.sh` needs no equivalent step.

### Option B — Kubernetes on kind

```bash
./k8s/deploy.sh
```

One command: creates the cluster, builds and loads all five images, applies
secrets and init ConfigMaps, brings up the data tier, waits for the seed, starts
the application tier, then installs the Datadog Agent. Idempotent — safe to re-run.

**First run takes 15–25 minutes.** Most of it is MySQL seeding 1.7M rows and
Maven downloading the Spring Boot dependency tree. Subsequent runs are minutes.

When it finishes:

| What | Where |
|---|---|
| Storefront | http://localhost:8080 |
| Control panel | http://localhost:8080/control.html |
| BFF API | http://localhost:3000/api/health |

Optionally register Software Catalog ownership (three teams, tiers, dependencies):

```bash
./k8s/register-catalog.sh
```

---

## Verify before you demo

Do this the day before, not an hour before. Give it ten minutes of traffic, then:

```bash
kubectl get pods -n $DEMO_NAME                       # all Running
curl -s localhost:3000/api/chaos                     # flag JSON, proves Redis is wired

NODE=$(kubectl get pod mysql-0 -n $DEMO_NAME -o jsonpath='{.spec.nodeName}')
POD=$(kubectl get pods -n datadog --field-selector spec.nodeName=$NODE \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep '^datadog-[a-z0-9]\{5\}$')
kubectl exec -n datadog $POD -c agent -- agent check mysql
```

The DBM checks only run on the agent co-located with the database pods, which is
why you target that pod specifically rather than using `ds/datadog`.

Then confirm in the UI:

1. **APM → Service Map** shows the full chain down to both databases
2. **APM → Databases** lists both hosts with query metrics
3. **DBM → Query Samples** has **explain plans** — this is the one that matters
4. **Digital Experience → Sessions** has a session with a replay

For number four you must click around the storefront yourself. The load generator
talks to the API directly and never loads a page, so it produces no RUM data.

New services can take 15–60 minutes to appear in Software Catalog. That is
ingestion lag, not a problem — APM, DBM and RUM do not depend on it.

---

## Running the chaos tests

Everything is driven from the control panel at `/control.html`, or over HTTP.
Change one variable at a time.

```bash
curl -s localhost:3000/api/chaos                      # current state
curl -s -X POST localhost:3000/api/chaos/reset        # back to healthy
curl -s -X POST localhost:3000/api/chaos \
  -H 'content-type: application/json' -d '{"slow_query":true}'
```

### 1. Missing index — the centrepiece

Switches order search to an equality predicate on an unindexed column: a full
scan of 400,000 rows on every request.

```bash
curl -s -X POST localhost:3000/api/admin/index/orders/drop
curl -s -X POST localhost:3000/api/chaos -H 'content-type: application/json' -d '{"slow_query":true}'

for i in $(seq 1 30); do
  curl -s -o /dev/null "localhost:3000/api/orders/search?email=customer$i@demo.example"
done
```

**Measured:** ~11ms healthy → ~675ms degraded. Explain plan cost **7.35 → 497,699**.

**Show:** APM trace where one `mysql.query` span owns the request → span → SQL
Queries tab → DBM explain plan showing `access_type: ALL`, no key used, ~400k
rows examined → the wait-event chart dominated by `wait/io/table/sql/handler`.

**Fix live**, either from the control panel or as a proper migration:

```bash
kubectl apply -f k8s/manifests/90-index-migration-job.yaml
```

The migration uses `ALGORITHM=INPLACE, LOCK=NONE`, so nothing is locked — worth
saying before anyone asks. The plan flips to `access_type: ref` on the new index.

### 2. N+1 queries

One batched join becomes ~100 sequential round trips per request.

```bash
curl -s -X POST localhost:3000/api/chaos -H 'content-type: application/json' -d '{"n_plus_one":true}'
curl -s -o /dev/null localhost:3000/api/orders/recent?limit=15
```

**Show:** the flame graph — a wall of sub-millisecond `mysql.query` spans. Every
statement is individually healthy, so per-query monitoring would never flag it.
This lands hardest with delivery leads, who recognise it from their own ORM code.

### 3. Row-lock contention

Forces every checkout onto one SKU with `SELECT … FOR UPDATE` held open while
real analytical aggregates run. You must create the concurrency yourself:

```bash
curl -s -X POST localhost:3000/api/chaos -H 'content-type: application/json' -d '{"lock_contention":true}'

for i in $(seq 1 8); do
  curl -s -o /dev/null -X POST localhost:3000/api/checkout \
    -H 'content-type: application/json' -d '{"qty":1}' &
done; wait
```

**Measured:** checkout p95 11ms → 30s, and throughput collapses from 24 requests
per interval to 5. Point at the throughput drop — it is more visceral than latency.

**Show:** DBM → Blocking Queries, and the blocking session tree.

Keep `hold_seconds` at 4–5. At 10 seconds with 8 concurrent requests you cross
InnoDB's 50-second lock wait timeout and get failures instead.

### 4. Connection pool exhaustion

The application pool is 10 connections; checkout holds one for the duration.

```bash
curl -s -X POST localhost:3000/api/chaos -H 'content-type: application/json' -d '{"pool_exhaustion":true}'
```

**Show:** application latency climbing while database time stays flat, and
`waiting` above zero on the control panel. This is the "it is *not* the database"
scenario, and it is the one that proves observability saves you from tuning the
wrong thing.

### 5. Frontend errors

```bash
curl -s -X POST localhost:3000/api/chaos -H 'content-type: application/json' -d '{"error_rate":30}'
```

Click around the storefront, then open **Digital Experience → Sessions**, find a
failed session, play the **Session Replay**, and jump from it to the backend
trace. This is the layer for a non-technical approver.

### 6. Injected latency — use with care

```bash
curl -s -X POST localhost:3000/api/chaos -H 'content-type: application/json' -d '{"latency_ms":2000}'
```

Adds delay at the BFF, ahead of any database work, so the trace shows the time is
**not** in the database.

**Never run this alongside a database scenario.** It puts the latency in the BFF,
and a dev lead reading that flame graph will correctly conclude the database is
innocent — contradicting the story you just told. This is the single easiest way
to undermine your own demo.

### Always reset between scenarios

```bash
curl -s -X POST localhost:3000/api/chaos/reset
```

---

## Monitors

Monitors are not shipped with the stack — thresholds depend on your hardware, and
a monitor that never fires is worse than none. Measure first, then create.

A useful set for the missing-index scenario:

1. **APM** — p95 on `GET /api/orders/search`, alert at roughly half your measured
   degraded value
2. **Logs** — the application already emits `Slow order search ... took Nms` with
   `dd.trace_id` injected, so a log monitor on that string is deterministic and
   cannot silently misfire
3. **DBM** — build it from the query page itself, so it targets that statement.
   Check the aggregation is a **duration percentile, not a count**, and that the
   threshold is in **nanoseconds**
4. **Composite** of 1 and 3, so the correlation claim is true rather than hopeful

Expect **three to five minutes** between flipping a scenario and a red monitor.
Trigger it, then fill the gap with the trace and the explain plan — the alerts
land on their own while you talk, which reads far better than watching a tile.

Watchdog anomaly detection needs roughly two weeks of baseline history, so it
will not fire on a stack you stood up yesterday. Use the on-demand **Investigate**
and **Explain This Graph** actions instead; they work immediately.

---

## Teardown

```bash
docker compose down -v          # compose, including volumes
./k8s/teardown.sh               # remove the app and agent, keep the cluster
./k8s/teardown.sh --cluster     # delete the kind cluster entirely
```

Keeping the cluster costs nothing and makes the next rebuild a single command.

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Pods `CrashLoopBackOff` with a port parsing error | Kubernetes injects `REDIS_PORT=tcp://…` for the redis Service. Every pod spec sets `enableServiceLinks: false` — if you add a Service, check its name does not collide with an application variable |
| nginx returns 403 for every page | File permissions from your checkout. The web Dockerfile runs `chmod -R a+rX`; re-download rather than patching |
| A database pod restarts during seeding | Almost always OOM. It is sticky: once the data directory exists, the entrypoint skips `initdb` forever and you get a running database with no data and no users. Delete the PVC and redeploy |
| A service is healthy but sends no traces | The Python tracer fails open — a missing dependency prints a traceback at startup and the app runs uninstrumented. Check the first lines of the pod log, or set `DD_TRACE_DEBUG=true` |
| `localhost:8080` refused | NodePort mappings are fixed at cluster creation. Editing `kind-cluster.yaml` afterwards has no effect without recreating the cluster |
| Storefront slow for no reason | `curl -s localhost:3000/api/chaos` — check `latency_ms` is 0 |
| No RUM data | Confirm `DD_RUM_APPLICATION_ID` is a UUID, not an application name, and remember only real browser sessions produce RUM |

---

## Notes for whoever maintains this

The two database init directories are the single source of truth for schema and
seed data; the Kubernetes path mounts the same files as ConfigMaps that Compose
bind-mounts. Change SQL in one place only.

`orders.customer_email` and `product_views.product_id` are deliberately left
unindexed. Do not "fix" them — they are the demo.

Both `docker-compose.yml` and the Kubernetes manifests are parameterised, but
differently: Compose uses native `${DEMO_NAME}` substitution, while the manifests
carry `__DEMO_NAME__` placeholders that `deploy.sh` renders with `sed`. Kubernetes
has no native variable substitution, and `sed` avoids a dependency on `envsubst`,
which is not installed on macOS by default.
