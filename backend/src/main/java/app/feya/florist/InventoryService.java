package app.feya.florist;

import app.feya.common.ApiException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Stock is tracked per florist and variant. An order is fulfilled entirely by one florist, so availability for a
 * delivery zone is the best single-florist quantity.
 */
@Service
public class InventoryService {
    private final InventoryRepository inventory;
    private final FloristRepository florists;

    public InventoryService(InventoryRepository inventory, FloristRepository florists) {
        this.inventory = inventory;
        this.florists = florists;
    }

    @Transactional(readOnly = true)
    public Map<UUID, Integer> availability(UUID zoneId) {
        Map<UUID, Integer> out = new HashMap<>();
        for (Object[] row : inventory.bestQuantityByVariant(zoneId)) {
            out.put((UUID) row[0], ((Number) row[1]).intValue());
        }
        return out;
    }

    /** Florist serving the zone that can fulfil every requested line, preferring the highest priority. */
    @Transactional(readOnly = true)
    public Optional<Florist> pickFlorist(UUID zoneId, Map<UUID, Integer> needed) {
        for (Florist f : florists.findActiveByZone(zoneId)) {
            Map<UUID, Integer> stock = new HashMap<>();
            inventory.findByFloristId(f.getId()).forEach(i -> stock.put(i.getVariantId(), i.getQuantity()));
            boolean ok = needed.entrySet().stream().allMatch(e -> stock.getOrDefault(e.getKey(), 0) >= e.getValue());
            if (ok) {
                return Optional.of(f);
            }
        }
        return Optional.empty();
    }

    /** Atomically decrements stock under row locks. */
    @Transactional
    public void reserve(UUID floristId, Map<UUID, Integer> needed) {
        List<Inventory> rows = inventory.lockForUpdate(floristId, needed.keySet());
        Map<UUID, Inventory> byVariant = new HashMap<>();
        rows.forEach(r -> byVariant.put(r.getVariantId(), r));
        for (Map.Entry<UUID, Integer> e : needed.entrySet()) {
            Inventory row = byVariant.get(e.getKey());
            if (row == null || row.getQuantity() < e.getValue()) {
                throw ApiException.conflict("OUT_OF_STOCK", "Some items are no longer available");
            }
        }
        needed.forEach((variantId, qty) -> {
            Inventory row = byVariant.get(variantId);
            row.setQuantity(row.getQuantity() - qty);
            row.setUpdatedAt(java.time.Instant.now());
        });
    }

    @Transactional
    public void release(UUID floristId, Map<UUID, Integer> items) {
        List<Inventory> rows = inventory.lockForUpdate(floristId, items.keySet());
        rows.forEach(r -> {
            r.setQuantity(r.getQuantity() + items.getOrDefault(r.getVariantId(), 0));
            r.setUpdatedAt(java.time.Instant.now());
        });
    }
}
