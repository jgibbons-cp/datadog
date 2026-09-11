# Observability Demo Stack

A real, fully instrumented e-commerce stack with toggleable performance failures — for
demonstrating APM, Database Monitoring and RUM against something that actually breaks.

---

Most observability demos show you a dashboard. This one lets you break a real application
in front of a customer and watch the platform find it.

The slow queries are genuinely slow — a 400,000-row full table scan, not a sleep. The locks
are genuinely held, by real analytical work. The index you add mid-demo genuinely fixes it,
and you can watch the execution plan change from `access_type: ALL` to `ref` while the
customer is looking at it.

That last part matters more than it sounds. The first thing a DBA in the room does is check
whether the blocking statement is real, and `SELECT SLEEP(4)` sitting at the top of a
blocking session tree ends the conversation. There are no sleeps anywhere in this stack.

## Quick start

Requires Docker (Colima works, and is what most people use where Docker Desktop is not
permitted), plus a Datadog API key and a Browser RUM application.

```bash
git clone <this-repo> && cd observability-demo-stack
cp .env.example .env      # set DEMO_NAME, DEMO_BRAND, DD_API_KEY, DD_SITE, DD_RUM_*

./render.sh && docker compose -f .rendered/docker-compose.yml \
  --env-file .env up -d --build       # option A: Compose
./k8s/deploy.sh                       # option B: Kubernetes on kind
```

First run seeds ~2.9M rows and takes 15–25 minutes. After that it is minutes.

| | |
|---|---|
| Storefront | http://localhost:8080 |
| Control panel | http://localhost:8080/control.html |
| BFF API | http://localhost:3000/api/health |

## What it runs

```
                    Browser  (Datadog Browser RUM + Session Replay)
                       |
                    nginx  :8080
                       |  /api/*
                       v
                     BFF   (Node 20 / Express)          <-- owns the chaos flags
                  /        \
                 v          v
            orders          catalog
   (Java 17 / Spring Boot)  (Python 3.11 / FastAPI)
          |                        |
          v                        v
       MySQL 8                PostgreSQL 16
   400k orders                5k products
   1.3M order items           400k reviews
   20k customers              800k product views

   Redis          <-- scenario flags, read live by every service
   Datadog Agent  <-- APM, DBM on both engines, logs, processes, profiler
```

Three languages so traces cross runtime boundaries. Two database engines so you can show
the DBM workflow is identical for both — which matters for any account that is not a
single-database shop.

**Instrumented with:** distributed tracing, Continuous Profiler, Database Monitoring with
explain plans, log collection with trace correlation, Browser RUM with Session Replay, and
on the Kubernetes path, Orchestrator Explorer and Software Catalog ownership.

## Failure scenarios

All six are toggled from the control panel or over HTTP. Change one at a time.

| Scenario | What it does | Measured impact |
|---|---|---|
| Missing index | Full scan of 400k rows on order search | 11ms → 675ms; plan cost 7.35 → 497,699 |
| N+1 queries | ~100 sequential round trips per request | Each query fast, request 20× slower |
| Row-lock contention | Every checkout serialises on one SKU | p95 11ms → 30s; throughput 24 → 5 |
| Pool exhaustion | Saturates a 10-connection pool | App latency climbs, DB time stays flat |
| Frontend errors | 503s on a share of API calls | RUM errors and failed session replays |
| Injected latency | Fixed delay at the BFF | Proves the slowness is *not* the database |

```bash
curl -s localhost:3000/api/chaos                       # current state
curl -s -X POST localhost:3000/api/chaos/reset         # back to healthy
curl -s -X POST localhost:3000/api/chaos \
  -H 'content-type: application/json' -d '{"slow_query":true}'
```

The remediation is real too — `k8s/manifests/90-index-migration-job.yaml` adds the index as
a proper migration using `ALGORITHM=INPLACE, LOCK=NONE`, so you can answer the "did you just
lock a production table?" question before it is asked.

> **Never run injected latency alongside a database scenario.** It puts the time in the BFF,
> and anyone reading the flame graph will correctly conclude the database is innocent —
> contradicting the story you just told.

## Rebranding it

Two lines in `.env`:

```bash
DEMO_NAME=northwind                 # lowercase; drives every generated name
DEMO_BRAND=Northwind Wellness       # storefront header
```

`DEMO_NAME` flows through to the kind cluster, Kubernetes namespace, image prefix, database
names, DBM host identities, Datadog service names, Software Catalog teams and the `account:`
tag. Two engineers running different values can work side by side without colliding.

## Layout

```
docker-compose.yml         Compose topology
.env.example               all configuration
db/{mysql,postgres}/init/  schema, seed data, Datadog DBM users  <-- single source of truth
services/web/              storefront + control panel (nginx, RUM)
services/bff/              Node BFF, owns the chaos flags
services/orders/           Java / Spring Boot, MySQL
services/catalog/          Python / FastAPI, PostgreSQL
loadgen/                   baseline traffic generator
agent/conf.d/              DBM check configs for the Compose path
k8s/                       manifests, deploy script, catalog definitions
```

## Documentation

| File | For |
|---|---|
| [CONFLUENCE.md](CONFLUENCE.md) | The team-facing guide — setup, scenarios, troubleshooting |
| [DB-SLOWNESS-PLAYBOOK.md](DB-SLOWNESS-PLAYBOOK.md) | Proving *causation*, not just correlation, on a call |
| [DEMO-SCRIPT-EXAMPLE.md](DEMO-SCRIPT-EXAMPLE.md) | A timed 30-minute script with measured numbers |
| [DEMO-RUNBOOK.md](DEMO-RUNBOOK.md) | Shorter scenario-by-scenario runbook |
| [k8s/README-K8S.md](k8s/README-K8S.md) | Kubernetes specifics and known gotchas |

## Notes for maintainers

**`orders.customer_email` and `product_views.product_id` are deliberately unindexed.**
Do not fix them. They are the demo.

**The database init directories are the single source of truth.** The Kubernetes path mounts
the same files as ConfigMaps that Compose bind-mounts. Change SQL in one place only.

**Compose and Kubernetes are parameterised differently.** Compose uses native `${DEMO_NAME}`
substitution; the manifests carry `__DEMO_NAME__` placeholders that `deploy.sh` renders with
`sed`. Kubernetes has no native variable substitution, and `sed` avoids depending on
`envsubst`, which is not installed on macOS by default.

**Every pod sets `enableServiceLinks: false`.** Kubernetes otherwise injects
`REDIS_PORT=tcp://…` for the redis Service, which shadows the application's own variable and
crash-loops the services. If you add a Service, check its name does not collide.

**The tracers are verified at build time.** Each image asserts its tracer imports during
`docker build`, because a missing dependency otherwise fails open — the application runs
perfectly and silently emits no telemetry, which is a genuinely horrible thing to discover
during a demo.
