package app.feya.florist;

import app.feya.catalog.ProductRepository;
import app.feya.catalog.ProductVariant;
import app.feya.common.ApiException;
import app.feya.common.AuditService;
import app.feya.common.Lang;
import app.feya.common.PageResponse;
import app.feya.orders.Actor;
import app.feya.orders.OrderEntity;
import app.feya.orders.OrderItem;
import app.feya.orders.OrderRepository;
import app.feya.orders.OrderService;
import app.feya.orders.OrderStateMachine;
import app.feya.orders.OrderStatus;
import app.feya.security.Auth;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Florist workspace: incoming orders and stock. Admins may operate any shop by passing floristId. */
@RestController
@RequestMapping({"/api/v1/florist"})
public class FloristController {
    public record RejectRequest(@Size(max = 255) String reason) {}

    public record FloristItem(String name, String variantLabel, int quantity) {}

    public record FloristOrder(UUID id, String number, OrderStatus status, List<FloristItem> items,
                               boolean asap, LocalDate deliveryDate, LocalTime slotStart, LocalTime slotEnd,
                               Instant eta, String giftMessage, boolean giftWrap, boolean anonymousSender,
                               String instructions, List<OrderStatus> allowedNext, Instant createdAt) {}

    public record StockRow(UUID variantId, UUID productId, String productName, String variantCode,
                           String variantLabel, int quantity) {}

    public record StockUpdate(@Min(0) @Max(100000) int quantity) {}

    private final OrderRepository orders;
    private final OrderService orderService;
    private final InventoryRepository inventory;
    private final ProductRepository products;
    private final FloristContext context;
    private final AuditService audit;

    public FloristController(OrderRepository orders, OrderService orderService, InventoryRepository inventory,
                             ProductRepository products, FloristContext context, AuditService audit) {
        this.orders = orders;
        this.orderService = orderService;
        this.inventory = inventory;
        this.products = products;
        this.context = context;
        this.audit = audit;
    }

    @GetMapping("/orders")
    @Transactional(readOnly = true)
    public PageResponse<FloristOrder> orders(@RequestParam(required = false) UUID floristId,
                                             @RequestParam(required = false) List<OrderStatus> status,
                                             @RequestParam(defaultValue = "0") int page,
                                             @RequestParam(defaultValue = "20") int size) {
        UUID fid = context.resolve(floristId);
        Specification<OrderEntity> spec = (r, q, cb) -> cb.conjunction();
        if (fid != null) {
            spec = spec.and((r, q, cb) -> cb.equal(r.get("floristId"), fid));
        }
        List<OrderStatus> wanted = status == null || status.isEmpty()
                ? List.of(OrderStatus.PAID, OrderStatus.CONFIRMED, OrderStatus.PREPARING, OrderStatus.READY_FOR_PICKUP)
                : status;
        spec = spec.and((r, q, cb) -> r.get("status").in(wanted));
        var result = orders.findAll(spec, PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 50)),
                Sort.by("etaAt").ascending()));
        Actor actor = Auth.hasRole("ADMIN") ? Actor.ADMIN : Actor.FLORIST;
        return PageResponse.of(result, o -> toDto(o, actor));
    }

    @PostMapping("/orders/{id}/accept")
    @Transactional
    public FloristOrder accept(@PathVariable UUID id) {
        return act(id, OrderStatus.CONFIRMED, null);
    }

    @PostMapping("/orders/{id}/reject")
    @Transactional
    public FloristOrder reject(@PathVariable UUID id, @Valid @RequestBody(required = false) RejectRequest req) {
        return act(id, OrderStatus.CANCELLED, req == null || req.reason() == null ? "rejected by florist" : req.reason());
    }

    @PostMapping("/orders/{id}/preparing")
    @Transactional
    public FloristOrder preparing(@PathVariable UUID id) {
        return act(id, OrderStatus.PREPARING, null);
    }

    @PostMapping("/orders/{id}/ready")
    @Transactional
    public FloristOrder ready(@PathVariable UUID id) {
        return act(id, OrderStatus.READY_FOR_PICKUP, null);
    }

    private FloristOrder act(UUID id, OrderStatus to, String note) {
        OrderEntity o = orders.lockById(id).orElseThrow(() -> ApiException.notFound("Order"));
        UUID fid = context.resolve(null); // null for admins (any shop), the caller's own shop for florists
        if (fid != null && !fid.equals(o.getFloristId())) {
            throw ApiException.notFound("Order");
        }
        Actor actor = Auth.hasRole("ADMIN") ? Actor.ADMIN : Actor.FLORIST;
        orderService.transition(o, to, actor, Auth.userId(), note);
        return toDto(o, actor);
    }

    @GetMapping("/inventory")
    @Transactional(readOnly = true)
    public List<StockRow> stock(@RequestParam(required = false) UUID floristId, Lang lang) {
        UUID fid = context.require(floristId);
        Map<UUID, Integer> qty = inventory.findByFloristId(fid).stream()
                .collect(Collectors.toMap(Inventory::getVariantId, Inventory::getQuantity));
        List<StockRow> rows = new ArrayList<>();
        for (var p : products.findAll(Sort.by("slug"))) {
            for (ProductVariant v : p.getVariants()) {
                rows.add(new StockRow(v.getId(), p.getId(), lang.pick(p.getName()), v.getCode().name(),
                        lang.pick(v.getLabel()), qty.getOrDefault(v.getId(), 0)));
            }
        }
        return rows;
    }

    @PutMapping("/inventory/{variantId}")
    @Transactional
    public StockRow setStock(@PathVariable UUID variantId, @RequestParam(required = false) UUID floristId,
                             @Valid @RequestBody StockUpdate req, Lang lang) {
        UUID fid = context.require(floristId);
        ProductVariant v = products.findVariants(List.of(variantId)).stream().findFirst()
                .orElseThrow(() -> ApiException.notFound("Variant"));
        Inventory row = inventory.findByFloristIdAndVariantId(fid, variantId).orElseGet(() -> {
            Inventory i = new Inventory();
            i.setFloristId(fid);
            i.setVariantId(variantId);
            return i;
        });
        int before = row.getQuantity();
        row.setQuantity(req.quantity());
        row.setUpdatedAt(Instant.now());
        inventory.save(row);
        audit.record("INVENTORY_SET", "INVENTORY", fid + "/" + variantId, before + "->" + req.quantity());
        return new StockRow(variantId, v.getProduct().getId(), lang.pick(v.getProduct().getName()), v.getCode().name(),
                lang.pick(v.getLabel()), req.quantity());
    }

    FloristOrder toDto(OrderEntity o, Actor actor) {
        List<FloristItem> items = o.getItems().stream()
                .map((OrderItem i) -> new FloristItem(i.getProductName(), i.getVariantLabel(), i.getQuantity())).toList();
        List<OrderStatus> next = OrderStateMachine.allowedTargets(o.getStatus(), actor).stream().sorted().toList();
        return new FloristOrder(o.getId(), o.getNumber(), o.getStatus(), items, o.isDeliveryAsap(), o.getDeliveryDate(),
                o.getSlotStart(), o.getSlotEnd(), o.getEtaAt(), o.getGiftMessage(), o.isGiftWrap(),
                o.isSenderAnonymous(), o.getInstructions(), next, o.getCreatedAt());
    }
}
