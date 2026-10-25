-- FEYA core schema. All money columns are NUMERIC(12,2) in the currency stored next to them (KZT by default).
-- All timestamps are timestamptz (stored in UTC); delivery dates/slots are local Asia/Almaty values.

-- ---------------------------------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------------------------------
CREATE TABLE florists (
    id          UUID PRIMARY KEY,
    name        VARCHAR(160) NOT NULL,
    city        VARCHAR(80)  NOT NULL,
    address     VARCHAR(255),
    phone       VARCHAR(24),
    priority    INT          NOT NULL DEFAULT 100,
    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE users (
    id                    UUID PRIMARY KEY,
    phone                 VARCHAR(20)  NOT NULL UNIQUE,
    name                  VARCHAR(120),
    email                 VARCHAR(160),
    language              VARCHAR(2)   NOT NULL DEFAULT 'ru' CHECK (language IN ('ru', 'kk', 'en')),
    status                VARCHAR(24)  NOT NULL DEFAULT 'ACTIVE'
                              CHECK (status IN ('ACTIVE', 'DELETION_REQUESTED', 'BLOCKED')),
    florist_id            UUID REFERENCES florists (id),
    notify_push           BOOLEAN      NOT NULL DEFAULT TRUE,
    notify_order_updates  BOOLEAN      NOT NULL DEFAULT TRUE,
    notify_promotions     BOOLEAN      NOT NULL DEFAULT FALSE,
    deletion_requested_at TIMESTAMPTZ,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    last_login_at         TIMESTAMPTZ
);

CREATE TABLE user_roles (
    user_id UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role    VARCHAR(24) NOT NULL CHECK (role IN ('CUSTOMER', 'ADMIN', 'FLORIST', 'COURIER', 'SUPPORT')),
    PRIMARY KEY (user_id, role)
);

CREATE TABLE otp_codes (
    id          UUID PRIMARY KEY,
    phone       VARCHAR(20)  NOT NULL,
    code_hash   VARCHAR(128) NOT NULL,
    attempts    INT          NOT NULL DEFAULT 0,
    consumed    BOOLEAN      NOT NULL DEFAULT FALSE,
    expires_at  TIMESTAMPTZ  NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_otp_phone_created ON otp_codes (phone, created_at DESC);

CREATE TABLE refresh_tokens (
    id          UUID PRIMARY KEY,
    user_id     UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash  VARCHAR(128) NOT NULL UNIQUE,
    family_id   UUID         NOT NULL,
    expires_at  TIMESTAMPTZ  NOT NULL,
    revoked_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_user ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_family ON refresh_tokens (family_id);

CREATE TABLE device_tokens (
    id          UUID PRIMARY KEY,
    user_id     UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token       VARCHAR(512) NOT NULL UNIQUE,
    platform    VARCHAR(16)  NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_device_user ON device_tokens (user_id);

CREATE TABLE addresses (
    id              UUID PRIMARY KEY,
    user_id         UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    label           VARCHAR(60),
    city            VARCHAR(80)  NOT NULL,
    street          VARCHAR(160) NOT NULL,
    building        VARCHAR(20)  NOT NULL,
    apartment       VARCHAR(20),
    entrance        VARCHAR(20),
    floor           VARCHAR(20),
    intercom        VARCHAR(40),
    recipient_name  VARCHAR(120),
    recipient_phone VARCHAR(20),
    instructions    VARCHAR(500),
    latitude        NUMERIC(9, 6),
    longitude       NUMERIC(9, 6),
    is_default      BOOLEAN      NOT NULL DEFAULT FALSE,
    deleted         BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_addresses_user ON addresses (user_id) WHERE deleted = FALSE;

-- ---------------------------------------------------------------------------------------------
-- Delivery zones and slot templates
-- ---------------------------------------------------------------------------------------------
CREATE TABLE delivery_zones (
    id                      UUID PRIMARY KEY,
    code                    VARCHAR(40)    NOT NULL UNIQUE,
    city_code               VARCHAR(40)    NOT NULL,
    city_aliases            VARCHAR(255)   NOT NULL DEFAULT '',
    name                    JSONB          NOT NULL,
    center_lat              NUMERIC(9, 6)  NOT NULL,
    center_lng              NUMERIC(9, 6)  NOT NULL,
    radius_km               NUMERIC(6, 2)  NOT NULL CHECK (radius_km > 0),
    base_fee                NUMERIC(12, 2) NOT NULL CHECK (base_fee >= 0),
    free_delivery_threshold NUMERIC(12, 2),
    asap_enabled            BOOLEAN        NOT NULL DEFAULT FALSE,
    asap_fee                NUMERIC(12, 2) NOT NULL DEFAULT 0,
    asap_eta_minutes        INT            NOT NULL DEFAULT 90,
    work_start              TIME           NOT NULL DEFAULT '09:00',
    work_end                TIME           NOT NULL DEFAULT '21:00',
    is_default              BOOLEAN        NOT NULL DEFAULT FALSE,
    active                  BOOLEAN        NOT NULL DEFAULT TRUE,
    currency                VARCHAR(3)       NOT NULL DEFAULT 'KZT'
);

CREATE TABLE florist_zones (
    florist_id UUID NOT NULL REFERENCES florists (id) ON DELETE CASCADE,
    zone_id    UUID NOT NULL REFERENCES delivery_zones (id) ON DELETE CASCADE,
    PRIMARY KEY (florist_id, zone_id)
);

CREATE TABLE delivery_slot_templates (
    id             UUID PRIMARY KEY,
    zone_id        UUID           NOT NULL REFERENCES delivery_zones (id) ON DELETE CASCADE,
    start_time     TIME           NOT NULL,
    end_time       TIME           NOT NULL,
    capacity       INT            NOT NULL CHECK (capacity > 0),
    cutoff_minutes INT            NOT NULL DEFAULT 120 CHECK (cutoff_minutes >= 0),
    surcharge      NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (surcharge >= 0),
    days_of_week   VARCHAR(20)    NOT NULL DEFAULT '1,2,3,4,5,6,7',
    active         BOOLEAN        NOT NULL DEFAULT TRUE,
    CHECK (end_time > start_time)
);
CREATE INDEX idx_slot_templates_zone ON delivery_slot_templates (zone_id);

-- ---------------------------------------------------------------------------------------------
-- Catalog
-- ---------------------------------------------------------------------------------------------
CREATE TABLE categories (
    id         UUID PRIMARY KEY,
    slug       VARCHAR(60) NOT NULL UNIQUE,
    name       JSONB       NOT NULL,
    sort_order INT         NOT NULL DEFAULT 0,
    active     BOOLEAN     NOT NULL DEFAULT TRUE
);

CREATE TABLE products (
    id                 UUID PRIMARY KEY,
    slug               VARCHAR(120)  NOT NULL UNIQUE,
    category_id        UUID          NOT NULL REFERENCES categories (id),
    name               JSONB         NOT NULL,
    description        JSONB         NOT NULL,
    composition        JSONB         NOT NULL DEFAULT '{}'::jsonb,
    search_text        TEXT          NOT NULL DEFAULT '',
    price_from         NUMERIC(12, 2) NOT NULL DEFAULT 0,
    currency           VARCHAR(3)      NOT NULL DEFAULT 'KZT',
    featured           BOOLEAN       NOT NULL DEFAULT FALSE,
    seasonal           BOOLEAN       NOT NULL DEFAULT FALSE,
    gift               BOOLEAN       NOT NULL DEFAULT FALSE,
    sold_count         INT           NOT NULL DEFAULT 0,
    rating_avg         NUMERIC(3, 2),
    rating_count       INT           NOT NULL DEFAULT 0,
    prep_minutes       INT           NOT NULL DEFAULT 90,
    active             BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX idx_products_category ON products (category_id) WHERE active;
CREATE INDEX idx_products_created ON products (created_at DESC);

CREATE TABLE product_images (
    id         UUID PRIMARY KEY,
    product_id UUID         NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    url        VARCHAR(512) NOT NULL,
    alt        VARCHAR(200),
    sort_order INT          NOT NULL DEFAULT 0
);
CREATE INDEX idx_product_images_product ON product_images (product_id, sort_order);

CREATE TABLE product_variants (
    id          UUID PRIMARY KEY,
    product_id  UUID           NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    code        VARCHAR(16)    NOT NULL CHECK (code IN ('SMALL', 'STANDARD', 'LARGE', 'PREMIUM')),
    label       JSONB          NOT NULL,
    price       NUMERIC(12, 2) NOT NULL CHECK (price > 0),
    stems_count INT            CHECK (stems_count IS NULL OR stems_count > 0),
    sort_order  INT            NOT NULL DEFAULT 0,
    active      BOOLEAN        NOT NULL DEFAULT TRUE,
    UNIQUE (product_id, code)
);

CREATE TABLE inventory (
    id         UUID PRIMARY KEY,
    florist_id UUID        NOT NULL REFERENCES florists (id) ON DELETE CASCADE,
    variant_id UUID        NOT NULL REFERENCES product_variants (id) ON DELETE CASCADE,
    quantity   INT         NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (florist_id, variant_id)
);
CREATE INDEX idx_inventory_variant ON inventory (variant_id);

CREATE TABLE favorites (
    user_id    UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    product_id UUID        NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, product_id)
);

-- ---------------------------------------------------------------------------------------------
-- Promotions
-- ---------------------------------------------------------------------------------------------
CREATE TABLE promo_codes (
    id              UUID PRIMARY KEY,
    code            VARCHAR(40)    NOT NULL UNIQUE,
    type            VARCHAR(16)    NOT NULL CHECK (type IN ('PERCENT', 'FIXED')),
    value           NUMERIC(12, 2) NOT NULL CHECK (value > 0),
    min_order       NUMERIC(12, 2) NOT NULL DEFAULT 0,
    max_discount    NUMERIC(12, 2),
    valid_from      TIMESTAMPTZ,
    valid_until     TIMESTAMPTZ,
    usage_limit     INT,
    per_user_limit  INT,
    used_count      INT            NOT NULL DEFAULT 0,
    active          BOOLEAN        NOT NULL DEFAULT TRUE,
    CHECK (type <> 'PERCENT' OR value <= 100)
);

CREATE TABLE banners (
    id           UUID PRIMARY KEY,
    title        JSONB        NOT NULL,
    subtitle     JSONB        NOT NULL DEFAULT '{}'::jsonb,
    image_url    VARCHAR(512),
    promo_code   VARCHAR(40),
    target_type  VARCHAR(16),
    target_value VARCHAR(120),
    sort_order   INT          NOT NULL DEFAULT 0,
    active       BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------------------------
-- Orders
-- ---------------------------------------------------------------------------------------------
CREATE SEQUENCE order_number_seq START WITH 1001;

CREATE TABLE couriers (
    user_id          UUID PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    vehicle          VARCHAR(60),
    on_shift         BOOLEAN     NOT NULL DEFAULT FALSE,
    location_sharing BOOLEAN     NOT NULL DEFAULT FALSE,
    active           BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE orders (
    id                  UUID PRIMARY KEY,
    number              VARCHAR(24)    NOT NULL UNIQUE,
    user_id             UUID           NOT NULL REFERENCES users (id),
    florist_id          UUID           NOT NULL REFERENCES florists (id),
    zone_id             UUID           NOT NULL REFERENCES delivery_zones (id),
    courier_id          UUID           REFERENCES couriers (user_id),
    status              VARCHAR(24)    NOT NULL CHECK (status IN (
        'CREATED', 'PENDING_PAYMENT', 'PAID', 'CONFIRMED', 'PREPARING', 'READY_FOR_PICKUP', 'COURIER_ASSIGNED',
        'PICKED_UP', 'ON_THE_WAY', 'DELIVERED', 'CANCELLED', 'PAYMENT_FAILED', 'REFUNDED')),
    payment_status      VARCHAR(16)    NOT NULL DEFAULT 'UNPAID' CHECK (payment_status IN ('UNPAID', 'PAID', 'FAILED', 'REFUNDED')),
    currency            VARCHAR(3)       NOT NULL DEFAULT 'KZT',
    subtotal            NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0),
    discount            NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    delivery_fee        NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (delivery_fee >= 0),
    gift_wrap_fee       NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (gift_wrap_fee >= 0),
    total               NUMERIC(12, 2) NOT NULL CHECK (total >= 0),
    promo_code          VARCHAR(40),
    delivery_asap       BOOLEAN        NOT NULL DEFAULT FALSE,
    delivery_date       DATE           NOT NULL,
    slot_template_id    UUID           REFERENCES delivery_slot_templates (id),
    slot_start          TIME,
    slot_end            TIME,
    eta_at              TIMESTAMPTZ,
    recipient_name      VARCHAR(120)   NOT NULL,
    recipient_phone     VARCHAR(20)    NOT NULL,
    addr_city           VARCHAR(80)    NOT NULL,
    addr_street         VARCHAR(160)   NOT NULL,
    addr_building       VARCHAR(20)    NOT NULL,
    addr_apartment      VARCHAR(20),
    addr_entrance       VARCHAR(20),
    addr_floor          VARCHAR(20),
    addr_intercom       VARCHAR(40),
    addr_latitude       NUMERIC(9, 6),
    addr_longitude      NUMERIC(9, 6),
    instructions        VARCHAR(500),
    sender_anonymous    BOOLEAN        NOT NULL DEFAULT FALSE,
    gift_message        VARCHAR(500),
    gift_wrap           BOOLEAN        NOT NULL DEFAULT FALSE,
    idempotency_key     VARCHAR(80),
    terms_accepted_at   TIMESTAMPTZ    NOT NULL,
    cancel_reason       VARCHAR(255),
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ    NOT NULL DEFAULT now(),
    paid_at             TIMESTAMPTZ,
    delivered_at        TIMESTAMPTZ,
    cancelled_at        TIMESTAMPTZ,
    version             BIGINT         NOT NULL DEFAULT 0,
    UNIQUE (user_id, idempotency_key)
);
CREATE INDEX idx_orders_user ON orders (user_id, created_at DESC);
CREATE INDEX idx_orders_florist_status ON orders (florist_id, status);
CREATE INDEX idx_orders_status_created ON orders (status, created_at DESC);
CREATE INDEX idx_orders_courier ON orders (courier_id) WHERE courier_id IS NOT NULL;
CREATE INDEX idx_orders_slot ON orders (slot_template_id, delivery_date);

CREATE TABLE order_items (
    id           UUID PRIMARY KEY,
    order_id     UUID           NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    product_id   UUID           NOT NULL REFERENCES products (id),
    variant_id   UUID           NOT NULL REFERENCES product_variants (id),
    product_name VARCHAR(200)   NOT NULL,
    variant_label VARCHAR(80)   NOT NULL,
    image_url    VARCHAR(512),
    unit_price   NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
    quantity     INT            NOT NULL CHECK (quantity > 0 AND quantity <= 20),
    line_total   NUMERIC(12, 2) NOT NULL CHECK (line_total >= 0)
);
CREATE INDEX idx_order_items_order ON order_items (order_id);
CREATE INDEX idx_order_items_product ON order_items (product_id);

CREATE TABLE order_status_history (
    id          UUID PRIMARY KEY,
    order_id    UUID        NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    from_status VARCHAR(24),
    to_status   VARCHAR(24) NOT NULL,
    actor_role  VARCHAR(24) NOT NULL,
    actor_id    UUID,
    note        VARCHAR(255),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_order_history_order ON order_status_history (order_id, created_at);

CREATE TABLE promo_redemptions (
    id         UUID PRIMARY KEY,
    promo_id   UUID        NOT NULL REFERENCES promo_codes (id),
    user_id    UUID        NOT NULL REFERENCES users (id),
    order_id   UUID        NOT NULL UNIQUE REFERENCES orders (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_promo_redemptions_user ON promo_redemptions (promo_id, user_id);

-- ---------------------------------------------------------------------------------------------
-- Payments
-- ---------------------------------------------------------------------------------------------
CREATE TABLE payments (
    id                  UUID PRIMARY KEY,
    order_id            UUID           NOT NULL REFERENCES orders (id),
    provider            VARCHAR(32)    NOT NULL,
    method              VARCHAR(24)    NOT NULL,
    status              VARCHAR(16)    NOT NULL CHECK (status IN ('PENDING', 'SUCCEEDED', 'FAILED', 'REFUNDED', 'PARTIALLY_REFUNDED')),
    amount              NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
    refunded_amount     NUMERIC(12, 2) NOT NULL DEFAULT 0,
    currency            VARCHAR(3)       NOT NULL,
    sandbox             BOOLEAN        NOT NULL DEFAULT FALSE,
    provider_payment_id VARCHAR(120),
    checkout_url        VARCHAR(1024),
    failure_reason      VARCHAR(255),
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ    NOT NULL DEFAULT now(),
    version             BIGINT         NOT NULL DEFAULT 0
);
CREATE INDEX idx_payments_order ON payments (order_id);
CREATE UNIQUE INDEX idx_payments_provider_id ON payments (provider, provider_payment_id) WHERE provider_payment_id IS NOT NULL;
-- At most one in-flight payment attempt per order.
CREATE UNIQUE INDEX idx_payments_one_pending ON payments (order_id) WHERE status = 'PENDING';

CREATE TABLE payment_events (
    id           UUID PRIMARY KEY,
    payment_id   UUID,
    provider     VARCHAR(32)  NOT NULL,
    event_id     VARCHAR(120) NOT NULL,
    type         VARCHAR(40)  NOT NULL,
    payload      TEXT         NOT NULL,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (provider, event_id)
);

CREATE TABLE refunds (
    id           UUID PRIMARY KEY,
    payment_id   UUID           NOT NULL REFERENCES payments (id),
    order_id     UUID           NOT NULL REFERENCES orders (id),
    amount       NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    reason       VARCHAR(255),
    status       VARCHAR(16)    NOT NULL CHECK (status IN ('REQUESTED', 'COMPLETED', 'FAILED')),
    requested_by UUID,
    created_at   TIMESTAMPTZ    NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ
);
CREATE INDEX idx_refunds_order ON refunds (order_id);

-- ---------------------------------------------------------------------------------------------
-- Courier tracking, reviews, notifications, audit
-- ---------------------------------------------------------------------------------------------
CREATE TABLE courier_locations (
    id          UUID PRIMARY KEY,
    courier_id  UUID           NOT NULL REFERENCES couriers (user_id) ON DELETE CASCADE,
    order_id    UUID           REFERENCES orders (id),
    latitude    NUMERIC(9, 6)  NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude   NUMERIC(9, 6)  NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    accuracy_m  NUMERIC(8, 2),
    recorded_at TIMESTAMPTZ    NOT NULL,
    created_at  TIMESTAMPTZ    NOT NULL DEFAULT now()
);
CREATE INDEX idx_courier_locations_courier ON courier_locations (courier_id, recorded_at DESC);
CREATE INDEX idx_courier_locations_order ON courier_locations (order_id, recorded_at DESC);

CREATE TABLE reviews (
    id         UUID PRIMARY KEY,
    product_id UUID        NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    user_id    UUID        NOT NULL REFERENCES users (id),
    order_id   UUID        REFERENCES orders (id),
    rating     SMALLINT    NOT NULL CHECK (rating BETWEEN 1 AND 5),
    text       VARCHAR(2000),
    verified   BOOLEAN     NOT NULL DEFAULT FALSE,
    status     VARCHAR(16) NOT NULL DEFAULT 'PUBLISHED' CHECK (status IN ('PUBLISHED', 'HIDDEN')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (product_id, user_id)
);
CREATE INDEX idx_reviews_product ON reviews (product_id, created_at DESC) WHERE status = 'PUBLISHED';

CREATE TABLE notifications (
    id         UUID PRIMARY KEY,
    user_id    UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    type       VARCHAR(40)  NOT NULL,
    title      VARCHAR(160) NOT NULL,
    body       VARCHAR(500) NOT NULL,
    data       VARCHAR(500),
    read_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_notifications_user ON notifications (user_id, created_at DESC);

CREATE TABLE audit_events (
    id          UUID PRIMARY KEY,
    actor_id    UUID,
    actor_role  VARCHAR(24),
    action      VARCHAR(60)  NOT NULL,
    entity_type VARCHAR(40)  NOT NULL,
    entity_id   VARCHAR(80),
    details     VARCHAR(1000),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_created ON audit_events (created_at DESC);
CREATE INDEX idx_audit_entity ON audit_events (entity_type, entity_id);
