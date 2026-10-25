package app.feya.payments;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentRepository extends JpaRepository<Payment, UUID> {
    List<Payment> findByOrderIdOrderByCreatedAtDesc(UUID orderId);

    Optional<Payment> findFirstByOrderIdAndStatus(UUID orderId, Payment.Status status);

    Optional<Payment> findByProviderAndProviderPaymentId(String provider, String providerPaymentId);
}
