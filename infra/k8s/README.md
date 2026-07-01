# Kubernetes manifests

Production-shaped manifests for running the ECOM services on Kubernetes with
horizontal autoscaling, in-cluster load balancing, and the shared Redis cache.

See [`docs/SCALING.md`](../../docs/SCALING.md) and
[`docs/DEPLOYMENT-K8S.md`](../../docs/DEPLOYMENT-K8S.md) for the architecture and
the bottleneck analysis behind these choices.

## Files

| File | What |
| --- | --- |
| `00-namespace.yaml` | `ecom` namespace |
| `10-config.yaml` | shared ConfigMap + Secret (placeholders — replace in real clusters) |
| `20-redis.yaml` | Redis cache (Deployment + Service) |
| `30-postgres.yaml` | one Postgres StatefulSet per service (DB-per-service) |
| `40-catalog.yaml` | catalog Deployment + Service + HPA + PDB (annotated reference) |
| `41-order.yaml` | order Deployment + Service + HPA + PDB |
| `42-payment.yaml` | payment Deployment + Service + HPA + PDB |
| `50-ingress.yaml` | ingress gateway (path routing + rate limiting) |
| `kustomization.yaml` | applies everything; manages image tags |

## Prerequisites

- A cluster with the **ingress-nginx** controller installed.
- The **metrics-server** add-on (HPA reads CPU/memory from it).
- **Kafka/Redpanda** reachable at `redpanda:9092` — run the
  [Redpanda operator](https://docs.redpanda.com/current/deploy/deployment-option/self-hosted/kubernetes/)
  or point `KAFKA_BROKERS` in `10-config.yaml` at a managed broker. (Not bundled
  here — brokers are stateful infra usually managed by an operator.)

## Apply

```bash
# Build & push images first, then set the tags:
cd infra/k8s
kustomize edit set image \
  ecom/catalog-service=YOUR_REGISTRY/catalog:v1 \
  ecom/order-service=YOUR_REGISTRY/order:v1 \
  ecom/payment-service=YOUR_REGISTRY/payment:v1

kubectl apply -k .
kubectl -n ecom get pods,hpa,ingress
```

## Verify scaling

```bash
# Watch the HPA react to load:
kubectl -n ecom get hpa -w
# Manually scale (HPA will reconcile back to its target):
kubectl -n ecom scale deploy/catalog-service --replicas=5
```

## Production notes

- **Databases**: these StatefulSets are a baseline. For prod use managed
  Postgres (RDS/Cloud SQL) or an operator (CloudNativePG) for backups, failover
  and **read replicas**; then add a **PgBouncer** Deployment between services and
  each DB to bound connection counts as pods scale out (see `docs/SCALING.md`).
- **Secrets**: replace `10-config.yaml`'s placeholder Secret with an external
  secrets operator (Vault, AWS/GCP secrets manager). Never commit real secrets.
- **Redis HA**: swap the single Redis Deployment for the Redis Operator or a
  managed Redis; keep the Service name `redis` so no app config changes.
- **TLS**: add cert-manager + a `tls:` block to the Ingress.
