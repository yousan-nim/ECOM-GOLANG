# ECOM-GOLANG — Architecture

E-commerce API built as 3 Go microservices following the **Database-per-Service**
pattern, coordinated through asynchronous events (choreography saga).

> **Related:** [`SCALING.md`](SCALING.md) — load-balancing layers, HPA, Redis
> caching, and bottleneck analysis. Kubernetes manifests live in
> [`infra/k8s/`](../infra/k8s/).

## 1. Stack decisions

| Area              | Choice                                         |
| ----------------- | ---------------------------------------------- |
| Language          | Go                                             |
| Repo layout       | Monorepo + `go.work`, shared `pkg` module      |
| HTTP framework    | Gin                                            |
| DB access         | GORM                                           |
| Database          | PostgreSQL 16 — one instance **per service**   |
| Inter-service     | Asynchronous events via **Kafka (Redpanda)**   |
| Saga style        | **Choreography** (no central orchestrator)     |
| Auth              | JWT verified at each service (shared middleware)|
| Gateway           | nginx — single entry point on `:8080`          |

### Pending decisions

- **Module path** — e.g. `github.com/yousan-nim/ecom`. _(to confirm)_
- **Migrations** — `golang-migrate` (versioned, prod-grade) vs GORM `AutoMigrate`
  (simpler, dev-friendly). _(to confirm)_

## 2. Services & ports

| Service           | Port | Database          | Responsibility                              |
| ----------------- | ---- | ----------------- | ------------------------------------------- |
| `catalog-service` | 8081 | `postgres-catalog`| Products, pricing, stock / reservations     |
| `order-service`   | 8082 | `postgres-order`  | Orders, cart, checkout, order lifecycle     |
| `payment-service` | 8083 | `postgres-payment`| Payments, charges, refunds                  |
| `gateway` (nginx) | 8080 | —                 | Routes `/catalog/ /order/ /payment/`        |

Databases are **never shared**. A service owns its data; others reach it only via
events (or, for plain reads, via REST through the gateway).

## 3. Request & event topology

```
Client → nginx:8080
           ├─ /catalog/*  → catalog-service:8081  → postgres-catalog
           ├─ /order/*    → order-service:8082    → postgres-order
           └─ /payment/*  → payment-service:8083  → postgres-payment

                        Kafka (Redpanda)
   order ──emit──► order.created ──► catalog
   catalog ──emit──► stock.reserved / stock.rejected ──► payment, order
   payment ──emit──► payment.completed / payment.failed ──► order, catalog
```

## 4. Repository layout

```
ECOM-GOLANG/
├── go.work                      # ties the 4 modules together
├── pkg/                         # shared module
│   ├── auth/                    # JWT middleware for Gin
│   ├── kafka/                   # producer/consumer wrapper + outbox publisher
│   ├── events/                  # event schemas (typed payloads + topic names)
│   ├── httpx/                   # response envelope, error helpers
│   └── config/                  # env loading
├── services/
│   ├── catalog/                 # own go.mod
│   │   ├── cmd/main.go
│   │   └── internal/
│   │       ├── handler/         # Gin handlers
│   │       ├── service/         # business logic
│   │       ├── repository/      # GORM data access
│   │       ├── model/           # GORM models
│   │       └── consumer/        # Kafka consumers (saga reactions)
│   ├── order/                   # same layout
│   └── payment/                 # same layout
├── infra/
│   └── nginx/nginx.conf
├── docs/
│   └── ARCHITECTURE.md
└── docker-compose*.yml
```

Each service shares the same internal shape: `handler → service → repository`.

## 5. Checkout — choreography saga

```
1. POST /order/orders
     order: create Order(PENDING) + write outbox row  →  emit  order.created

2. catalog consumes order.created → reserve stock
     ├─ ok       → emit  stock.reserved
     └─ shortage → emit  stock.rejected

3. payment consumes stock.reserved → charge
     ├─ ok       → emit  payment.completed
     └─ failure  → emit  payment.failed

4. order   consumes payment.completed → Order = CONFIRMED
   catalog consumes payment.completed → commit reservation

Compensation:
   payment.failed  → catalog releases stock, order = CANCELLED
   stock.rejected  → order = CANCELLED
```

No service commands another; each reacts to events and emits its own.

## 6. Reliability: Transactional Outbox

Writing to the DB and publishing to Kafka are **not** atomic. To avoid stuck sagas:

1. In one DB transaction, write business data **and** a row into an `outbox` table.
2. A background relay reads unsent `outbox` rows → publishes to Kafka → marks sent.
3. Consumers are **idempotent**: persist processed `event_id`s and skip duplicates
   (Kafka is at-least-once).

This logic lives in `pkg/kafka` so all services share one implementation.

## 7. Events (initial set)

| Topic               | Producer | Consumers        | Payload (key fields)              |
| ------------------- | -------- | ---------------- | --------------------------------- |
| `order.created`     | order    | catalog          | order_id, items[], total          |
| `stock.reserved`    | catalog  | payment, order   | order_id, reservation_id          |
| `stock.rejected`    | catalog  | order            | order_id, reason                  |
| `payment.completed` | payment  | order, catalog   | order_id, payment_id              |
| `payment.failed`    | payment  | order, catalog   | order_id, reason                  |

Schemas are versioned Go structs in `pkg/events`; every event carries
`event_id`, `occurred_at`, and `order_id` (used as the Kafka partition key so a
given order's events stay ordered).

## 8. Authentication

- JWT issued elsewhere (a future `auth`/`user` service); for now tokens are
  verified per request.
- `pkg/auth` provides a Gin middleware: validates signature + expiry, injects
  claims (user id, roles) into the request context.
- The gateway does **not** verify auth yet — services validate independently.

## 9. Infra changes from the existing scaffold

The current `docker-compose*.yml` and `.env*` were authored for Spring/Java and
must be adapted:

- Replace `DB_URL=jdbc:postgresql://...` with a Go DSN
  (`host=... port=5432 user=... dbname=... sslmode=disable`).
- Remove `JAVA_OPTS`, `SPRING_PROFILES_ACTIVE`.
- Add **Redpanda** broker + **Redpanda Console** services.
- Add a multi-stage Go Dockerfile (build from `go.work`).
- Wire each service's Kafka brokers env (`KAFKA_BROKERS=redpanda:9092`).

## 10. Local run (target)

```
docker compose -f docker-compose.yml -f docker-compose.local.yml up
# gateway      → http://localhost:8080
# redpanda UI  → http://localhost:8085  (console)
# pgAdmin      → http://localhost:5050
```
