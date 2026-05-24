# 03 · Saga (Choreography)

> distributed transaction ข้ามหลาย service ผ่าน event — แต่ละ service react เอง ไม่มีตัวกลางสั่งงาน

## ปัญหาที่แก้

checkout ต้องแตะ 3 DB ที่แยกกัน (order / catalog / payment) — ไม่มี ACID transaction ข้าม DB
ต้องการความ "ถูกต้องในที่สุด" (eventual consistency) + ยกเลิกย้อนกลับได้เมื่อมีขั้นพัง

## Choreography vs Orchestration

- **Choreography (ที่เราเลือก):** แต่ละ service ฟัง event แล้วทำงานของตัวเอง + ยิง event ถัดไป → ไม่มี single point, coupling ต่ำ
- Orchestration: มี orchestrator สั่งทีละขั้น → flow ชัดแต่ผูกศูนย์กลาง

## Flow checkout ของเรา

```
1. POST /order/orders → order: Order(PENDING) + outbox → emit order.created
2. catalog ← order.created → reserve stock
      ├─ ok       → emit stock.reserved
      └─ shortage → emit stock.rejected
3. payment ← stock.reserved → charge
      ├─ ok       → emit payment.completed
      └─ fail     → emit payment.failed
4. order   ← payment.completed → Order = CONFIRMED
   catalog ← payment.completed → commit reservation

Compensation (ย้อนกลับ):
   payment.failed → catalog release stock, order = CANCELLED
   stock.rejected → order = CANCELLED
```

## หัวใจ: Compensating action

แต่ละขั้นที่เปลี่ยน state ต้องมี "การชดเชย" คู่กันเสมอ
(reserve ↔ release · charge ↔ refund) เพราะ rollback ข้าม service ทำไม่ได้ ต้องชดเชยด้วย action ตรงข้าม

## State machine ของ order

```
PENDING → (stock.reserved + payment.completed) → CONFIRMED
PENDING → (stock.rejected | payment.failed)    → CANCELLED
```
เก็บ state ลง DB ทุกครั้ง — เป็นแหล่งความจริงของ saga

## ข้อควรระวัง

- ทุกขั้น **ต้อง idempotent** → [05](05-idempotent-consumer.md)
- ทุก event ใช้ `order_id` เป็น **partition key** → event ของ order เดียวเรียงกันเสมอ
- choreography debug ยาก → ฝัง trace_id ใน event header (ดู ARCHITECTURE §6)
- ระวัง event loop / cyclic reaction

## เกี่ยวข้อง
[Outbox](04-outbox.md) · [Idempotent Consumer](05-idempotent-consumer.md) · [Unit of Work](02-unit-of-work.md)
