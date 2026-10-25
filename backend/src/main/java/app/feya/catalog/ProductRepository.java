package app.feya.catalog;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface ProductRepository extends JpaRepository<Product, UUID>, JpaSpecificationExecutor<Product> {
    Optional<Product> findBySlug(String slug);

    @Query("select v from ProductVariant v join fetch v.product where v.id in :ids")
    List<ProductVariant> findVariants(Collection<UUID> ids);

    @Modifying
    @Query("update Product p set p.soldCount = p.soldCount + :qty where p.id = :id")
    void incrementSold(UUID id, int qty);
}
