package app.feya.orders;

import app.feya.cart.CartDtos;
import jakarta.validation.Valid;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

public final class OrderDtos {
    private OrderDtos() {}

    public record InlineAddress(@NotBlank @Size(max = 80) String city, @NotBlank @Size(max = 160) String street,
                                @NotBlank @Size(max = 20) String building, @Size(max = 20) String apartment,
                                @Size(max = 20) String entrance, @Size(max = 20) String floor,
                                @Size(max = 40) String intercom, BigDecimal latitude, BigDecimal longitude,
                                boolean saveAddress) {}

    public record Recipient(@NotBlank @Size(max = 120) String name, @NotBlank @Size(max = 24) String phone) {}

    public record CreateOrderRequest(@NotEmpty @Size(max = 30) @Valid List<CartDtos.Line> items,
                                     @Size(max = 40) String promoCode, UUID addressId, @Valid InlineAddress address,
                                     @NotNull @Valid Recipient recipient, @Valid CartDtos.SlotChoice slot,
                                     boolean asap, @Size(max = 500) String giftMessage, boolean anonymousSender,
                                     boolean giftWrap, @Size(max = 500) String instructions,
                                     @AssertTrue(message = "Terms must be accepted") boolean acceptTerms) {}

    public record CancelRequest(@Size(max = 255) String reason) {}

    public record ItemDto(UUID productId, UUID variantId, String name, String variantLabel, String imageUrl,
                          BigDecimal unitPrice, int quantity, BigDecimal lineTotal) {}

    public record AddressDto(String city, String street, String building, String apartment, String entrance,
                             String floor, String intercom, BigDecimal latitude, BigDecimal longitude) {}

    public record TimelineEntry(OrderStatus status, Instant at, String note) {}

    public record OrderDetail(UUID id, String number, OrderStatus status, OrderEntity.PaymentState paymentStatus,
                              String currency, BigDecimal subtotal, BigDecimal discount, BigDecimal deliveryFee,
                              BigDecimal giftWrapFee, BigDecimal total, String promoCode, boolean asap,
                              LocalDate deliveryDate, LocalTime slotStart, LocalTime slotEnd, Instant eta,
                              AddressDto address, String instructions, String recipientName, String recipientPhone,
                              String giftMessage, boolean giftWrap, boolean anonymousSender, List<ItemDto> items,
                              List<TimelineEntry> timeline, boolean canCancel, boolean canPay, Instant createdAt) {}

    public record OrderSummary(UUID id, String number, OrderStatus status, BigDecimal total, String currency,
                               int itemCount, String firstItemName, String firstItemImage, LocalDate deliveryDate,
                               LocalTime slotStart, LocalTime slotEnd, boolean asap, Instant createdAt) {}
}
