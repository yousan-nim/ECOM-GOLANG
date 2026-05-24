# 04 · Transactional Outbox

> รับประกันว่า event ออกจากระบบแน่นอน โดยทำให้ "เขียน DB" กับ "ส่ง event" เป็น atomic

## ปัญหาที่แก้

```go
db.Save(order)        // ✅ commit แล้ว
kafka.Publish(event)  // ❌ ถ้าพังตรงนี้ → order ถูกสร้าง แต่ไม่มีใครรู้ → saga ค้างถาวร
```
"commit DB แล้วค่อย publish" **ไม่ atomic** — dual write problem

## วิธีทำใน Go

### 1. เขียน business data + outbox ใน transaction เดียว (ดู [UoW](02-unit-of-work.md))

```sql
CREATE TABLE outbox (
    id           UUID PRIMARY KEY,
    aggregate_id TEXT NOT NULL,        -- = order_id (ใช้เป็น Kafka key)
    topic        TEXT NOT NULL,
    payload      JSONB NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at      TIMESTAMPTZ           -- NULL = ยังไม่ส่ง
);
```

### 2. Relay (background worker) อ่าน row ที่ยังไม่ส่ง → publish → mark sent

```go
func (r *Relay) tick(ctx context.Context) error {
    rows, _ := r.repo.FetchUnsent(ctx, 100)        // ORDER BY created_at, FOR UPDATE SKIP LOCKED
    for _, m := range rows {
        if err := r.producer.Publish(ctx, m.Topic, m.AggregateID, m.Payload); err != nil {
            return err                              // ลองใหม่รอบหน้า
        }
        r.repo.MarkSent(ctx, m.ID)
    }
    return nil
}
```

เรียก `tick` เป็นรอบ ๆ (polling) — เริ่มต้นพอแล้ว; ถ้าต้องการ low-latency ค่อยขยับไป CDC (Debezium)

## ใช้ที่ไหนในโปรเจกต์เรา

อยู่ใน `pkg/kafka` (relay + outbox repo ใช้ร่วม) — ทั้ง 3 service มีตาราง `outbox` ของตัวเอง

## ข้อควรระวัง

- relay ส่งแบบ **at-least-once** → consumer ต้อง [idempotent](05-idempotent-consumer.md)
- ใช้ `FOR UPDATE SKIP LOCKED` กัน relay หลาย instance ส่ง row ซ้ำ
- ใส่ index บน `sent_at` (partial: `WHERE sent_at IS NULL`)
- มี job ลบ row เก่าที่ส่งแล้ว (retention)

## เกี่ยวข้อง
[Unit of Work](02-unit-of-work.md) · [Saga](03-saga-choreography.md) · [Idempotent Consumer](05-idempotent-consumer.md)
