# 12 · CQRS (Command Query Responsibility Segregation)

> แยกโมเดลฝั่งเขียน (command) ออกจากฝั่งอ่าน (query)

> **สถานะ: ยังไม่ต้องใช้ตอนนี้** — บันทึกไว้เป็นองค์ความรู้ เผื่ออนาคต

## ปัญหาที่แก้

เมื่อ pattern การอ่านกับการเขียนต่างกันมาก:
- เขียน: ต้อง validate, business rule, normalize
- อ่าน: ต้องการ join หลายตาราง / view ที่ denormalize เพื่อความเร็ว (เช่น หน้า dashboard, รายงาน)

ถ้าใช้ model เดียวกันทั้งคู่ → model บวมและประนีประนอมทั้งสองด้าน

## วิธีทำใน Go (ระดับเบา)

ไม่จำเป็นต้องแยก DB — แค่แยก "เส้นทางโค้ด":

```go
// command side — ผ่าน domain + repository + business rule
type OrderCommandService struct{ repo OrderRepo; uow *UoW }
func (s *OrderCommandService) Place(ctx, cmd PlaceOrder) error { ... }

// query side — อ่านตรงเป็น read model / DTO ไม่ต้องผ่าน domain
type OrderQueryService struct{ db *gorm.DB }
func (q *OrderQueryService) ListForUser(ctx, userID string) ([]OrderListItem, error) {
    // SELECT แบบ projection เฉพาะ field ที่ UI ใช้ — ข้าม domain model
}
```

ระดับหนัก (ค่อยทำถ้าจำเป็นจริง): แยก read DB / materialized view ที่อัปเดตจาก event

## เมื่อไหร่ถึงควรใช้ในโปรเจกต์เรา

- หน้า report/analytics ที่ query หนักจนกระทบ write path
- read traffic สูงกว่า write มาก ๆ จนต้อง scale แยก

**ตอนนี้:** ใช้ service เดียวอ่าน-เขียนไปก่อน อย่าเพิ่ง over-engineer

## ข้อควรระวัง

- CQRS เพิ่มความซับซ้อนเยอะ — ใส่เมื่อมี pain จริงเท่านั้น
- ถ้าแยก read store จะเกิด eventual consistency (read อาจตามหลัง write)
- มักถูกเข้าใจผิดว่าต้องมาคู่ Event Sourcing — **ไม่จำเป็น**

## เกี่ยวข้อง
[Event Sourcing](13-event-sourcing.md) · [DTO/Mapper](14-dto-mapper.md)
