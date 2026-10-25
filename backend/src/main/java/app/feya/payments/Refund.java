package app.feya.payments;

import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "refunds")
@Getter
@Setter
public class Refund {
    public enum Status { REQUESTED, COMPLETED, FAILED }

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    private UUID paymentId;
    private UUID orderId;
    private BigDecimal amount;
    private String reason;
    @Enumerated(EnumType.STRING)
    private Status status = Status.REQUESTED;
    private UUID requestedBy;
    private Instant createdAt = Instant.now();
    private Instant processedAt;
}
