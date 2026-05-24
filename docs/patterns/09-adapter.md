# 09 · Adapter

> ห่อ SDK / ระบบภายนอกด้วย interface ของเราเอง — กันไม่ให้ vendor รั่วเข้า domain

## ปัญหาที่แก้

ถ้า service เรียก SDK ของ Kafka / payment gateway ตรง ๆ:
- domain ผูกติด vendor → เปลี่ยนเจ้าทีแก้ทั้งระบบ
- mock ใน test ยาก (type ของ SDK ควบคุมไม่ได้)
- API ของ SDK เปลี่ยน = พังกระจาย

## วิธีทำใน Go

นิยาม interface ตาม "ภาษาของ domain เรา" แล้วให้ adapter แปลงไป SDK:

```go
// pkg/events — ภาษาของเรา (domain ไม่รู้จัก Kafka)
type Publisher interface {
    Publish(ctx context.Context, topic, key string, payload []byte) error
}

// pkg/kafka — adapter ที่ห่อ SDK จริง (เช่น franz-go / segmentio/kafka-go)
type KafkaPublisher struct{ w *kgo.Client }

func (k *KafkaPublisher) Publish(ctx context.Context, topic, key string, payload []byte) error {
    rec := &kgo.Record{Topic: topic, Key: []byte(key), Value: payload}
    return k.w.ProduceSync(ctx, rec).FirstErr()   // รายละเอียดของ SDK ถูกซ่อนไว้ในนี้
}
```

payment gateway ก็ทำแบบเดียวกัน:

```go
type CardGateway interface {
    Charge(ctx context.Context, req ChargeReq) (ChargeResp, error)
}
// StripeAdapter / OmiseAdapter / FakeGateway(สำหรับ test) ต่าง implement อันนี้
```

## ใช้ที่ไหนในโปรเจกต์เรา

- `pkg/kafka` — ห่อ Kafka client
- payment-service — ห่อ payment gateway แต่ละเจ้า
- ทุก external HTTP client / object storage / email ฯลฯ

## ข้อควรระวัง

- interface ควรเป็น "ภาษาเรา" ไม่ใช่ copy หน้าตา SDK มาตรง ๆ
- ใส่ adapter ปลอม (fake/stub) ไว้ test
- อย่าให้ type ของ SDK (เช่น `kgo.Record`) โผล่ใน signature ของ interface

## เกี่ยวข้อง
[Strategy](07-strategy.md) · [Decorator](08-decorator-middleware.md) · [Repository](01-repository.md)
