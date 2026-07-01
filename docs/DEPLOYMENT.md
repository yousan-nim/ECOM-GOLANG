# DEPLOYMENT — build, run, deploy, rollback

> วิธี build image, รัน local, deploy ขึ้น Kubernetes, และ rollback
> Related: [`../infra/k8s/README.md`](../infra/k8s/README.md) · [`SCALING.md`](SCALING.md) · [`ARCHITECTURE.md`](ARCHITECTURE.md)

## 1. Build (multi-stage Go image)

แต่ละ service build จาก `go.work` เป็น **distroless nonroot** (UID 65532, read-only rootfs).

```bash
# ตัวอย่าง (ปรับ path/target ตาม Dockerfile จริง)
docker build -t YOUR_REGISTRY/catalog:v1 --build-arg SERVICE=catalog .
docker build -t YOUR_REGISTRY/order:v1   --build-arg SERVICE=order   .
docker build -t YOUR_REGISTRY/payment:v1 --build-arg SERVICE=payment .
docker push YOUR_REGISTRY/{catalog,order,payment}:v1
```

## 2. Run — local (Docker Compose)

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml up
#   gateway         → http://localhost:8080
#   catalog/order/payment → :8081 / :8082 / :8083
#   redpanda console → http://localhost:8085
#   pgAdmin          → http://localhost:5050
```

> หมายเหตุ: `docker-compose*.yml` / `.env*` เดิมเขียนสำหรับ Spring/Java — ต้องปรับเป็น Go
> (DSN แบบ Go, ลบ `JAVA_OPTS`/`SPRING_*`, เพิ่ม Redpanda + `KAFKA_BROKERS`) — ดู ARCHITECTURE §9

## 3. Configuration (env)

โหลดผ่าน [`pkg/config`](../pkg/config/config.go) — `config.Load("<service>")`:

| Env | Default | หมายเหตุ |
| --- | ------- | -------- |
| `HTTP_PORT` | 8080 | ตั้งต่อ service (8081/8082/8083) |
| `DB_HOST`/`DB_PORT`/`DB_USER`/`DB_PASSWORD`/`DB_NAME` | – | Postgres ต่อ service |
| `DB_SSLMODE` | disable | prod ใช้ `require` |
| `KAFKA_BROKERS` | localhost:9092 | คั่นด้วย `,` |
| `REDIS_ADDR` | "" (ว่าง = ปิด cache) | cache เป็น optional |
| `REDIS_PASSWORD` / `REDIS_DB` | "" / 0 | |
| `JWT_SECRET` | dev-secret-change-me | **เปลี่ยนใน prod** |

Secret **ห้าม commit** — ใช้ `.env.example` เป็นแม่แบบ; บน k8s ใช้ Secret/external secrets operator

## 4. Deploy — Kubernetes (kustomize)

Manifest อยู่ใน [`infra/k8s/`](../infra/k8s/) — แต่ละ service มี **Deployment + Service + HPA + PDB**;
Postgres เป็น **StatefulSet** ต่อ service; gateway เป็น **Ingress** (ingress-nginx)

**Prerequisites:** cluster + `ingress-nginx` + `metrics-server` (สำหรับ HPA) + Kafka/Redpanda ที่ `redpanda:9092`

```bash
cd infra/k8s
# ใส่ image tag จริง (ไม่ต้องแก้ Deployment)
kustomize edit set image \
  ecom/catalog-service=YOUR_REGISTRY/catalog:v1 \
  ecom/order-service=YOUR_REGISTRY/order:v1 \
  ecom/payment-service=YOUR_REGISTRY/payment:v1

kubectl apply -k .
kubectl -n ecom get pods,hpa,ingress
```

### Zero-downtime
- RollingUpdate `maxSurge:1, maxUnavailable:0` → ไม่มี downtime ตอน deploy
- `readinessProbe` (`/readyz` ping DB) → LB route เมื่อ pod พร้อมจริง
- `PodDisruptionBudget minAvailable:1` → คง pod ขั้นต่ำตอน node drain

### Autoscaling (HPA)
CPU 70% / memory 80%; catalog `2→10` (read-heavy, headroom มากสุด), order/payment ตาม manifest

```bash
kubectl -n ecom get hpa -w
kubectl -n ecom scale deploy/catalog-service --replicas=5   # HPA จะ reconcile กลับ
```

## 5. Rollback

```bash
# ย้อน deployment ไป revision ก่อนหน้า (zero-downtime)
kubectl -n ecom rollout undo deploy/catalog-service
kubectl -n ecom rollout undo deploy/catalog-service --to-revision=3
kubectl -n ecom rollout status deploy/catalog-service     # เฝ้าดูจนสำเร็จ
kubectl -n ecom rollout history deploy/catalog-service    # ดู revision (เก็บ 5)
```

- **DB migration:** รันตอน boot และ **forward-only** — rollback โค้ดต้อง backward-compatible กับ schema
  (อย่า deploy โค้ดที่ต้อง schema ใหม่คู่กับ migration ที่ย้อนไม่ได้ → ใช้ expand/contract)
- **Saga:** ระหว่าง rollout event อาจถูก consume ซ้ำ — ปลอดภัยเพราะ consumer idempotent ([`EVENTS.md`](EVENTS.md) §6)

## 6. Production notes (จาก [`infra/k8s/README.md`](../infra/k8s/README.md))

- **DB:** ใช้ managed Postgres (RDS/Cloud SQL) หรือ operator (CloudNativePG) + read replica; เพิ่ม **PgBouncer** คั่นเมื่อ pod scale out (ดู [`SCALING.md`](SCALING.md))
- **Secrets:** external secrets operator (Vault / AWS/GCP) — อย่า commit ค่าจริง (placeholder ใน `10-config.yaml` ใช้ dev เท่านั้น)
- **Redis HA:** Redis Operator หรือ managed — คงชื่อ Service `redis` ไว้ (ไม่ต้องแก้ app config)
- **TLS:** เพิ่ม cert-manager + `tls:` block ที่ Ingress
- **Kafka/Redpanda:** จัดการด้วย operator (stateful infra — ไม่ได้ bundle ใน manifest)
