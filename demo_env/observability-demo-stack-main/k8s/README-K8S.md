# Running the the demo storefront stack on kind

Same application, same databases, same failure scenarios as the compose stack —
deployed to a local Kubernetes cluster and viewable in Freelens.

## Prerequisites

Colima must be running with enough headroom for a three-node kind cluster plus
the seeded databases:

```bash
colima start --cpu 8 --memory 16 --disk 100 --vm-type vz --mount-type virtiofs
docker ps          # must succeed before you go further
```

Then:

```bash
brew install kind kubectl helm
```

## Deploy

```bash
cp .env.example .env          # fill in DD_API_KEY, DD_SITE, DD_RUM_* values
./k8s/deploy.sh
```

The script creates the cluster, builds all five images, loads them into kind,
creates the Secrets and init ConfigMaps, applies the manifests, waits for the
databases to finish seeding, and installs the Datadog Agent. It is safe to
re-run — everything uses `apply` or `upgrade --install`.

Expect **15 to 25 minutes** on the first run. Most of it is MySQL seeding
1.7 million rows and Maven downloading the Spring Boot dependency tree.

When it finishes:

| What | Where |
|---|---|
| Storefront | http://localhost:8080 |
| Control panel | http://localhost:8080/control.html |
| BFF API | http://localhost:3000/api/health |

Both are reachable because `k8s/kind-cluster.yaml` maps NodePorts 30080 and
30300 to host ports 8080 and 3000.

## Viewing it in Freelens

OpenLens was retired in January 2024 and is no longer maintained. Freelens is
the community fork that took over, MIT-licensed, no sign-in, with native
Apple Silicon builds.

```bash
brew install --cask freelens
```

If that cask is not found, grab the arm64 `.dmg` from
https://github.com/freelensapp/freelens/releases

Freelens reads `~/.kube/config` automatically, so the `kind-${DEMO_NAME}` context
appears on launch — no configuration needed. Useful places to look:

- **Workloads → Pods**, namespace `${DEMO_NAME}`, to watch the stack come up
- **Workloads → StatefulSets → mysql → Logs** to follow the seed
- **Config → ConfigMaps → mysql-init** to see the SQL that was mounted
- **Workloads → DaemonSets → datadog** in the `datadog` namespace, showing one
  agent per node — a good visual when you talk about deployment model

Freelens also gives you a pod shell in one click, which is the fastest way to
run `agent status` during a demo.

## What is different from the compose version

The application code is byte-identical. Only the plumbing changed:

- **MySQL and PostgreSQL are StatefulSets** with PVCs backed by kind's
  local-path provisioner. The same `db/*/init/` scripts are mounted as
  ConfigMaps, so there is one source of truth for the schema and seed.
- **Database Monitoring is configured with pod annotations**
  (`ad.datadoghq.com/mysql.checks`) rather than agent conf files. The DBM
  passwords are referenced as `%%env_MYSQL_DD_PASSWORD%%`, resolved from a
  secret mounted into the agent, so they never appear in a pod spec. The node agent
  discovers the database on the pod and starts the DBM check against it. This is
  worth showing on the call — it is how you would actually onboard a database in
  Kubernetes, with no agent config to maintain.
- **APM points at the node's host IP** via the downward API
  (`status.hostIP`), which is the standard DaemonSet pattern.
- **Unified service tagging comes from pod labels**
  (`tags.datadoghq.com/service`), read back into `DD_SERVICE`, `DD_ENV` and
  `DD_VERSION` through the downward API. That is why traces, logs, metrics and
  the orchestrator explorer all correlate without extra configuration.
- **`orchestratorExplorer` is on**, so Datadog shows live Kubernetes resources —
  Deployments, ReplicaSets, pod restarts — alongside the APM data.

## A note on how the scenarios work

None of the failure scenarios use `SLEEP()` or `pg_sleep()`. The slow-query and
N+1 scenarios run genuinely unindexed and genuinely repeated statements, and the
lock-contention and pool-exhaustion scenarios hold their locks by running real
analytical aggregates over `order_items` and `product_views` for the configured
duration. Everything that appears in Query Samples and Query Activity is a real
statement with a real execution plan, which matters the moment a DBA in the room
decides to look closely.

## Service ownership in the Software Catalog

By default your services appear in the catalog with no owning team, which makes
any team-scoped view look empty. Two things fix that, and both are already wired
into the manifests.

**Telemetry tags.** Each service sets `DD_TAGS=team:<team>`, so every span,
metric and log line carries ownership. The databases carry the same tag through
their DBM instance config.

**Catalog definitions.** `k8s/catalog/entities.yaml` declares eight
Entity v3 objects — one system, four services and three datastores — with owners,
tiers, languages and dependency relationships. Register them once:

```bash
./k8s/register-catalog.sh
```

This needs `DD_APP_KEY` in `.env` alongside the API key. If the API rejects the
payload, the same file imports by hand through Software Catalog → Add Entity.

Ownership is split three ways on purpose:

| Team | Owns |
|---|---|
| `${DEMO_NAME}-storefront` | web, bff, redis |
| `${DEMO_NAME}-commerce` | orders, mysql |
| `${DEMO_NAME}-data` | catalog, postgres |

That split is worth a sentence on the call. A catalog where every service has a
named owner, a tier and declared dependencies is the difference between an
inventory and something an on-call engineer can actually use at 2am — and it
came from labels already on the workloads, not a separate documentation effort.

The teams themselves need to exist in Datadog (Organization Settings → Teams)
for the owner field to resolve to a real team page. The tags work either way.

## Verifying before a demo

```bash
kubectl get pods -n ${DEMO_NAME}                        # all Running
kubectl exec -n datadog ds/datadog -c agent -- agent status | grep -A8 'mysql\|postgres'
kubectl exec -n datadog ds/datadog -c agent -- agent check mysql
```

The `agent status` output must show `dbm: true` and no connection errors for
both database checks. If DBM is missing, the annotation password substitution
failed — check that `MYSQL_DD_PASSWORD` in `.env` matches what the init script
created.

Then confirm in Datadog: Service Map, DBM Query Samples with explain plans, RUM
sessions with replays. The pre-flight list in the root `README.md` applies
unchanged.

## Teardown

```bash
./k8s/teardown.sh              # remove the app and the agent, keep the cluster
./k8s/teardown.sh --cluster    # delete the kind cluster entirely
```

## Troubleshooting

**Pods stuck in `ImagePullBackOff`.** The images are local-only and loaded with
`kind load`. If you recreated the cluster, re-run `./k8s/deploy.sh` to reload
them.

**A service is healthy but sends no traces.** The Python tracer fails open: if a
ddtrace dependency is missing, `sitecustomize.py` prints a traceback at startup
and the application runs normally with no instrumentation at all. Nothing in the
environment or the pod status looks wrong. Check the first few lines of the pod
log, and set `DD_TRACE_DEBUG=true` to make the tracer explain itself:

```bash
kubectl logs -n ${DEMO_NAME} deploy/catalog | head -10
kubectl set env deployment/catalog -n ${DEMO_NAME} DD_TRACE_DEBUG=true
```

The images now verify their tracer imports at build time, so this should fail
loudly during `docker build` rather than silently at runtime.

**Application pods in CrashLoopBackOff with a port parsing error.** Kubernetes
injects legacy Docker-link environment variables for every Service in the
namespace — a Service named `redis` produces `REDIS_PORT=tcp://10.96.x.x:6379`,
which shadows any application variable of the same name. Every pod spec here
sets `enableServiceLinks: false` to disable that mechanism, and pins
`REDIS_PORT` explicitly as a second line of defence. If you add a new Service,
check its name does not collide with an application variable.

**A database pod restarts during seeding.** This is the one failure that is
sticky, so check it first. Both startup probes allow 30 minutes, so a restart
almost always means the container was OOM-killed — raise the memory limit in the
StatefulSet or give Colima more RAM. It matters because once the data directory
is initialised, both entrypoints skip `/docker-entrypoint-initdb.d` entirely on
the next start: you get a running database with no seed data, no application
user and no Datadog user, and nothing will tell you so. Recovery is to delete the
claim and start over:

```bash
kubectl delete statefulset postgres -n ${DEMO_NAME} --cascade=orphan
kubectl delete pod postgres-0 -n ${DEMO_NAME}
kubectl delete pvc data-postgres-0 -n ${DEMO_NAME}
./k8s/deploy.sh
```

**Agent kubelet check failing with a certificate error.** `kubelet.tlsVerify` is
already `false` in `datadog-values.yaml`; confirm your Helm release actually
picked up the values file with `helm get values datadog -n datadog`.

**A database pod stuck `Pending` after a node restart.** kind's local-path
provisioner pins each PersistentVolume to the node that created it. If that node
is recreated the pod can never schedule. Recreate the cluster
(`./k8s/teardown.sh --cluster`) rather than trying to rescue it.

**`localhost:8080` refused.** The NodePort mapping lives on the control-plane
node. Check `kubectl get svc -n ${DEMO_NAME} web-nodeport` shows nodePort 30080, and
that you did not edit the port mappings out of `k8s/kind-cluster.yaml` after the
cluster was created — those are fixed at creation time and need a cluster
recreate to change.

## Reproducibility note

`k8s/kind-cluster.yaml` does not pin a node image, so the Kubernetes version
floats with whatever `kind` version Homebrew installed. If you want this to be
identical across machines and over time, pin it — run `kind version` to see the
default node image for your build, then add it to each node entry:

```yaml
nodes:
  - role: control-plane
    image: kindest/node:v1.xx.y@sha256:...
```
