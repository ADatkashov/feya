package app.feya.payments;

import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "payments")
@Getter
@Setter
public class Payment {
    public enum Status { PENDING, SUCCEEDED, FAILED, REFUNDED, PARTIALLY_REFUNDED }

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    private UUID orderId;
    private String provider;
    private String method;
    @Enumerated(EnumType.STRING)
    private Status status = Status.PENDING;
    private BigDecimal amount;
    private BigDecimal refundedAmount = BigDecimal.ZERO;
    private String currency;
    private boolean sandbox;
    private String providerPaymentId;
    private String checkoutUrl;
    private String failureReason;
    private Instant createdAt;
    private Instant updatedAt;
    @Version
    private long version;

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
