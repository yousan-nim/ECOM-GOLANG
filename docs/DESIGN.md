# design.md — การออกแบบเชิงเทคนิค

> "ระบบทำงานยังไง + ออกแบบมาแบบไหน" — สำหรับ dev/architect
> ภาพรวมฉบับเต็ม: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · scaling: [`docs/SCALING.md`](docs/SCALING.md) ·
> "ทำไม" อยู่ใน [`context.md`](context.md) · pattern แต่ละตัว: [`docs/patterns/`](docs/patterns/README.md)

## 1. Architecture overview

```
Client → nginx:8080 (gateway)
           ├─ /catalog/*  → catalog-service:8081 → postgres-catalog
           ├─ /order/*    → order-service:8082   → postgres-order
           └─ /payment/*  → payment-service:8083 → postgres-payment
                              │
                        Kafka (Redpanda) — event bus
```

- **Database-per-Service:** 3 Postgres instance แยกกัน ไม่แชร์ตาราง
- **Async coordination:** service คุยกันผ่าน event ไม่ใช่ direct call (ใน checkout flow)
- **Gateway:** nginx เป็น single entry point route ตาม path prefix

## 2. โครงสร้างภายในแต่ละ service (layered)

```
cmd/main.go        composition root — ประกอบ dependency ทั้งหมดที่นี่
  ↓ inject
handler/  → service/  → repository/  → PostgreSQL (GORM)
   (HTTP)   (business)   (data access)
consumer/  → service/                  ← Kafka (saga reactions)
model/     GORM structs
```

ทิศทาง dependency: **ชี้เข้าด้านใน** (handler รู้จัก service, service รู้จัก repository interface — ไม่ย้อนกลับ)
กฎการวางโค้ดอยู่ใน [`rules.md`](rules.md) R1.5

## 3. Checkout — choreography saga (flow หลัก)

```
1. POST /order/orders
   order: create Order(PENDING) + เขียน outbox row (1 tx) → emit  order.created

2. catalog ← order.created → reserve stock
   ├─ ok       → emit  stock.reserved
   └─ shortage → emit  stock.rejected

3. payment ← stock.reserved → charge (idempotent)
   ├─ ok       → emit  payment.completed
   └─ failure  → emit  payment.failed

4. order   ← payment.completed → Order = CONFIRMED
   catalog ← payment.completed → commit reservation

Compensation:
   payment.failed → catalog คืน stock, order = CANCELLED
   stock.rejected → order = CANCELLED
```

**ไม่มี service ไหนสั่งอีก service** — ทุกตัว react ต่อ event แล้ว emit ของตัวเอง

## 4. Reliability design

### Transactional Outbox ([04](docs/patterns/04-outbox.md))
DB write กับ Kafka publish ไม่ atomic → ในหนึ่ง tx เขียนทั้ง business data + `outbox` row,
background relay อ่าน row ที่ยังไม่ส่ง → publish → mark sent. Logic อยู่ใน `pkg/kafka` (ใช้ร่วมทุก service)

### Idempotent Consumer ([05](docs/patterns/05-idempotent-consumer.md))
Kafka = at-least-once → consumer persist `event_id` ที่ประมวลแล้ว (`processed_events`) และข้ามซ้ำ

### Health / readiness ([`pkg/httpx`](pkg/httpx/httpx.go))
- `/healthz` — liveness (process ขึ้นไหม) → ใช้ตัดสินใจ restart
- `/readyz` — readiness (ping DB + dependency ที่ขาดไม่ได้) → LB route traffic เมื่อพร้อมจริง
- dependency ที่ degrade ได้ (Redis cache) **ไม่** ทำให้ readiness fail

### Graceful shutdown
ทุก service drain in-flight request บน SIGINT/SIGTERM (timeout 10s) — pattern ใน [`main.go`](services/catalog/cmd/main.go)

## 5. Event catalog

| Topic | Producer | Consumers | Payload (key fields) |
| ----- | -------- | --------- | -------------------- |
| `order.created` | order | catalog | order_id, items[], total |
| `stock.reserved` | catalog | payment, order | order_id, reservation_id |
| `stock.rejected` | catalog | order | order_id, reason |
| `payment.completed` | payment | order, catalog | order_id, payment_id |
| `payment.failed` | payment | order, catalog | order_id, reason |

- Schema = versioned Go struct ใน `pkg/events`
- ทุก event มี `event_id`, `occurred_at`, `order_id` (partition key → คง ordering ต่อ order)
- กฎการเปลี่ยน schema: [`rules.md`](rules.md) R3.2–R3.4

## 6. Data model (ย่อ — จาก migrations)

- **Identity:** `users`, `user_roles`, `refresh_tokens`, `addresses` + `audit_log` (มี `attach_standard_triggers()`)
- **Catalog:** `products` → `product_variants` → `inventory`; option modeling: `product_options`, `option_values`, `variant_option_values`
- **Order:** `orders` → `sub_orders` (แตกตาม vendor) → `order_items`; `carts` → `cart_items`; `shipments`, `shipment_items`, `shipment_events`; `coupons`, `coupon_usages`
- **Payment:** `payments`, `refunds`, `vendor_payouts`, `payment_idempotency_keys`
- **Messaging (ต่อ service):** `outbox`, `processed_events`
- PK ใช้ UUID v7 (`uuid_generate_v7()`) — time-ordered

## 7. Design patterns ที่ยึด

**Core (มีอยู่แล้ว):** Repository · Unit of Work · Saga (Choreography) · Outbox · Idempotent Consumer
**Idiomatic Go:** Functional Options · Strategy (เช่น payment method) · Decorator/Middleware · Adapter · Composition
**Situational (ใส่เมื่อเจอ pain จริง — YAGNI):** Circuit Breaker/Retry · CQRS · Event Sourcing · DTO/Mapper
รายละเอียดแต่ละตัว + ตัวอย่างโค้ดจริง → [`docs/patterns/`](docs/patterns/README.md)

## 8. Deployment (k8s — [`infra/k8s/`](infra/k8s/README.md))

แต่ละ service มี **Deployment + Service + HPA + PDB**; Postgres เป็น **StatefulSet** ต่อ service;
config ผ่าน **ConfigMap** + secret ผ่าน **Secret**; **Ingress** route ไป 3 backend service.
scaling strategy (PgBouncer, HPA, Redis, bottleneck) → [`docs/SCALING.md`](docs/SCALING.md)
