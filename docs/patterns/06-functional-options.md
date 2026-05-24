# 06 · Functional Options

> constructor ที่มี option ไม่บังคับ — pattern เอกลักษณ์ของ Go ที่มาแทน Builder / telescoping constructor

## ปัญหาที่แก้

constructor ที่พารามเยอะและส่วนใหญ่ไม่บังคับ:

```go
NewProducer(brokers, 5, 3*time.Second, true, nil)  // ❌ อ่านไม่รู้เรื่องว่าอะไรคืออะไร
```
- เติม param ใหม่ = break ทุกที่ที่เรียก
- ค่า default ไม่ชัด

## วิธีทำใน Go

```go
type Producer struct {
    brokers []string
    retries int
    timeout time.Duration
}

type Option func(*Producer)

func WithRetries(n int) Option       { return func(p *Producer) { p.retries = n } }
func WithTimeout(d time.Duration) Option { return func(p *Producer) { p.timeout = d } }

func NewProducer(brokers []string, opts ...Option) *Producer {
    p := &Producer{brokers: brokers, retries: 3, timeout: 5 * time.Second} // defaults
    for _, opt := range opts {
        opt(p)
    }
    return p
}
```

ใช้งาน — อ่านออกทันที, ใส่เฉพาะที่อยากเปลี่ยน:

```go
NewProducer(brokers)                                  // ใช้ default
NewProducer(brokers, WithRetries(5), WithTimeout(2*time.Second))
```

## ใช้ที่ไหนในโปรเจกต์เรา

- `pkg/kafka` — producer/consumer config (retries, batch, acks)
- HTTP server / client wrapper (timeout, middleware)
- ที่ใดก็ตามที่ constructor มี option > 2 ตัวและไม่บังคับ

## ข้อควรระวัง

- **อย่าใช้เกินจำเป็น** — ถ้ามี field บังคับ 1-2 ตัว ส่งเป็น param ตรง ๆ ดีกว่า
- อย่าเอามาแทน required dependency (DB, logger) — พวกนั้นต้องเป็น param ที่บังคับ
- จะ validate ก็ทำหลัง apply opts เสร็จ (คืน `error` ได้ถ้าจำเป็น)

## เกี่ยวข้อง
[Adapter](09-adapter.md) · [Anti-patterns](15-anti-patterns.md) (Builder ที่ไม่ควรใช้)
