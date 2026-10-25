package app.feya.catalog;

import jakarta.persistence.Embeddable;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import java.util.UUID;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "favorites")
@Getter
@Setter
@NoArgsConstructor
public class Favorite {
    @Embeddable
    @Getter
    @Setter
    @NoArgsConstructor
    @EqualsAndHashCode
    public static class Key implements Serializable {
        private UUID userId;
        private UUID productId;

        public Key(UUID userId, UUID productId) {
            this.userId = userId;
            this.productId = productId;
        }
    }

    @EmbeddedId
    private Key id;
    private Instant createdAt = Instant.now();

    public Favorite(UUID userId, UUID productId) {
        this.id = new Key(userId, productId);
    }
}
