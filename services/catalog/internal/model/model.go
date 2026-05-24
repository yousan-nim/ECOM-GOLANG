// Package model maps GORM structs onto the catalog schema.
//
// The schema is authoritative in services/catalog/migrations — these structs
// must match it. Do NOT enable AutoMigrate; the migrations own the DDL
// (triggers, partial indexes, generated columns, etc.).
//
// Money is stored as a minor-unit integer (amount) + ISO-4217 currency code,
// matching the SQL (BIGINT amount, CHAR(3) currency).
package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type User struct {
	ID            int64          `gorm:"primaryKey"`
	PublicID      uuid.UUID      `gorm:"column:public_id"`
	Email         string         `gorm:"column:email"`
	EmailVerified bool           `gorm:"column:email_verified"`
	PasswordHash  string         `gorm:"column:password_hash"`
	FullName      string         `gorm:"column:full_name"`
	Phone         *string        `gorm:"column:phone"`
	Status        string         `gorm:"column:status"`
	LastLoginAt   *time.Time     `gorm:"column:last_login_at"`
	CreatedAt     time.Time      `gorm:"column:created_at"`
	UpdatedAt     time.Time      `gorm:"column:updated_at"`
	Version       int64          `gorm:"column:version"`
	DeletedAt     gorm.DeletedAt `gorm:"column:deleted_at"`
}

func (User) TableName() string { return "users" }

type Vendor struct {
	ID                   int64          `gorm:"primaryKey"`
	PublicID             uuid.UUID      `gorm:"column:public_id"`
	OwnerUserID          int64          `gorm:"column:owner_user_id"`
	Name                 string         `gorm:"column:name"`
	Slug                 string         `gorm:"column:slug"`
	Status               string         `gorm:"column:status"`
	DefaultCommissionBps int            `gorm:"column:default_commission_bps"`
	PayoutCurrency       string         `gorm:"column:payout_currency"`
	CreatedAt            time.Time      `gorm:"column:created_at"`
	UpdatedAt            time.Time      `gorm:"column:updated_at"`
	Version              int64          `gorm:"column:version"`
	DeletedAt            gorm.DeletedAt `gorm:"column:deleted_at"`
}

func (Vendor) TableName() string { return "vendors" }

type Category struct {
	ID        int64          `gorm:"primaryKey"`
	PublicID  uuid.UUID      `gorm:"column:public_id"`
	ParentID  *int64         `gorm:"column:parent_id"`
	Name      string         `gorm:"column:name"`
	Slug      string         `gorm:"column:slug"`
	Path      string         `gorm:"column:path"`
	Depth     int            `gorm:"column:depth"`
	IsActive  bool           `gorm:"column:is_active"`
	CreatedAt time.Time      `gorm:"column:created_at"`
	UpdatedAt time.Time      `gorm:"column:updated_at"`
	Version   int64          `gorm:"column:version"`
	DeletedAt gorm.DeletedAt `gorm:"column:deleted_at"`
}

func (Category) TableName() string { return "categories" }

type Product struct {
	ID            int64          `gorm:"primaryKey"`
	PublicID      uuid.UUID      `gorm:"column:public_id"`
	VendorID      int64          `gorm:"column:vendor_id"`
	CategoryID    int64          `gorm:"column:category_id"`
	Name          string         `gorm:"column:name"`
	Slug          string         `gorm:"column:slug"`
	ShortDesc     *string        `gorm:"column:short_desc"`
	Description   *string        `gorm:"column:description"`
	Brand         *string        `gorm:"column:brand"`
	Status        string         `gorm:"column:status"`
	PriceMin      *int64         `gorm:"column:price_min_amount"`
	PriceMax      *int64         `gorm:"column:price_max_amount"`
	PriceCurrency *string        `gorm:"column:price_currency"`
	RatingAvg     *float64       `gorm:"column:rating_avg"`
	RatingCount   int            `gorm:"column:rating_count"`
	SoldCount     int            `gorm:"column:sold_count"`
	PublishedAt   *time.Time     `gorm:"column:published_at"`
	CreatedAt     time.Time      `gorm:"column:created_at"`
	UpdatedAt     time.Time      `gorm:"column:updated_at"`
	Version       int64          `gorm:"column:version"`
	DeletedAt     gorm.DeletedAt `gorm:"column:deleted_at"`

	Variants []ProductVariant `gorm:"foreignKey:ProductID"`
}

func (Product) TableName() string { return "products" }

type ProductVariant struct {
	ID            int64          `gorm:"primaryKey"`
	PublicID      uuid.UUID      `gorm:"column:public_id"`
	ProductID     int64          `gorm:"column:product_id"`
	SKU           string         `gorm:"column:sku"`
	Barcode       *string        `gorm:"column:barcode"`
	NameSuffix    *string        `gorm:"column:name_suffix"`
	PriceAmount   int64          `gorm:"column:price_amount"`
	PriceCurrency string         `gorm:"column:price_currency"`
	CompareAt     *int64         `gorm:"column:compare_at_amount"`
	CostAmount    *int64         `gorm:"column:cost_amount"`
	Status        string         `gorm:"column:status"`
	CreatedAt     time.Time      `gorm:"column:created_at"`
	UpdatedAt     time.Time      `gorm:"column:updated_at"`
	Version       int64          `gorm:"column:version"`
	DeletedAt     gorm.DeletedAt `gorm:"column:deleted_at"`
}

func (ProductVariant) TableName() string { return "product_variants" }

// Inventory is tracked per (variant, warehouse). Available stock is computed:
// available = on_hand_qty - reserved_qty - safety_stock.
type Inventory struct {
	ID          int64     `gorm:"primaryKey"`
	VariantID   int64     `gorm:"column:variant_id"`
	WarehouseID int64     `gorm:"column:warehouse_id"`
	OnHandQty   int       `gorm:"column:on_hand_qty"`
	ReservedQty int       `gorm:"column:reserved_qty"`
	SafetyStock int       `gorm:"column:safety_stock"`
	CreatedAt   time.Time `gorm:"column:created_at"`
	UpdatedAt   time.Time `gorm:"column:updated_at"`
	Version     int64     `gorm:"column:version"`
}

func (Inventory) TableName() string { return "inventory" }

// Available returns sellable quantity.
func (i Inventory) Available() int { return i.OnHandQty - i.ReservedQty - i.SafetyStock }
