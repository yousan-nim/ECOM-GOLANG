# 15 · Anti-patterns — GoF/OOP ที่ "อย่า" ลากมาใช้ใน Go

> pattern ที่ดีในภาษา OOP แต่กลายเป็นภาระเมื่อเอามาใช้ใน Go

## 1. Singleton / Global state

```go
var DB *gorm.DB   // ❌ global — test ยาก, ผูก lifecycle, ซ่อน dependency
func init() { DB = connect() }
```
**แทนด้วย:** ฉีด dependency ผ่าน constructor ที่ `cmd/main.go` (composition root)
ดู [Composition](10-composition-embedding.md), ARCHITECTURE §3

## 2. Inheritance hierarchy ลึก ๆ

Go ไม่มี inheritance — อย่าพยายามเลียนแบบด้วย embedding ซ้อน 3-4 ชั้น
**แทนด้วย:** composition + interface เล็ก ๆ → [10](10-composition-embedding.md)

## 3. Interface ยักษ์ / interface ที่ implementation ประกาศเอง

```go
// ❌ interface 15 method ประกาศข้าง implementation แบบ Java
type OrderService interface { /* method เพียบ */ }
```
**แทนด้วย:** interface เล็ก (1-3 method) ประกาศ **ฝั่งคนใช้**
> "The bigger the interface, the weaker the abstraction." — Rob Pike

## 4. Abstract Factory / Factory ซ้อนหลายชั้น

**แทนด้วย:** constructor function ธรรมดา `NewXxx(...)`; ถ้ามี option ใช้ [Functional Options](06-functional-options.md)

## 5. Builder pattern แบบ Java (`.SetX().SetY().Build()`)

**แทนด้วย:** [Functional Options](06-functional-options.md) — idiomatic กว่ามากใน Go

## 6. Over-engineering ตั้งแต่ day 1

ใส่ CQRS / Event Sourcing / microservice ย่อยเต็มไปหมดก่อนเจอ pain จริง
**แทนด้วย:** เริ่มเรียบง่าย เพิ่ม abstraction เมื่อมีเหตุผลรองรับ (YAGNI)

## 7. `panic` แทน error / กลืน error

```go
if err != nil { panic(err) }      // ❌
result, _ := doThing()            // ❌ กลืน error
```
**แทนด้วย:** คืน `error`, wrap ด้วย `%w`, จัดการที่ขอบ (handler). `panic` ใช้เฉพาะ programmer error จริง ๆ

## 8. ใช้ `interface{}` / `any` พร่ำเพรื่อ

ทำให้เสีย type safety ของ Go
**แทนด้วย:** type ที่ชัดเจน หรือ generics (Go 1.18+) เมื่อจำเป็น

## 9. goroutine ที่ไม่มีทางจบ / ไม่ผูก context

```go
go worker()   // ❌ leak — ไม่มีทางสั่งหยุด
```
**แทนด้วย:** ส่ง `context.Context` เข้าไป, ใช้ `errgroup`, จัดการ graceful shutdown (ARCHITECTURE §5)

## 10. ปล่อย vendor SDK / GORM / Gin รั่วเข้า domain

**แทนด้วย:** [Adapter](09-adapter.md) + [Repository](01-repository.md) + [DTO/Mapper](14-dto-mapper.md)

---

**สรุปหลักคิด:** Go ชอบความเรียบง่ายและชัดเจน — *"Clear is better than clever."*
pattern มีไว้แก้ปัญหาที่เกิดจริง ไม่ใช่ใส่เพื่อให้ดูเป็นมืออาชีพ
