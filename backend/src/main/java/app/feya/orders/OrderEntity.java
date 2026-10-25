package app.feya.orders;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "orders")
@Getter
@Setter
public class OrderEntity {
    public enum PaymentState { UNPAID, PAID, FAILED, REFUNDED }

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @Column(unique = true)
    private String number;
    private UUID userId;
    private UUID floristId;
    private UUID zoneId;
    private UUID courierId;

    @Enumerated(EnumType.STRING)
    private OrderStatus status;
    @Enumerated(EnumType.STRING)
    private PaymentState paymentStatus = PaymentState.UNPAID;

    private String currency = "KZT";
    private BigDecimal subtotal;
    private BigDecimal discount = BigDecimal.ZERO;
    private BigDecimal deliveryFee = BigDecimal.ZERO;
    private BigDecimal giftWrapFee = BigDecimal.ZERO;
    private BigDecimal total;
    private String promoCode;

    private boolean deliveryAsap;
    private LocalDate deliveryDate;
    private UUID slotTemplateId;
    private LocalTime slotStart;
    private LocalTime slotEnd;
    private Instant etaAt;

    private String recipientName;
    private String recipientPhone;
    private String addrCity;
    private String addrStreet;
    private String addrBuilding;
    private String addrApartment;
    private String addrEntrance;
    private String addrFloor;
    private String addrIntercom;
    private BigDecimal addrLatitude;
    private BigDecimal addrLongitude;
    private String instructions;

    private boolean senderAnonymous;
    private String giftMessage;
    private boolean giftWrap;
    private String idempotencyKey;
    private Instant termsAcceptedAt;
    private String cancelReason;

    private Instant createdAt;
    private Instant updatedAt;
    private Instant paidAt;
    private Instant deliveredAt;
    private Instant cancelledAt;

    @Version
    private long version;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("productName ASC")
    private List<OrderItem> items = new ArrayList<>();

    @PrePersist
    void onCreate() {
        createdAt = Instant.now();
        updatedAt = createdAt;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }
}
