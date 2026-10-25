package app.feya.promotions;

import app.feya.common.ApiException;
import app.feya.common.Money;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PromoService {
    public record Result(PromoCode promo, BigDecimal discount) {}

    private final PromoCodeRepository promos;
    private final PromoRedemptionRepository redemptions;
    private final Clock clock;

    public PromoService(PromoCodeRepository promos, PromoRedemptionRepository redemptions, Clock clock) {
        this.promos = promos;
        this.redemptions = redemptions;
        this.clock = clock;
    }

    /** Validates a code against a subtotal and (when known) the customer's usage history. */
    @Transactional(readOnly = true)
    public Result evaluate(String code, BigDecimal subtotal, UUID userId) {
        PromoCode p = promos.findByCodeIgnoreCase(code.trim())
                .filter(PromoCode::isActive)
                .orElseThrow(() -> ApiException.unprocessable("PROMO_NOT_FOUND", "Promo code not found"));
        Instant now = clock.instant();
        if (p.getValidFrom() != null && now.isBefore(p.getValidFrom())
                || p.getValidUntil() != null && now.isAfter(p.getValidUntil())) {
            throw ApiException.unprocessable("PROMO_EXPIRED", "Promo code is not valid at this time");
        }
        if (subtotal.compareTo(p.getMinOrder()) < 0) {
            throw ApiException.unprocessable("PROMO_MIN_ORDER", "Order total is below the promo minimum");
        }
        if (p.getUsageLimit() != null && p.getUsedCount() >= p.getUsageLimit()) {
            throw ApiException.unprocessable("PROMO_LIMIT_REACHED", "Promo code usage limit reached");
        }
        if (userId != null && p.getPerUserLimit() != null
                && redemptions.countByPromoIdAndUserId(p.getId(), userId) >= p.getPerUserLimit()) {
            throw ApiException.unprocessable("PROMO_ALREADY_USED", "You have already used this promo code");
        }
        BigDecimal discount;
        if (p.getType() == PromoCode.Type.PERCENT) {
            discount = Money.wholeTenge(subtotal.multiply(p.getValue()).divide(BigDecimal.valueOf(100)));
        } else {
            discount = Money.scale(p.getValue());
        }
        if (p.getMaxDiscount() != null) {
            discount = Money.min(discount, p.getMaxDiscount());
        }
        discount = Money.min(discount, subtotal);
        return new Result(p, Money.scale(discount));
    }

    /** Consumes one use of the code for an order. Must run in the order-creating transaction. */
    @Transactional
    public void redeem(PromoCode promo, UUID userId, UUID orderId) {
        if (promos.tryIncrementUsage(promo.getId()) == 0) {
            throw ApiException.unprocessable("PROMO_LIMIT_REACHED", "Promo code usage limit reached");
        }
        PromoRedemption r = new PromoRedemption();
        r.setPromoId(promo.getId());
        r.setUserId(userId);
        r.setOrderId(orderId);
        redemptions.save(r);
    }

    /** Returns the use when an unpaid order is cancelled. */
    @Transactional
    public void release(UUID orderId) {
        redemptions.findByOrderId(orderId).ifPresent(r -> {
            promos.decrementUsage(r.getPromoId());
            redemptions.delete(r);
        });
    }
}
