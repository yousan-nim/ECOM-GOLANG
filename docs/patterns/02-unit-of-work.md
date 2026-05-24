# 02 · Unit of Work (Transaction Manager)

> รวมหลาย write ให้ commit หรือ rollback เป็นหน่วยเดียว — หัวใจของ Outbox

## ปัญหาที่แก้

ตอน checkout เราต้องเขียน 2 อย่างพร้อมกัน:
1. `orders` (business data)
2. `outbox` (event ที่จะส่งเข้า Kafka)

ถ้าเขียนแยก transaction แล้วตัวที่สองพัง → ข้อมูลไม่ตรงกัน, saga ค้าง
ทั้งคู่ต้อง **commit พร้อมกัน หรือ rollback พร้อมกัน**

## วิธีทำใน Go

ส่ง `tx` ผ่าน closure — เป็น pattern ที่ idiomatic ที่สุด:

```go
// pkg ... transaction manager
type UoW struct{ db *gorm.DB }

func (u *UoW) Do(ctx context.Context, fn func(tx *gorm.DB) error) error {
    return u.db.WithContext(ctx).Transaction(fn)   // GORM rollback อัตโนมัติถ้า fn คืน error
}
```

repo รองรับ tx ด้วย method `WithTx`:

```go
func (r *GormOrderRepo) WithTx(tx *gorm.DB) *GormOrderRepo { return &GormOrderRepo{tx} }
```

ใช้งานใน service:

```go
err := uow.Do(ctx, func(tx *gorm.DB) error {
    if err := orderRepo.WithTx(tx).Save(ctx, order); err != nil {
        return err
    }
    return outbox.WithTx(tx).Add(ctx, OrderCreatedEvent(order))  // commit คู่กัน
})
```

## ใช้ที่ไหนในโปรเจกต์เรา

- order: สร้าง order + `order.created`
- catalog: reserve stock + `stock.reserved`
- payment: บันทึก payment + `payment.completed`

ทุกที่ที่ "เปลี่ยน state แล้วต้องยิง event" = ใช้ UoW เสมอ

## ข้อควรระวัง

- **อย่าทำ I/O ภายนอก (เรียก HTTP/publish Kafka จริง) ใน transaction** — ให้เขียนลง outbox แล้วให้ relay ส่งทีหลัง
- ระวัง transaction ค้างนาน → lock DB
- อย่าซ้อน transaction มั่ว ๆ; ส่ง `tx` ที่มีอยู่ลงไปแทนการเปิดใหม่

## เกี่ยวข้อง
[Outbox](04-outbox.md) · [Repository](01-repository.md)
