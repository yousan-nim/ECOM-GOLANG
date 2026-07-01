# DATABASE — Schema & migrations

> Database-per-Service: **3 Postgres instance แยกกัน ไม่แชร์ตาราง**
> Related: [`ARCHITECTURE.md`](ARCHITECTURE.md) · [`../design.md`](../design.md) §6 · [`EVENTS.md`](EVENTS.md) (outbox/processed_events)

## 1. หลักการออกแบบ (ยึดทั้งระบบ)

- **1 service = 1 database** — ห้าม service ข้ามไปแตะ DB ของ service อื่น (สื่อสารผ่าน event เท่านั้น — [`../rules.md`](../rules.md) R1.1)
- **ไม่มี cross-service FK** — reference ข้าม service ใช้ `UUID` (soft ref) + **snapshot field** (เก็บค่า ณ เวลานั้น เช่น `vendor_name`, `order_number`, `customer_email`)
- **ID สองชั้น:** `id BIGSERIAL` (ใช้ภายใน/FK ในบริการเดียวกัน) + `public_id UUID` v7 (expose ออก API, time-ordered)
- **เงินเป็น integer:** `BIGINT` หน่วยย่อยที่สุด (สตางค์) + `currency CHAR(3)` — ไม่มี float
- **Optimistic locking:** คอลัมน์ `version BIGINT` บนตารางที่แก้บ่อย
- **Audit:** `attach_standard_triggers()` / `audit_trigger_fn()` (จาก `000002_init_helpers`) ใส่ `updated_at` + audit log อัตโนมัติ
- **Enum ผ่าน CHECK constraint** ไม่ใช่ pg enum type (แก้ง่ายกว่า)
- **PostgreSQL 16**, extensions: `uuid_generate_v7()`, `CITEXT` (email case-insensitive)

## 2. Migrations

- ไฟล์ SQL อยู่ใน `services/<svc>/migrations/` (แยกต่อ service) — รูปแบบ `NNNNNN_name.up.sql` / `.down.sql`
- **Embed เข้า binary** (`MigrationsFS`) แล้วรัน **ตอน boot** ผ่าน `db.Migrate(sqlDB, FS)` — ดู [`services/catalog/cmd/main.go`](../services/catalog/cmd/main.go)
- **Forward-only:** ห้ามแก้ migration ที่ apply แล้ว — สร้างไฟล์ใหม่เสมอ ([`../rules.md`](../rules.md) R6.4)
- ทุก service เริ่มด้วย `000001_init_extensions` + `000002_init_helpers` (uuid v7, trigger helpers) เหมือนกัน

> Pending decision: `golang-migrate` (prod-grade) vs GORM `AutoMigrate` — ดู ARCHITECTURE §1

## 3. catalog_db (`postgres-catalog`)

Master data ของ platform (users/vendors อยู่ที่นี่เป็น source of truth)

| กลุ่ม | ตาราง |
| ----- | ----- |
| Identity | `users`, `user_roles`, `refresh_tokens`, `addresses` |
| Vendor | `vendors`, `commission_rates` |
| Catalog | `categories`, `products`, `product_variants`, `product_options`, `option_values`, `variant_option_values` |
| Stock | `inventory` (stock / reservation) |
| อื่น ๆ | `exchange_rates`, `audit_log` |
| Messaging | `outbox`, `processed_events` |

โครง product: `products` → `product_variants` (SKU ที่ขายได้จริง) → `inventory`;
variant modeling = `product_options` × `option_values` → `variant_option_values`

## 4. order_db (`postgres-order`)

| กลุ่ม | ตาราง |
| ----- | ----- |
| Cart | `carts`, `cart_items` |
| Order | `orders` → `sub_orders` (แตกตาม vendor) → `order_items` |
| Fulfillment | `shipments`, `shipment_items`, `shipment_events` |
| Promo | `coupons`, `coupon_usages` |
| Review | `reviews` |
| อื่น ๆ | `audit_log`, `outbox`, `processed_events` |

**`orders`** (key fields): `public_id`, `order_number` (unique), `user_public_id` (soft ref → catalog),
`status` CHECK(`PENDING_PAYMENT`/`PAID`/`FULFILLED`/`CANCELLED`/`REFUNDED`/…),
เงิน: `subtotal/discount/shipping/tax/total_amount` (BIGINT) + FX snapshot (`fx_rate_to_base`, `base_currency`),
customer snapshot (`customer_email` CITEXT, `billing_address`/`shipping_address` JSONB), `version`

**`sub_orders`** = 1 order ต่อ 1 vendor: `vendor_public_id` + `vendor_name` (snapshot),
มี `commission_bps` (0–10000) + `commission_amount`, status ของตัวเอง (`SHIPPED`/`DELIVERED`/…)

## 5. payment_db (`postgres-payment`)

| กลุ่ม | ตาราง |
| ----- | ----- |
| Payment | `payments`, `refunds` |
| Payout | `vendor_payouts` |
| Idempotency | `payment_idempotency_keys` |
| Messaging | `outbox`, `processed_events` |

**`payments`** (key fields): `order_public_id` + `order_number` (soft ref/snapshot),
`provider` CHECK(`STRIPE`/`OMISE`/`PROMPTPAY`/`TRUEMONEY`/`2C2P`/`COD`/`BANK_TRANSFER`),
`method` CHECK(`CARD`/`PROMPTPAY`/`WALLET`/…), `amount`/`fee_amount`/`net_amount` (BIGINT),
`status` CHECK(`PENDING`/`AUTHORIZED`/`CAPTURED`/`FAILED`/`REFUNDED`/…),
card snapshot (`card_brand`, `card_last4`, `card_exp_*` — **ห้ามเก็บ PAN/CVV** → [`../rules.md`](../rules.md) R2.2), `raw_response` JSONB
**`refunds`** → FK `payment_id` (ในบริการเดียวกัน), `reason` CHECK(`CUSTOMER_REQUEST`/`FRAUD`/…)

## 6. ER (ระดับ service — cross-service เป็น soft ref)

```
catalog_db:  users ─< user_roles          products ─< product_variants ─< inventory
             users ─< addresses            products ─< variant_option_values >─ option_values
             vendors ─< commission_rates

order_db:    carts ─< cart_items
             orders ─< sub_orders ─< order_items
             sub_orders ─< shipments ─< shipment_items / shipment_events
             coupons ─< coupon_usages

payment_db:  payments ─< refunds
             vendor_payouts        payment_idempotency_keys

ทุก db:      outbox        processed_events        (choreography saga — ดู EVENTS.md)
```

จุดเชื่อมข้าม service (soft ref, ไม่มี FK):
`order.user_public_id → catalog.users` · `order.sub_orders.vendor_public_id → catalog.vendors` ·
`payment.order_public_id → order.orders`
