package app.feya.cart;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public final class CartDtos {
    private CartDtos() {}

    public record Line(@NotNull UUID variantId, @Min(1) @Max(99) int quantity) {}

    public record SlotChoice(@NotNull UUID templateId, @NotNull LocalDate date) {}

    /** Client-supplied selections only; prices are never accepted from the client. */
    public record QuoteRequest(@NotEmpty @Size(max = 30) List<@Valid Line> items, @Size(max = 40) String promoCode,
                               UUID zoneId, @Valid SlotChoice slot, boolean asap, boolean giftWrap) {}

    public record QuoteLine(UUID variantId, UUID productId, String productName, String variantLabel, String imageUrl,
                            BigDecimal unitPrice, int quantity, BigDecimal lineTotal, boolean available,
                            int maxQuantity, String issue) {}

    public record PromoInfo(String code, boolean applied, BigDecimal discount, String error) {}

    public record QuoteResponse(List<QuoteLine> lines, BigDecimal subtotal, BigDecimal discount, PromoInfo promo,
                                BigDecimal deliveryFee, BigDecimal giftWrapFee, BigDecimal total, String currency,
                                UUID zoneId, boolean valid, List<String> issues) {}
}
