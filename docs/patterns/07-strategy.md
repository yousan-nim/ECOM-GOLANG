# 07 · Strategy

> สลับ algorithm/behavior ได้ตอน runtime ผ่าน interface หรือ first-class function

## ปัญหาที่แก้

payment รองรับหลายช่องทาง (บัตรเครดิต / PromptPay / COD) แต่ละแบบ logic คนละอย่าง
ถ้าเขียนเป็น `switch method { case ... }` ก้อนใหญ่ → เพิ่มช่องทางใหม่ทีต้องแก้โค้ดเดิม (ผิด open/closed)

## วิธีทำใน Go

### แบบ interface (เมื่อ strategy มี state / หลาย method)

```go
type PaymentMethod interface {
    Charge(ctx context.Context, amount Money) (ChargeResult, error)
}

type CreditCard struct{ gw CardGateway }
func (c CreditCard) Charge(ctx context.Context, a Money) (ChargeResult, error) { ... }

type PromptPay struct{ client PPClient }
func (p PromptPay) Charge(ctx context.Context, a Money) (ChargeResult, error) { ... }
```

เลือก strategy จาก input:

```go
func (s *PaymentService) methodFor(kind string) (PaymentMethod, error) {
    m, ok := s.methods[kind]   // map[string]PaymentMethod ลงทะเบียนตอน wire ใน main.go
    if !ok { return nil, ErrUnsupportedMethod }
    return m, nil
}
```

### แบบ function (เมื่อ strategy เป็น logic ล้วน ไม่มี state)

```go
type PricingRule func(items []Item) Money
var rules = map[string]PricingRule{
    "default": defaultPrice,
    "vip":     vipPrice,
}
```

## ใช้ที่ไหนในโปรเจกต์เรา

- payment-service: payment provider แต่ละเจ้า
- catalog/order: pricing / discount rule, shipping calculation

## ข้อควรระวัง

- ลงทะเบียน strategy ที่ `cmd/main.go` (composition root) ไม่ใช่ global init
- interface เล็ก (1 method) ใช้ function ก็ได้ — ไม่ต้องสร้าง type เกินจำเป็น
- หลีกเลี่ยง `switch` ยาวที่เติมไม่จบ → นั่นคือสัญญาณว่าควรใช้ Strategy

## เกี่ยวข้อง
[Decorator](08-decorator-middleware.md) · [Adapter](09-adapter.md)
