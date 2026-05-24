# 05 · Idempotent Consumer

> consume event เดิมซ้ำกี่ครั้งก็ได้ผลเหมือนเดิม — เพราะ Kafka/Outbox เป็น at-least-once

## ปัญหาที่แก้

Kafka รับประกัน "อย่างน้อยหนึ่งครั้ง" (at-least-once) ไม่ใช่ "ครั้งเดียวเป๊ะ"
event ใบเดิมอาจถูกส่งซ้ำได้ (relay retry, rebalance, offset ยังไม่ commit)
ถ้า payment consume `stock.reserved` ซ้ำ → ตัดเงิน 2 รอบ = หายนะ

## วิธีทำใน Go

### วิธีหลัก: dedup ด้วย `event_id`

```sql
CREATE TABLE processed_events (
    event_id   UUID PRIMARY KEY,
    consumer   TEXT NOT NULL,
    handled_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

```go
func (c *Consumer) Handle(ctx context.Context, evt Event) error {
    return c.uow.Do(ctx, func(tx *gorm.DB) error {
        // INSERT ... ON CONFLICT DO NOTHING — ถ้าเคยทำแล้วจะ insert ไม่ติด
        ins, err := c.seen.WithTx(tx).Mark(ctx, evt.ID, "payment")
        if err != nil { return err }
        if !ins {
            return nil                  // เคยประมวลผลแล้ว → ข้าม
        }
        return c.process(ctx, tx, evt)  // ทำงานจริง + mark อยู่ transaction เดียวกัน
    })
}
```

ความสำคัญ: **mark + business logic อยู่ transaction เดียว** (UoW) — กันกรณี process สำเร็จแต่ mark พัง

### เสริม: ออกแบบ operation ให้ idempotent โดยธรรมชาติ

`UPDATE orders SET status='CONFIRMED' WHERE id=? AND status='PENDING'` → รันซ้ำก็ปลอดภัย

## ใช้ที่ไหนในโปรเจกต์เรา

ทุก consumer ใน `internal/consumer/` ของทั้ง 3 service ผ่าน helper กลางใน `pkg/kafka`

## ข้อควรระวัง

- ทุก event ต้องมี `event_id` ที่ producer สร้าง (UUID) — ไม่ใช่ generate ตอน consume
- commit Kafka offset **หลัง** business logic + mark สำเร็จเท่านั้น
- มี retention ลบ `processed_events` เก่า
- ใช้คู่กับ Outbox เสมอ (at-least-once ทั้งสองฝั่ง)

## เกี่ยวข้อง
[Outbox](04-outbox.md) · [Saga](03-saga-choreography.md) · [Unit of Work](02-unit-of-work.md)
