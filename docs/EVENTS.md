# EVENTS — Event catalog & messaging

> สัญญาของ event ทั้งหมดในระบบ + วิธีรับประกันความน่าเชื่อถือ (Outbox + Idempotent Consumer)
> Related: [`ARCHITECTURE.md`](ARCHITECTURE.md) §5–7 · [`patterns/03-saga-choreography.md`](patterns/03-saga-choreography.md) ·
> [`patterns/04-outbox.md`](patterns/04-outbox.md) · [`patterns/05-idempotent-consumer.md`](patterns/05-idempotent-consumer.md)

## 1. Transport

- **Broker:** Kafka / Redpanda (`KAFKA_BROKERS`, default `redpanda:9092`)
- **Delivery:** at-least-once → **consumer ทุกตัวต้อง idempotent**
- **Partition key:** `order.public_id` (= `aggregate_id`) → event ของ order เดียวคง ordering
- **Coordination style:** choreography — ไม่มี orchestrator, แต่ละ service react แล้ว emit เอง

## 2. Event envelope

ทุก event มี field มาตรฐานเหล่านี้ (payload เฉพาะ topic อยู่ด้านล่าง):

| Field | Type | หมายเหตุ |
| ----- | ---- | -------- |
| `event_id` | UUID v7 | ใช้ dedup ที่ consumer |
| `occurred_at` | timestamptz | เวลาเกิด event |
| `order_id` | UUID | public_id ของ order = partition key |

Headers (Kafka): `trace_id` ฯลฯ (ดู `headers JSONB` ใน outbox)
Schema เป็น **versioned Go struct** — ที่ตั้งใจไว้คือ `pkg/events` (ยังไม่ถูก implement; ตอนนี้มีแค่ [`pkg/outbox/model.go`](../pkg/outbox/model.go))

## 3. Event catalog

| Topic | Producer | Consumers | Payload (key fields) | ทำให้เกิด |
| ----- | -------- | --------- | -------------------- | -------- |
| `order.created` | order | catalog | `order_id, items[], total, currency` | catalog reserve stock |
| `stock.reserved` | catalog | payment, order | `order_id, reservation_id` | payment charge |
| `stock.rejected` | catalog | order | `order_id, reason` | order → CANCELLED |
| `payment.completed` | payment | order, catalog | `order_id, payment_id` | order → CONFIRMED, catalog commit |
| `payment.failed` | payment | order, catalog | `order_id, reason` | compensation (คืน stock, cancel) |

## 4. Saga flow (checkout)

```
order   ──order.created──►  catalog
catalog ──stock.reserved──► payment   (ok)
        └─stock.rejected──► order      (shortage → CANCELLED)
payment ──payment.completed──► order + catalog   (ok → CONFIRMED + commit)
        └─payment.failed────► order + catalog     (compensation)
```

**Compensation:** `payment.failed` → catalog คืน stock + order = CANCELLED · `stock.rejected` → order = CANCELLED

## 5. Reliability — Transactional Outbox

DB write กับ Kafka publish **ไม่ atomic** → เขียน event ลงตาราง `outbox` ในทรานแซกชันเดียวกับ
business change แล้วให้ background relay ส่งไป Kafka (pattern อยู่ใน `pkg/kafka`)

**`outbox` table** (เหมือนกันทุก service — GORM model: [`pkg/outbox/model.go`](../pkg/outbox/model.go) → `Message`):

| Column | Type | หมายเหตุ |
| ------ | ---- | -------- |
| `id` | UUID v7 PK | |
| `aggregate` | TEXT | เช่น `order`, `payment` |
| `aggregate_id` | TEXT | **Kafka partition key** (มักเป็น order public_id) |
| `topic` | TEXT | ชื่อ event |
| `payload` | JSONB | body ของ event |
| `headers` | JSONB | trace_id ฯลฯ |
| `created_at` | timestamptz | |
| `sent_at` | timestamptz NULL | NULL = ยังไม่ publish |

Index: `idx_outbox_unsent (created_at) WHERE sent_at IS NULL` — relay poll แถวที่ยังไม่ส่ง เก่าสุดก่อน

### Relay loop
```
1 tx:  INSERT business rows  +  INSERT outbox row      (Unit of Work)
relay: SELECT ... WHERE sent_at IS NULL ORDER BY created_at
       → publish to Kafka → UPDATE sent_at = NOW()
```

## 6. Reliability — Idempotent Consumer

Kafka เป็น at-least-once → consumer ต้องกันประมวลซ้ำ ด้วยตาราง `processed_events`
(GORM model: `ProcessedEvent`):

| Column | Type | หมายเหตุ |
| ------ | ---- | -------- |
| `event_id` | UUID | PK ร่วม |
| `consumer` | TEXT | PK ร่วม — ตัวไหน handle |
| `handled_at` | timestamptz | |

### Consumer pattern
```
1 tx:  ทำ side effect (reserve stock / update order)
       INSERT INTO processed_events (event_id, consumer) ON CONFLICT DO NOTHING
       ถ้า INSERT ได้ 0 แถว = เคยทำแล้ว → rollback/skip (no-op)
```

## 7. เพิ่ม event ใหม่ (checklist)

1. นิยาม struct ใน `pkg/events` + **version** (ห้ามแก้ schema เดิมแบบ breaking → ดู [`../rules.md`](../rules.md) R3.2)
2. Producer: เขียน `outbox` row ในทรานแซกชันเดียวกับ business change
3. Consumer: handle แบบ idempotent ผ่าน `processed_events`
4. ใส่ `event_id`, `occurred_at`, `order_id` ครบ + `order_id` เป็น partition key
5. อัปเดตตารางใน §3 นี้ + [`ARCHITECTURE.md`](ARCHITECTURE.md) §7
