-- ┌───────────────────────────────────────────────────────────┐
-- │ V3: reviews (review service).                              │
-- │  Product ratings/reviews. All refs are UUID + snapshot.    │
-- │  verified_purchase is set by consuming order/payment events.│
-- └───────────────────────────────────────────────────────────┘

CREATE TABLE reviews (
    id                 BIGSERIAL   PRIMARY KEY,
    public_id          UUID        NOT NULL DEFAULT uuid_generate_v7() UNIQUE,

    -- Soft refs (no cross-service FK).
    product_public_id  UUID        NOT NULL,               -- → catalog.products
    vendor_public_id   UUID        NOT NULL,               -- → catalog.vendors
    user_public_id     UUID        NOT NULL,               -- → auth.users (author)
    order_public_id    UUID,                               -- → order.orders (proof of purchase)

    author_name        TEXT        NOT NULL,               -- snapshot for display
    rating             SMALLINT    NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title              TEXT,
    body               TEXT        NOT NULL,

    status             TEXT        NOT NULL DEFAULT 'PENDING'
                       CHECK (status IN ('PENDING','PUBLISHED','REJECTED','HIDDEN')),
    verified_purchase  BOOLEAN     NOT NULL DEFAULT FALSE,
    helpful_count      INTEGER     NOT NULL DEFAULT 0 CHECK (helpful_count >= 0),

    -- Optional vendor reply, kept inline (1:1 with the review).
    response_body      TEXT,
    responded_at       TIMESTAMPTZ,

    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version            BIGINT      NOT NULL DEFAULT 0,

    -- One review per user per product.
    UNIQUE (user_public_id, product_public_id)
);

CREATE INDEX idx_reviews_product ON reviews (product_public_id, status, created_at DESC);
CREATE INDEX idx_reviews_user    ON reviews (user_public_id, created_at DESC);
CREATE INDEX idx_reviews_rating  ON reviews (product_public_id, rating) WHERE status = 'PUBLISHED';

SELECT attach_standard_triggers('reviews');
