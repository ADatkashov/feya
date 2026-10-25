package app.feya.orders;

import app.feya.address.Address;
import app.feya.address.AddressRepository;
import app.feya.cart.CartDtos;
import app.feya.cart.CartService;
import app.feya.common.ApiException;
import app.feya.common.Lang;
import app.feya.common.MediaUrls;
import app.feya.delivery.DeliveryService;
import app.feya.delivery.DeliveryZone;
import app.feya.florist.Florist;
import app.feya.florist.InventoryService;
import app.feya.identity.PhoneNumbers;
import app.feya.identity.User;
import app.feya.identity.UserRepository;
import app.feya.catalog.ProductRepository;
import app.feya.promotions.PromoService;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OrderService {
    private static final Set<OrderStatus> UNPAID = EnumSet.of(OrderStatus.PENDING_PAYMENT, OrderStatus.PAYMENT_FAILED);
    private static final int MAX_UNPAID_ORDERS = 3;

    private final OrderRepository orders;
    private final OrderStatusHistoryRepository history;
    private final AddressRepository addresses;
    private final UserRepository users;
    private final ProductRepository products;
    private final CartService cart;
    private final DeliveryService delivery;
    private final InventoryService inventory;
    private final PromoService promos;
    private final MediaUrls media;
    private final JdbcTemplate jdbc;
    private final ApplicationEventPublisher events;
    private final Clock clock;
    private final app.feya.common.FeyaProperties props;

    public OrderService(OrderRepository orders, OrderStatusHistoryRepository history, AddressRepository addresses,
                        UserRepository users, ProductRepository products, CartService cart, DeliveryService delivery,
                        InventoryService inventory, PromoService promos, MediaUrls media, JdbcTemplate jdbc,
                        ApplicationEventPublisher events, Clock clock, app.feya.common.FeyaProperties props) {
        this.orders = orders;
        this.history = history;
        this.addresses = addresses;
        this.users = users;
        this.products = products;
        this.cart = cart;
        this.delivery = delivery;
        this.inventory = inventory;
        this.promos = promos;
        this.media = media;
        this.jdbc = jdbc;
        this.events = events;
        this.clock = clock;
        this.props = props;
    }

    // ---------------------------------------------------------------------------------------------
    // Creation
    // ---------------------------------------------------------------------------------------------

    public record Created(OrderEntity order, boolean replayed) {}

    @Transactional
    public Created create(UUID userId, OrderDtos.CreateOrderRequest req, String idempotencyKey) {
        if (idempotencyKey != null && !idempotencyKey.isBlank()) {
            Optional<OrderEntity> existing = orders.findByUserIdAndIdempotencyKey(userId, idempotencyKey);
            if (existing.isPresent()) {
                return new Created(existing.get(), true);
            }
        }
        User user = users.findById(userId).orElseThrow(() -> ApiException.unauthorized("UNAUTHORIZED", "Unknown user"));
        if (orders.countByUserIdAndStatusIn(userId, UNPAID) >= MAX_UNPAID_ORDERS) {
            throw ApiException.conflict("TOO_MANY_UNPAID_ORDERS", "Please pay or cancel your pending orders first");
        }
        if (req.slot() != null && req.asap() || req.slot() == null && !req.asap()) {
            throw ApiException.badRequest("DELIVERY_TIME_REQUIRED", "Choose either ASAP delivery or a time slot");
        }
        if (req.addressId() != null && req.address() != null || req.addressId() == null && req.address() == null) {
            throw ApiException.badRequest("ADDRESS_REQUIRED", "Provide either a saved address or address details");
        }

        // Address snapshot
        String city, street, building, apartment, entrance, floor, intercom;
        BigDecimal lat, lng;
        if (req.addressId() != null) {
            Address a = addresses.findByIdAndUserIdAndDeletedFalse(req.addressId(), userId)
                    .orElseThrow(() -> ApiException.notFound("Address"));
            city = a.getCity(); street = a.getStreet(); building = a.getBuilding(); apartment = a.getApartment();
            entrance = a.getEntrance(); floor = a.getFloor(); intercom = a.getIntercom();
            lat = a.getLatitude(); lng = a.getLongitude();
        } else {
            OrderDtos.InlineAddress a = req.address();
            if ((a.latitude() == null) != (a.longitude() == null)) {
                throw ApiException.badRequest("INVALID_COORDINATES", "Both latitude and longitude are required");
            }
            city = a.city().trim(); street = a.street().trim(); building = a.building().trim();
            apartment = a.apartment(); entrance = a.entrance(); floor = a.floor(); intercom = a.intercom();
            lat = a.latitude(); lng = a.longitude();
        }
        DeliveryZone zone = delivery.resolveZone(city, lat, lng);

        // Delivery time
        UUID slotTemplateId = null;
        java.time.LocalDate deliveryDate;
        java.time.LocalTime slotStart = null, slotEnd = null;
        Instant eta;
        BigDecimal surcharge = null;
        if (req.asap()) {
            eta = delivery.asapEta(zone);
            deliveryDate = java.time.LocalDate.ofInstant(eta, delivery.businessZone());
        } else {
            DeliveryService.ValidatedSlot slot = delivery.validateSlot(zone, req.slot().templateId(), req.slot().date());
            slotTemplateId = slot.template().getId();
            deliveryDate = slot.date();
            slotStart = slot.template().getStartTime();
            slotEnd = slot.template().getEndTime();
            eta = slot.startsAt();
            surcharge = slot.template().getSurcharge();
        }

        // Authoritative pricing
        CartDtos.QuoteRequest quoteReq = new CartDtos.QuoteRequest(req.items(), req.promoCode(), zone.getId(), req.slot(),
                req.asap(), req.giftWrap());
        CartService.Priced priced = cart.price(quoteReq, userId, zone, surcharge);
        if (priced.promoError() != null) {
            throw ApiException.unprocessable(priced.promoError(), "Promo code cannot be applied");
        }
        if (!priced.valid()) {
            throw ApiException.conflict("ITEMS_UNAVAILABLE", "Some items are unavailable: " + String.join(",", priced.issues()));
        }

        Map<UUID, Integer> needed = priced.quantities();
        Florist florist = inventory.pickFlorist(zone.getId(), needed)
                .orElseThrow(() -> ApiException.conflict("ITEMS_UNAVAILABLE", "The bouquet set is not available from one florist"));
        inventory.reserve(florist.getId(), needed);

        Lang lang = user.lang();
        OrderEntity o = new OrderEntity();
        o.setNumber("FEYA-" + jdbc.queryForObject("select nextval('order_number_seq')", Long.class));
        o.setUserId(userId);
        o.setFloristId(florist.getId());
        o.setZoneId(zone.getId());
        o.setStatus(OrderStatus.CREATED);
        o.setCurrency(zone.getCurrency());
        o.setSubtotal(priced.subtotal());
        o.setDiscount(priced.discount());
        o.setDeliveryFee(priced.deliveryFee());
        o.setGiftWrapFee(priced.giftWrapFee());
        o.setTotal(priced.total());
        o.setPromoCode(priced.promo() == null ? null : priced.promo().getCode());
        o.setDeliveryAsap(req.asap());
        o.setDeliveryDate(deliveryDate);
        o.setSlotTemplateId(slotTemplateId);
        o.setSlotStart(slotStart);
        o.setSlotEnd(slotEnd);
        o.setEtaAt(eta);
        o.setRecipientName(req.recipient().name().trim());
        o.setRecipientPhone(PhoneNumbers.normalize(req.recipient().phone()));
        o.setAddrCity(city); o.setAddrStreet(street); o.setAddrBuilding(building); o.setAddrApartment(apartment);
        o.setAddrEntrance(entrance); o.setAddrFloor(floor); o.setAddrIntercom(intercom);
        o.setAddrLatitude(lat); o.setAddrLongitude(lng);
        o.setInstructions(req.instructions());
        o.setSenderAnonymous(req.anonymousSender());
        o.setGiftMessage(req.giftMessage());
        o.setGiftWrap(req.giftWrap());
        o.setIdempotencyKey(idempotencyKey == null || idempotencyKey.isBlank() ? null : idempotencyKey);
        o.setTermsAcceptedAt(clock.instant());
        for (CartService.PricedLine l : priced.lines()) {
            OrderItem item = new OrderItem();
            item.setOrder(o);
            item.setProductId(l.product().getId());
            item.setVariantId(l.variant().getId());
            item.setProductName(lang.pick(l.product().getName()));
            item.setVariantLabel(lang.pick(l.variant().getLabel()));
            item.setImageUrl(l.product().getImages().isEmpty() ? null : l.product().getImages().get(0).getUrl());
            item.setUnitPrice(l.unitPrice());
            item.setQuantity(l.quantity());
            item.setLineTotal(l.lineTotal());
            o.getItems().add(item);
        }
        o = orders.save(o);
        record(o, null, OrderStatus.CREATED, Actor.CUSTOMER, userId, null);
        if (priced.promo() != null) {
            promos.redeem(priced.promo(), userId, o.getId());
        }
        transition(o, OrderStatus.PENDING_PAYMENT, Actor.SYSTEM, null, null);

        if (req.address() != null && req.address().saveAddress()) {
            Address saved = new Address();
            saved.setUserId(userId);
            saved.setCity(city); saved.setStreet(street); saved.setBuilding(building); saved.setApartment(apartment);
            saved.setEntrance(entrance); saved.setFloor(floor); saved.setIntercom(intercom);
            saved.setLatitude(lat); saved.setLongitude(lng);
            saved.setRecipientName(o.getRecipientName());
            saved.setRecipientPhone(o.getRecipientPhone());
            saved.setDefaultAddress(addresses.findByUserIdAndDeletedFalseOrderByDefaultAddressDescCreatedAtDesc(userId).isEmpty());
            addresses.save(saved);
        }
        return new Created(o, false);
    }

    // ---------------------------------------------------------------------------------------------
    // Transitions
    // ---------------------------------------------------------------------------------------------

    /** Applies a validated status change. Always run inside a transaction holding the order row lock when possible. */
    @Transactional
    public OrderEntity transition(OrderEntity order, OrderStatus to, Actor actor, UUID actorId, String note) {
        OrderStatus from = order.getStatus();
        OrderStateMachine.require(from, to, actor);
        order.setStatus(to);
        Instant now = clock.instant();
        switch (to) {
            case PAID -> {
                order.setPaymentStatus(OrderEntity.PaymentState.PAID);
                order.setPaidAt(now);
            }
            case PAYMENT_FAILED -> order.setPaymentStatus(OrderEntity.PaymentState.FAILED);
            case DELIVERED -> {
                order.setDeliveredAt(now);
                order.getItems().forEach(i -> products.incrementSold(i.getProductId(), i.getQuantity()));
            }
            case CANCELLED -> {
                order.setCancelledAt(now);
                order.setCancelReason(note);
                releaseResources(order);
            }
            case REFUNDED -> order.setPaymentStatus(OrderEntity.PaymentState.REFUNDED);
            default -> { }
        }
        record(order, from, to, actor, actorId, note);
        events.publishEvent(new OrderStatusChanged(order.getId(), order.getUserId(), from, to, actor));
        return order;
    }

    private void releaseResources(OrderEntity order) {
        Map<UUID, Integer> items = new java.util.HashMap<>();
        order.getItems().forEach(i -> items.merge(i.getVariantId(), i.getQuantity(), Integer::sum));
        inventory.release(order.getFloristId(), items);
        promos.release(order.getId());
    }

    private void record(OrderEntity o, OrderStatus from, OrderStatus to, Actor actor, UUID actorId, String note) {
        OrderStatusHistory h = new OrderStatusHistory();
        h.setOrderId(o.getId());
        h.setFromStatus(from);
        h.setToStatus(to);
        h.setActorRole(actor);
        h.setActorId(actorId);
        h.setNote(note);
        h.setCreatedAt(clock.instant());
        history.save(h);
    }

    @Transactional
    public OrderEntity transitionById(UUID orderId, OrderStatus to, Actor actor, UUID actorId, String note) {
        OrderEntity o = orders.lockById(orderId).orElseThrow(() -> ApiException.notFound("Order"));
        return transition(o, to, actor, actorId, note);
    }

    @Transactional
    public OrderDtos.OrderDetail cancelByCustomer(UUID userId, UUID orderId, String reason, Lang lang) {
        OrderEntity o = orders.lockById(orderId).filter(x -> x.getUserId().equals(userId))
                .orElseThrow(() -> ApiException.notFound("Order"));
        transition(o, OrderStatus.CANCELLED, Actor.CUSTOMER, userId, reason);
        return detail(o);
    }

    /** Unpaid orders are cancelled after the configured TTL so reserved stock and slots are returned. */
    @Scheduled(fixedDelayString = "PT1M", initialDelayString = "PT1M")
    public void expireUnpaid() {
        expireUnpaidBefore(clock.instant().minus(props.orders().pendingPaymentTtl()));
    }

    @Transactional
    public int expireUnpaidBefore(Instant cutoff) {
        List<OrderEntity> stale = orders.findByStatusInAndCreatedAtBefore(UNPAID, cutoff);
        int n = 0;
        for (OrderEntity s : stale) {
            OrderEntity locked = orders.lockById(s.getId()).orElse(null);
            if (locked != null && UNPAID.contains(locked.getStatus())) {
                transition(locked, OrderStatus.CANCELLED, Actor.SYSTEM, null, "payment timeout");
                n++;
            }
        }
        return n;
    }

    // ---------------------------------------------------------------------------------------------
    // Reads
    // ---------------------------------------------------------------------------------------------

    @Transactional(readOnly = true)
    public OrderDtos.OrderDetail get(UUID userId, UUID orderId) {
        return detail(orders.findByIdAndUserId(orderId, userId).orElseThrow(() -> ApiException.notFound("Order")));
    }

    @Transactional(readOnly = true)
    public Page<OrderEntity> list(UUID userId, int page, int size) {
        return orders.findByUserId(userId, PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 50)),
                Sort.by(Sort.Order.desc("createdAt"))));
    }

    @Transactional(readOnly = true)
    public OrderEntity require(UUID orderId) {
        return orders.findById(orderId).orElseThrow(() -> ApiException.notFound("Order"));
    }

    public OrderDtos.OrderSummary summary(OrderEntity o) {
        OrderItem first = o.getItems().isEmpty() ? null : o.getItems().get(0);
        return new OrderDtos.OrderSummary(o.getId(), o.getNumber(), o.getStatus(), o.getTotal(), o.getCurrency(),
                o.getItems().stream().mapToInt(OrderItem::getQuantity).sum(), first == null ? null : first.getProductName(),
                first == null ? null : media.resolve(first.getImageUrl()), o.getDeliveryDate(), o.getSlotStart(),
                o.getSlotEnd(), o.isDeliveryAsap(), o.getCreatedAt());
    }

    @Transactional(readOnly = true)
    public OrderDtos.OrderDetail detail(OrderEntity o) {
        List<OrderDtos.TimelineEntry> timeline = history.findByOrderIdOrderByCreatedAt(o.getId()).stream()
                .map(h -> new OrderDtos.TimelineEntry(h.getToStatus(), h.getCreatedAt(), null)).toList();
        List<OrderDtos.ItemDto> items = o.getItems().stream().map(i -> new OrderDtos.ItemDto(i.getProductId(),
                i.getVariantId(), i.getProductName(), i.getVariantLabel(), media.resolve(i.getImageUrl()),
                i.getUnitPrice(), i.getQuantity(), i.getLineTotal())).toList();
        boolean canCancel = OrderStateMachine.canTransition(o.getStatus(), OrderStatus.CANCELLED, Actor.CUSTOMER);
        boolean canPay = UNPAID.contains(o.getStatus());
        return new OrderDtos.OrderDetail(o.getId(), o.getNumber(), o.getStatus(), o.getPaymentStatus(), o.getCurrency(),
                o.getSubtotal(), o.getDiscount(), o.getDeliveryFee(), o.getGiftWrapFee(), o.getTotal(), o.getPromoCode(),
                o.isDeliveryAsap(), o.getDeliveryDate(), o.getSlotStart(), o.getSlotEnd(), o.getEtaAt(),
                new OrderDtos.AddressDto(o.getAddrCity(), o.getAddrStreet(), o.getAddrBuilding(), o.getAddrApartment(),
                        o.getAddrEntrance(), o.getAddrFloor(), o.getAddrIntercom(), o.getAddrLatitude(), o.getAddrLongitude()),
                o.getInstructions(), o.getRecipientName(), o.getRecipientPhone(), o.getGiftMessage(), o.isGiftWrap(),
                o.isSenderAnonymous(), items, timeline, canCancel, canPay, o.getCreatedAt());
    }
}
