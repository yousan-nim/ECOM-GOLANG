# 13 · Event Sourcing

> เก็บ "ลำดับเหตุการณ์ทั้งหมด" เป็นแหล่งความจริง แทนที่จะเก็บแค่ state ปัจจุบัน

> **สถานะ: ยังไม่ใช้** — choreography + outbox ของเราเพียงพอแล้ว บันทึกไว้เป็นองค์ความรู้

## แนวคิด

แทนที่จะเก็บ `orders.status = CONFIRMED` (state ปัจจุบัน)
เก็บลำดับเหตุการณ์ทั้งหมด แล้ว "เล่นซ้ำ" เพื่อสร้าง state:

```
OrderPlaced → StockReserved → PaymentCompleted → OrderConfirmed
(state ปัจจุบัน = ผลลัพธ์จากการ replay event ทั้งหมด)
```

## ข้อดี / ข้อเสีย

| ข้อดี | ข้อเสีย |
| ----- | ------- |
| audit trail สมบูรณ์ (รู้ทุกการเปลี่ยนแปลง) | ซับซ้อนสูงมาก |
| replay / time-travel / debug ย้อนหลังได้ | query state ปัจจุบันยาก (ต้อง projection) |
| สร้าง read model ใหม่จาก event เดิมได้ | schema/versioning ของ event ยุ่งยาก |

## ทำไมเรา "ยังไม่ใช้"

- ระบบเราเก็บ **current state ใน DB** (orders/products/payments) + ใช้ event เพื่อ "สื่อสาร" เท่านั้น
- ความต้องการ audit ระดับที่เรามี → ใช้ตาราง history / outbox log ก็พอ
- Event Sourcing คนละเรื่องกับ "การส่ง event ผ่าน Kafka" — เราทำแค่อย่างหลัง

## ถ้าวันหนึ่งจะใช้

- เริ่มจาก aggregate ที่ต้องการ audit สูงสุด (เช่น `payment`) เท่านั้น ไม่ใช่ทั้งระบบ
- ต้องมี event store + snapshot + projection
- พิจารณาคู่กับ [CQRS](12-cqrs.md) (read model แยก)

## ข้อควรระวัง

- เป็น pattern ที่ "ถอยกลับยาก" — คิดให้รอบคอบก่อนรับมาทั้งระบบ
- อย่าสับสน: outbox = ส่ง event ออก ≠ event sourcing = ใช้ event เป็น source of truth

## เกี่ยวข้อง
[Saga](03-saga-choreography.md) · [Outbox](04-outbox.md) · [CQRS](12-cqrs.md)
