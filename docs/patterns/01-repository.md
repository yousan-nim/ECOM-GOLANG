# 01 · Repository

> แยก logic การเก็บข้อมูลออกจาก business logic — service เห็นแค่ interface ไม่เห็น GORM

## ปัญหาที่แก้

ถ้า service เรียก `db.Where(...).First(...)` ตรง ๆ:
- business logic ผูกติด GORM → เปลี่ยน DB/ORM ทีต้องแก้ทั้งระบบ
- test ต้องมี Postgres จริงเสมอ
- `gorm.ErrRecordNotFound` รั่วขึ้นไปทุกชั้น

## วิธีทำใน Go

Interface ประกาศที่ **ฝั่ง service (คนใช้)** ไม่ใช่ฝั่ง implementation:

```go
// services/order/internal/service/order.go
type OrderRepo interface {
    Save(ctx context.Context, o *Order) error
    FindByID(ctx context.Context, id string) (*Order, error)
}
```

Implementation อยู่คนละ package คืน **struct** (ไม่ประกาศ interface เอง):

```go
// services/order/internal/repository/order_gorm.go
type GormOrderRepo struct{ db *gorm.DB }

func NewGormOrderRepo(db *gorm.DB) *GormOrderRepo { return &GormOrderRepo{db} }

func (r *GormOrderRepo) FindByID(ctx context.Context, id string) (*Order, error) {
    var o Order
    err := r.db.WithContext(ctx).First(&o, "id = ?", id).Error
    if errors.Is(err, gorm.ErrRecordNotFound) {
        return nil, ErrNotFound          // แปลง error ของ GORM → domain error ตรงนี้
    }
    return &o, err
}
```

## ใช้ที่ไหนในโปรเจกต์เรา

ทุก service: `internal/repository/` ทุกตัว ป้อน `*gorm.DB` เข้าทาง constructor ที่ `cmd/main.go`

## ข้อควรระวัง

- **อย่าให้ repo คืน `*gorm.DB` หรือ GORM error ดิบ** — กันรั่ว
- อย่าทำ "generic repository" ยักษ์ตัวเดียวครอบทุก entity — แยกตาม aggregate
- repo ต้องรองรับ transaction → ดู [Unit of Work](02-unit-of-work.md) (`WithTx`)

## เกี่ยวข้อง
[Unit of Work](02-unit-of-work.md) · [DTO/Mapper](14-dto-mapper.md) · [Adapter](09-adapter.md)
