# 14 · DTO / Mapper

> แยก 3 โมเดลออกจากกัน: API model ↔ Domain model ↔ Persistence (GORM) model

> **สถานะ: ควรมี** — ป้องกัน coupling ที่มองไม่เห็นตั้งแต่แรก

## ปัญหาที่แก้

ถ้าใช้ struct ตัวเดียวเป็นทั้ง JSON request, domain, และ GORM model:

```go
type Order struct {
    ID        string `json:"id" gorm:"primaryKey"`
    UserID    string `json:"user_id"`
    Internal  string `json:"-" gorm:"column:internal_note"`   // ❌ ปนกันมั่ว
}
```
- เปลี่ยน schema DB → กระทบ API contract
- เผลอ expose field ภายในออก JSON
- GORM tag ปนกับ JSON tag ปนกับ validation

## วิธีทำใน Go

แยก 3 ชั้น + mapper แปลงระหว่างกัน:

```go
// handler/dto.go — API contract (JSON + validation)
type CreateOrderReq struct {
    Items []struct {
        SKU string `json:"sku" binding:"required"`
        Qty int    `json:"qty" binding:"required,gt=0"`
    } `json:"items" binding:"required,min=1"`
}
type OrderRes struct {
    ID     string `json:"id"`
    Status string `json:"status"`
}

// service/order.go — domain model (ไม่มี tag ของ framework เลย)
type Order struct {
    ID     string
    UserID string
    Items  []Item
    Status Status
}

// repository/model.go — persistence (GORM)
type orderRow struct {
    ID     string `gorm:"primaryKey"`
    UserID string `gorm:"index"`
    Status string
}

// mapper
func toDomain(r orderRow) *Order { ... }
func toRow(o *Order) orderRow    { ... }
func toRes(o *Order) OrderRes    { ... }
```

## ใช้ที่ไหนในโปรเจกต์เรา

ทุก service: `handler` (DTO) ↔ `service` (domain) ↔ `repository` (row)
event payload ใน `pkg/events` ก็เป็น DTO อีกชนิด (contract ระหว่าง service)

## ข้อควรระวัง

- mapper เพิ่ม boilerplate — ยอมรับได้ เพราะแลกกับ decoupling; ถ้าโมเดลเล็กมากในช่วงแรกจะรวม domain+row ก็พอรับได้ แต่ **API DTO ควรแยกเสมอ**
- อย่าให้ GORM model หรือ domain model หลุดออกไปเป็น JSON response ตรง ๆ
- validation อยู่ที่ DTO (binding tag) ส่วน business rule อยู่ที่ domain

## เกี่ยวข้อง
[Repository](01-repository.md) · [Adapter](09-adapter.md) · [CQRS](12-cqrs.md)
