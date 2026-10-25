package app.feya.payments;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RefundRepository extends JpaRepository<Refund, UUID> {
    List<Refund> findByOrderId(UUID orderId);

    Optional<Refund> findFirstByPaymentIdAndStatus(UUID paymentId, Refund.Status status);
}
