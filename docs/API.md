# API — REST endpoints

> สเปก HTTP API ของทั้ง 3 service ผ่าน gateway เดียว
> **สถานะ:** health + envelope = **implemented**; business endpoints = **target/planned**
> (ยัง scaffold — ดู [`../AGENTS.md`](../AGENTS.md)) ทำ endpoint ใหม่ให้ตรงสเปกนี้
> Related: [`ARCHITECTURE.md`](ARCHITECTURE.md) · [`EVENTS.md`](EVENTS.md) · [`../design.md`](../design.md)

## 1. Base URL & routing

ทุก request ผ่าน **nginx gateway** `:8080` แล้ว route ตาม path prefix:

| Prefix | Service | Port |
| ------ | ------- | ---- |
| `/catalog/*` | catalog-service | 8081 |
| `/order/*` | order-service | 8082 |
| `/payment/*` | payment-service | 8083 |

Local: `http://localhost:8080` · k8s: ผ่าน Ingress (ดู [`DEPLOYMENT.md`](DEPLOYMENT.md))

## 2. Conventions

- **Content-Type:** `application/json`
- **จำนวนเงิน:** integer **หน่วยย่อยที่สุด** (สตางค์) เสมอ — ไม่ใช่ทศนิยม (ตรงกับ DB `BIGINT`)
- **Currency:** ISO-4217 3 ตัว (`THB`, `USD`)
- **ID สาธารณะ:** ใช้ `public_id` (UUID v7) ใน API เสมอ — ไม่ expose `BIGSERIAL` ภายใน
- **Timestamp:** RFC 3339 / ISO-8601 UTC
- **Idempotency:** endpoint ที่สร้าง resource (โดยเฉพาะ payment) รับ header `Idempotency-Key`

## 3. Authentication

- ส่ง `Authorization: Bearer <JWT>` — verify ที่แต่ละ service ผ่าน [`pkg/auth`](../pkg/auth) middleware (signature + expiry)
- claim ที่ inject เข้า context: user id, roles
- endpoint สาธารณะ (browse catalog, guest checkout) ไม่ต้องมี token; endpoint จัดการ order/payment ต้องมี
- gateway **ยังไม่** verify auth — service ตรวจเอง (ดู ARCHITECTURE §8)

## 4. Error envelope (implemented — [`pkg/httpx`](../pkg/httpx/httpx.go))

ทุก error ตอบรูปแบบเดียว — **ห้ามเขียน error JSON เอง** ใช้ `httpx.Fail`:

```json
{ "error": { "code": "stock_insufficient", "message": "not enough stock for SKU-123" } }
```

| HTTP | ใช้เมื่อ | ตัวอย่าง `code` |
| ---- | ------- | -------------- |
| 400 | input ไม่ถูกต้อง | `invalid_request`, `validation_failed` |
| 401 | ไม่มี/หมดอายุ token | `unauthorized` |
| 403 | ไม่มีสิทธิ์ | `forbidden` |
| 404 | ไม่พบ resource | `not_found` |
| 409 | ขัดแย้ง state | `stock_insufficient`, `duplicate_order` |
| 422 | ธุรกิจปฏิเสธ | `payment_declined` |
| 503 | dependency ล่ม | `db_unavailable` |

## 5. Health (implemented — ทุก service)

| Method | Path | ความหมาย |
| ------ | ---- | -------- |
| GET | `/healthz` | liveness — process ขึ้นไหม (ไม่แตะ DB) |
| GET | `/readyz` | readiness — ping DB (+ dependency ที่ขาดไม่ได้); LB route เมื่อ ready |

## 6. Endpoints (target — จัดกลุ่มตาม service)

> ยังไม่ implement — เป็น contract เป้าหมาย เพิ่มจริงแล้วอัปเดตตารางนี้ + สร้าง OpenAPI

### catalog-service `/catalog`
| Method | Path | คำอธิบาย | Auth |
| ------ | ---- | -------- | ---- |
| GET | `/catalog/products` | list/search (paginate, filter) | – |
| GET | `/catalog/products/{public_id}` | รายละเอียด + variants + stock | – |
| GET | `/catalog/categories` | หมวดหมู่ | – |
| POST | `/catalog/products` | สร้างสินค้า (vendor/admin) | ✔ |
| PATCH | `/catalog/products/{public_id}` | แก้ไข | ✔ |
| GET | `/catalog/vendors/{public_id}` | ข้อมูล vendor | – |

### order-service `/order`
| Method | Path | คำอธิบาย | Auth |
| ------ | ---- | -------- | ---- |
| GET | `/order/cart` | ดูตะกร้า | ✔ |
| POST | `/order/cart/items` | เพิ่มสินค้าลงตะกร้า | ✔ |
| DELETE | `/order/cart/items/{id}` | ลบออกจากตะกร้า | ✔ |
| POST | `/order/orders` | **checkout** → เริ่ม saga (emit `order.created`) | ✔ |
| GET | `/order/orders` | ประวัติ order ของผู้ใช้ | ✔ |
| GET | `/order/orders/{public_id}` | สถานะ order + sub-orders | ✔ |
| POST | `/order/orders/{public_id}/cancel` | ยกเลิก (ถ้า state อนุญาต) | ✔ |

### payment-service `/payment`
| Method | Path | คำอธิบาย | Auth |
| ------ | ---- | -------- | ---- |
| POST | `/payment/payments` | สร้าง payment (ใช้ `Idempotency-Key`) | ✔ |
| GET | `/payment/payments/{public_id}` | สถานะ payment | ✔ |
| POST | `/payment/payments/{public_id}/refund` | ขอคืนเงิน | ✔ |
| POST | `/payment/webhooks/{provider}` | callback จาก provider (STRIPE/OMISE/…) | signature |

## 7. OpenAPI / Swagger

ยังไม่มีไฟล์สเปก — เมื่อ implement endpoint แนะนำ generate `docs/openapi.yaml`
(เช่น `swaggo/swag` จาก annotation ใน handler) แล้ว serve ที่ `/swagger` ต่อ service
