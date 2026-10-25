package app.feya.catalog;

import java.util.Collection;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface FavoriteRepository extends JpaRepository<Favorite, Favorite.Key> {
    @Query("select f.id.productId from Favorite f where f.id.userId = :userId and f.id.productId in :productIds")
    Set<UUID> findFavoriteIds(UUID userId, Collection<UUID> productIds);

    @Query("select f.id.productId from Favorite f where f.id.userId = :userId order by f.createdAt desc")
    List<UUID> findProductIds(UUID userId);
}
