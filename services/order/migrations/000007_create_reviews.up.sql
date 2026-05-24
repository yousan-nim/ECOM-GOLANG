-- Reviews live here in order-service because every review must reference an order_item
-- (verified purchase guarantee).
-- product / user are soft refs to catalog.

CREATE TABLE reviews (
    id              BIGSERIAL    PRIMARY KEY,
    public_id       UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,

    product_public_id UUID       NOT NULL,                        -- soft ref → catalog.products
    user_public_id    UUID       NOT NULL,                        -- soft ref → catalog.users
    order_item_id     BIGINT     NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,

    rating          SMALLINT     NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title           TEXT,
    body            TEXT,

    status          TEXT         NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING','APPROVED','REJECTED','HIDDEN')),
    moderation_note TEXT,

    helpful_count   INTEGER      NOT NULL DEFAULT 0,
    reply_from_vendor TEXT,
    replied_at      TIMESTAMPTZ,

    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    version         BIGINT       NOT NULL DEFAULT 0,

    CONSTRAINT uq_review_per_item UNIQUE (order_item_id)
);

CREATE INDEX idx_reviews_product ON reviews (product_public_id, status, created_at DESC);
CREATE INDEX idx_reviews_user    ON reviews (user_public_id, created_at DESC);

CREATE TABLE review_images (
    id              BIGSERIAL    PRIMARY KEY,
    review_id       BIGINT       NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
    url             TEXT         NOT NULL,
    position        INTEGER      NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE review_votes (
    review_id       BIGINT      NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
    user_public_id  UUID        NOT NULL,
    is_helpful      BOOLEAN     NOT NULL,
    voted_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (review_id, user_public_id)
);

SELECT attach_standard_triggers('reviews');
