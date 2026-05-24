// Package model maps GORM structs onto the order schema.
//
// Cross-service references are soft refs (UUID `*_public_id`) with snapshot
// columns — there are NO foreign keys to catalog/payment. Order history must
// survive product changes/deletion, so item details are snapshotted.
//
// Schema is authoritative in services/order/migrations (do not AutoMigrate).
package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/datatypes"
)

// ── Cart ─────────────────────────────────────────────────────
type Cart struct {
	ID             int64      `gorm:"primaryKey"`
	PublicID       uuid.UUID  `gorm:"column:public_id"`
	UserPublicID   *uuid.UUID `gorm:"column:user_public_id"`
	AnonymousToken *string    `gorm:"column:anonymous_token"`
	Currency       string     `gorm:"column:currency"`
	Status         string     `gorm:"column:status"`
	ExpiresAt      *time.Time `gorm:"column:expires_at"`
	CreatedAt      time.Time  `gorm:"column:created_at"`
	UpdatedAt      time.Time  `gorm:"column:updated_at"`
	Version        int64      `gorm:"column:version"`

	Items []CartItem `gorm:"foreignKey:CartID"`
}

func (Cart) TableName() string { return "carts" }

type CartItem struct {
	ID              int64     `gorm:"primaryKey"`
	CartID          int64     `gorm:"column:cart_id"`
	VariantPublicID uuid.UUID `gorm:"column:variant_public_id"`
	ProductPublicID uuid.UUID `gorm:"column:product_public_id"`
	ProductName     string    `gorm:"column:product_name"`
	VariantLabel    *string   `gorm:"column:variant_label"`
	SKU             string    `gorm:"column:sku"`
	Quantity        int       `gorm:"column:quantity"`
	UnitPriceAmount int64     `gorm:"column:unit_price_amount"`
	UnitPriceCcy    string    `gorm:"column:unit_price_currency"`
	AddedAt         time.Time `gorm:"column:added_at"`
	UpdatedAt       time.Time `gorm:"column:updated_at"`
	Version         int64     `gorm:"column:version"`
}

func (CartItem) TableName() string { return "cart_items" }

// ── Order ────────────────────────────────────────────────────
type Order struct {
	ID              int64      `gorm:"primaryKey"`
	PublicID        uuid.UUID  `gorm:"column:public_id"`
	OrderNumber     string     `gorm:"column:order_number"`
	UserPublicID    *uuid.UUID `gorm:"column:user_public_id"`
	Status          string     `gorm:"column:status"`
	Currency        string     `gorm:"column:currency"`
	SubtotalAmount  int64      `gorm:"column:subtotal_amount"`
	DiscountAmount  int64      `gorm:"column:discount_amount"`
	ShippingAmount  int64      `gorm:"column:shipping_amount"`
	TaxAmount       int64      `gorm:"column:tax_amount"`
	TotalAmount     int64      `gorm:"column:total_amount"`
	CustomerEmail   string     `gorm:"column:customer_email"`
	CustomerName    string     `gorm:"column:customer_name"`
	BillingAddress  datatypes.JSON `gorm:"column:billing_address"`
	ShippingAddress datatypes.JSON `gorm:"column:shipping_address"`
	CouponCode      *string    `gorm:"column:coupon_code"`
	PlacedAt        time.Time  `gorm:"column:placed_at"`
	PaidAt          *time.Time `gorm:"column:paid_at"`
	CancelledAt     *time.Time `gorm:"column:cancelled_at"`
	CancelledReason *string    `gorm:"column:cancelled_reason"`
	CreatedAt       time.Time  `gorm:"column:created_at"`
	UpdatedAt       time.Time  `gorm:"column:updated_at"`
	Version         int64      `gorm:"column:version"`

	SubOrders []SubOrder `gorm:"foreignKey:OrderID"`
}

func (Order) TableName() string { return "orders" }

// Order status constants (mirror the CHECK constraint).
const (
	OrderPendingPayment = "PENDING_PAYMENT"
	OrderPaid           = "PAID"
	OrderFulfilled      = "FULFILLED"
	OrderCancelled      = "CANCELLED"
	OrderFailed         = "FAILED"
)

type SubOrder struct {
	ID               int64      `gorm:"primaryKey"`
	PublicID         uuid.UUID  `gorm:"column:public_id"`
	OrderID          int64      `gorm:"column:order_id"`
	VendorPublicID   uuid.UUID  `gorm:"column:vendor_public_id"`
	VendorName       string     `gorm:"column:vendor_name"`
	SubOrderNumber   string     `gorm:"column:sub_order_number"`
	Status           string     `gorm:"column:status"`
	Currency         string     `gorm:"column:currency"`
	SubtotalAmount   int64      `gorm:"column:subtotal_amount"`
	TotalAmount      int64      `gorm:"column:total_amount"`
	CommissionBps    int        `gorm:"column:commission_bps"`
	CommissionAmount int64      `gorm:"column:commission_amount"`
	VendorNetAmount  int64      `gorm:"column:vendor_net_amount"`
	PayoutPublicID   *uuid.UUID `gorm:"column:payout_public_id"`
	CreatedAt        time.Time  `gorm:"column:created_at"`
	UpdatedAt        time.Time  `gorm:"column:updated_at"`
	Version          int64      `gorm:"column:version"`

	Items []OrderItem `gorm:"foreignKey:SubOrderID"`
}

func (SubOrder) TableName() string { return "sub_orders" }

type OrderItem struct {
	ID              int64          `gorm:"primaryKey"`
	PublicID        uuid.UUID      `gorm:"column:public_id"`
	SubOrderID      int64          `gorm:"column:sub_order_id"`
	VariantPublicID uuid.UUID      `gorm:"column:variant_public_id"`
	ProductPublicID uuid.UUID      `gorm:"column:product_public_id"`
	ProductName     string         `gorm:"column:product_name"`
	VariantLabel    *string        `gorm:"column:variant_label"`
	SKU             string         `gorm:"column:sku"`
	Snapshot        datatypes.JSON `gorm:"column:snapshot"`
	Quantity        int            `gorm:"column:quantity"`
	UnitPriceAmount int64          `gorm:"column:unit_price_amount"`
	UnitPriceCcy    string         `gorm:"column:unit_price_currency"`
	LineTotalAmount int64          `gorm:"column:line_total_amount"`
	CreatedAt       time.Time      `gorm:"column:created_at"`
	UpdatedAt       time.Time      `gorm:"column:updated_at"`
	Version         int64          `gorm:"column:version"`
}

func (OrderItem) TableName() string { return "order_items" }
