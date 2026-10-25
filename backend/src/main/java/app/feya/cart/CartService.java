package app.feya.cart;

import app.feya.catalog.Product;
import app.feya.catalog.ProductRepository;
import app.feya.catalog.ProductVariant;
import app.feya.common.ApiException;
import app.feya.common.FeyaProperties;
import app.feya.common.Lang;
import app.feya.common.MediaUrls;
import app.feya.common.Money;
import app.feya.delivery.DeliveryService;
import app.feya.delivery.DeliverySlotTemplate;
import app.feya.delivery.DeliveryZone;
import app.feya.delivery.DeliverySlotTemplateRepository;
import app.feya.florist.InventoryService;
import app.feya.promotions.PromoCode;
import app.feya.promotions.PromoService;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Authoritative pricing. Prices come from the database; the client only sends variant ids and quantities.
 * The same code path prices both quotes and real orders.
 */
@Service
@Transactional(readOnly = true)
public class CartService {
    /** Internal pricing result, including entities needed to create an order. */
    public record Priced(DeliveryZone zone, List<PricedLine> lines, BigDecimal subtotal, BigDecimal discount,
                         PromoCode promo, String promoError, BigDecimal deliveryFee, BigDecimal giftWrapFee,
                         BigDecimal total, List<String> issues) {
        public boolean valid() {
            return issues.isEmpty();
        }

        public Map<UUID, Integer> quantities() {
            Map<UUID, Integer> m = new LinkedHashMap<>();
            lines.forEach(l -> m.put(l.variant().getId(), l.quantity()));
            return m;
        }
    }

    public record PricedLine(ProductVariant variant, Product product, int quantity, BigDecimal unitPrice,
                             BigDecimal lineTotal, boolean available, int maxQuantity, String issue) {}

    private final ProductRepository products;
    private final InventoryService inventory;
    private final DeliveryService delivery;
    private final DeliverySlotTemplateRepository slotTemplates;
    private final PromoService promos;
    private final MediaUrls media;
    private final FeyaProperties props;

    public CartService(ProductRepository products, InventoryService inventory, DeliveryService delivery,
                       DeliverySlotTemplateRepository slotTemplates, PromoService promos, MediaUrls media,
                       FeyaProperties props) {
        this.products = products;
        this.inventory = inventory;
        this.delivery = delivery;
        this.slotTemplates = slotTemplates;
        this.promos = promos;
        this.media = media;
        this.props = props;
    }

    public Priced price(CartDtos.QuoteRequest req, UUID userId, DeliveryZone zoneOverride, BigDecimal slotSurcharge) {
        DeliveryZone zone = zoneOverride != null ? zoneOverride
                : req.zoneId() != null ? delivery.getZone(req.zoneId()) : delivery.defaultZone();

        // Merge duplicate variants so quantities are validated as a whole.
        Map<UUID, Integer> requested = new LinkedHashMap<>();
        for (CartDtos.Line l : req.items()) {
            requested.merge(l.variantId(), l.quantity(), Integer::sum);
        }
        Map<UUID, ProductVariant> variants = new LinkedHashMap<>();
        products.findVariants(requested.keySet()).forEach(v -> variants.put(v.getId(), v));
        Map<UUID, Integer> stock = inventory.availability(zone.getId());

        List<PricedLine> lines = new ArrayList<>();
        List<String> issues = new ArrayList<>();
        BigDecimal subtotal = Money.ZERO;
        int maxPerLine = props.orders().maxQuantityPerLine();
        for (Map.Entry<UUID, Integer> e : requested.entrySet()) {
            ProductVariant v = variants.get(e.getKey());
            if (v == null || !v.isActive() || !v.getProduct().isActive()) {
                throw ApiException.unprocessable("VARIANT_NOT_FOUND", "Item is no longer in the catalog");
            }
            int qty = e.getValue();
            int available = Math.min(stock.getOrDefault(v.getId(), 0), maxPerLine);
            String issue = null;
            if (qty > maxPerLine) {
                issue = "QUANTITY_LIMIT";
            } else if (available == 0) {
                issue = "UNAVAILABLE";
            } else if (qty > available) {
                issue = "INSUFFICIENT_STOCK";
            }
            if (issue != null) {
                issues.add(issue + ":" + v.getId());
            }
            BigDecimal lineTotal = Money.scale(v.getPrice().multiply(BigDecimal.valueOf(qty)));
            subtotal = subtotal.add(lineTotal);
            lines.add(new PricedLine(v, v.getProduct(), qty, v.getPrice(), lineTotal, available > 0, available, issue));
        }

        PromoCode promo = null;
        String promoError = null;
        BigDecimal discount = Money.ZERO;
        if (req.promoCode() != null && !req.promoCode().isBlank()) {
            try {
                PromoService.Result r = promos.evaluate(req.promoCode(), subtotal, userId);
                promo = r.promo();
                discount = r.discount();
            } catch (ApiException ex) {
                promoError = ex.code();
            }
        }
        BigDecimal afterDiscount = subtotal.subtract(discount);
        BigDecimal deliveryFee = delivery.fee(zone, afterDiscount, slotSurcharge, req.asap());
        BigDecimal giftWrap = req.giftWrap() ? Money.scale(props.orders().giftWrapFee()) : Money.ZERO;
        BigDecimal total = afterDiscount.add(deliveryFee).add(giftWrap);
        return new Priced(zone, lines, subtotal, discount, promo, promoError, deliveryFee, giftWrap, total, issues);
    }

    public CartDtos.QuoteResponse quote(CartDtos.QuoteRequest req, UUID userId, Lang lang) {
        BigDecimal surcharge = null;
        DeliveryZone zone = req.zoneId() != null ? delivery.getZone(req.zoneId()) : delivery.defaultZone();
        if (req.slot() != null) {
            DeliverySlotTemplate t = slotTemplates.findById(req.slot().templateId())
                    .filter(x -> x.isActive() && x.getZoneId().equals(zone.getId()))
                    .orElseThrow(() -> ApiException.unprocessable("SLOT_UNAVAILABLE", "Delivery slot is not available"));
            surcharge = t.getSurcharge();
        }
        if (req.slot() != null && req.asap()) {
            throw ApiException.badRequest("SLOT_CONFLICT", "Choose either ASAP delivery or a time slot");
        }
        Priced p = price(req, userId, zone, surcharge);
        List<CartDtos.QuoteLine> lines = p.lines().stream().map(l -> new CartDtos.QuoteLine(
                l.variant().getId(), l.product().getId(), lang.pick(l.product().getName()),
                lang.pick(l.variant().getLabel()),
                l.product().getImages().isEmpty() ? null : media.resolve(l.product().getImages().get(0).getUrl()),
                l.unitPrice(), l.quantity(), l.lineTotal(), l.available(), l.maxQuantity(), l.issue())).toList();
        CartDtos.PromoInfo promoInfo = req.promoCode() == null || req.promoCode().isBlank() ? null
                : new CartDtos.PromoInfo(req.promoCode().trim().toUpperCase(), p.promo() != null, p.discount(), p.promoError());
        return new CartDtos.QuoteResponse(lines, p.subtotal(), p.discount(), promoInfo, p.deliveryFee(),
                p.giftWrapFee(), p.total(), p.zone().getCurrency(), p.zone().getId(), p.valid(), p.issues());
    }

    static ApiException invalid(String code, String msg) {
        return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, code, msg);
    }
}
