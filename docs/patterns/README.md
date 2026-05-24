# Design Patterns — Knowledge Base

คลัง pattern ที่ใช้ในโปรเจกต์ ECOM-GOLANG จัดกลุ่มตามบทบาท แต่ละไฟล์อธิบาย:
**ปัญหาที่แก้ → วิธีทำใน Go → ใช้ที่ไหนในโปรเจกต์เรา → ข้อควรระวัง**

โค้ดตัวอย่างทั้งหมดอิงสถาปัตยกรรมจริงของเรา — ดู [../ARCHITECTURE.md](../ARCHITECTURE.md)
(Monorepo + go.work · Gin · GORM · Kafka/Redpanda · choreography saga · JWT ต่อ service)

## A. Core — กระดูกสันหลังของระบบ (ต้องมี)

| # | Pattern | สรุป |
| - | ------- | ---- |
| 01 | [Repository](01-repository.md) | แยก persistence ออกจาก business logic |
| 02 | [Unit of Work](02-unit-of-work.md) | รวมหลาย write ให้ commit/rollback เป็นหน่วยเดียว |
| 03 | [Saga (Choreography)](03-saga-choreography.md) | distributed transaction ผ่าน event ไม่มี orchestrator |
| 04 | [Transactional Outbox](04-outbox.md) | รับประกัน event ออกจากระบบแน่นอน (atomic กับ DB) |
| 05 | [Idempotent Consumer](05-idempotent-consumer.md) | consume ซ้ำได้ไม่พัง (at-least-once) |

## B. Idiomatic Go — มาแทน GoF แบบเดิม

| # | Pattern | สรุป |
| - | ------- | ---- |
| 06 | [Functional Options](06-functional-options.md) | constructor ที่มี option ไม่บังคับ — แทน Builder |
| 07 | [Strategy](07-strategy.md) | สลับ algorithm ผ่าน interface / ฟังก์ชัน — เช่น payment method |
| 08 | [Decorator / Middleware](08-decorator-middleware.md) | ห่อ cross-cutting concern (log, metric, retry) |
| 09 | [Adapter](09-adapter.md) | ห่อ SDK ภายนอกด้วย interface ของเราเอง |
| 10 | [Composition / Embedding](10-composition-embedding.md) | แทน inheritance |

## C. Situational — ใช้เมื่อจำเป็น อย่าใส่ตั้งแต่ day 1

| # | Pattern | ใช้เมื่อ |
| - | ------- | ------- |
| 11 | [Circuit Breaker / Retry](11-circuit-breaker-retry.md) | เรียก external / broker ที่อาจล่ม |
| 12 | [CQRS](12-cqrs.md) | read กับ write โตคนละทิศ |
| 13 | [Event Sourcing](13-event-sourcing.md) | ต้องการ audit/replay เต็มรูปแบบ |
| 14 | [DTO / Mapper](14-dto-mapper.md) | แยก API model ↔ domain ↔ DB model |

## D. Anti-patterns

| # | เอกสาร | สรุป |
| - | ------ | ---- |
| 15 | [Anti-patterns](15-anti-patterns.md) | GoF/OOP ที่ "อย่า" ลากมาใช้ใน Go |

---

**หลักคิดรวม:** เริ่มเรียบง่าย เพิ่ม abstraction เมื่อเจอ pain จริง —
"the bigger the interface, the weaker the abstraction"
