package app.feya.catalog;

import app.feya.common.ApiException;
import app.feya.common.Lang;
import app.feya.common.MediaUrls;
import app.feya.common.PageResponse;
import app.feya.delivery.DeliveryService;
import app.feya.florist.InventoryService;
import app.feya.promotions.Banner;
import app.feya.promotions.BannerRepository;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class CatalogService {
    public record Query(String q, String category, String collection, BigDecimal minPrice, BigDecimal maxPrice,
                        String sort, UUID zoneId, boolean availableOnly, int page, int size) {}

    private final ProductRepository products;
    private final CategoryRepository categories;
    private final BannerRepository banners;
    private final FavoriteRepository favorites;
    private final InventoryService inventory;
    private final DeliveryService delivery;
    private final MediaUrls media;
    private final Clock clock;

    public CatalogService(ProductRepository products, CategoryRepository categories, BannerRepository banners,
                          FavoriteRepository favorites, InventoryService inventory, DeliveryService delivery,
                          MediaUrls media, Clock clock) {
        this.products = products;
        this.categories = categories;
        this.banners = banners;
        this.favorites = favorites;
        this.inventory = inventory;
        this.delivery = delivery;
        this.media = media;
        this.clock = clock;
    }

    public List<CatalogDtos.CategoryDto> categories(Lang lang) {
        return categories.findByActiveTrueOrderBySortOrder().stream()
                .map(c -> new CatalogDtos.CategoryDto(c.getId(), c.getSlug(), lang.pick(c.getName()))).toList();
    }

    public PageResponse<CatalogDtos.ProductSummary> search(Query query, Lang lang, UUID userId) {
        UUID zoneId = query.zoneId() != null ? delivery.getZone(query.zoneId()).getId() : delivery.defaultZone().getId();
        Specification<Product> spec = ProductSpecs.active();
        if (query.q() != null && !query.q().isBlank()) {
            spec = spec.and(ProductSpecs.text(query.q().trim()));
        }
        if (query.category() != null && !query.category().isBlank()) {
            spec = spec.and(ProductSpecs.category(query.category()));
        }
        if (query.minPrice() != null || query.maxPrice() != null) {
            spec = spec.and(ProductSpecs.price(query.minPrice(), query.maxPrice()));
        }
        String sort = query.sort() == null ? "popular" : query.sort();
        if (query.collection() != null) {
            switch (query.collection()) {
                case "featured" -> spec = spec.and(ProductSpecs.flag("featured"));
                case "seasonal" -> spec = spec.and(ProductSpecs.flag("seasonal"));
                case "gift" -> spec = spec.and(ProductSpecs.flag("gift"));
                case "new" -> sort = "new";
                case "popular" -> sort = "popular";
                default -> throw ApiException.badRequest("INVALID_COLLECTION", "Unknown collection");
            }
        }
        if (query.availableOnly()) {
            spec = spec.and(ProductSpecs.inStockInZone(zoneId));
        }
        Pageable pageable = PageRequest.of(Math.max(0, query.page()), Math.max(1, Math.min(query.size(), 50)), sortFor(sort));
        Page<Product> page = products.findAll(spec, pageable);
        return PageResponse.of(summaries(page, lang, userId, zoneId));
    }

    private static Sort sortFor(String sort) {
        return switch (sort) {
            case "new" -> Sort.by(Sort.Order.desc("createdAt"), Sort.Order.asc("id"));
            case "price_asc" -> Sort.by(Sort.Order.asc("priceFrom"), Sort.Order.asc("id"));
            case "price_desc" -> Sort.by(Sort.Order.desc("priceFrom"), Sort.Order.asc("id"));
            case "rating" -> Sort.by(Sort.Order.desc("ratingAvg").nullsLast(), Sort.Order.desc("ratingCount"), Sort.Order.asc("id"));
            case "popular" -> Sort.by(Sort.Order.desc("soldCount"), Sort.Order.desc("featured"), Sort.Order.asc("id"));
            default -> throw ApiException.badRequest("INVALID_SORT", "Unknown sort order");
        };
    }

    private Page<CatalogDtos.ProductSummary> summaries(Page<Product> page, Lang lang, UUID userId, UUID zoneId) {
        Set<UUID> favs = favoriteSet(userId, page.getContent());
        Map<UUID, Integer> stock = inventory.availability(zoneId);
        return page.map(p -> summary(p, lang, favs.contains(p.getId()), stock));
    }

    private List<CatalogDtos.ProductSummary> summaryList(List<Product> list, Lang lang, UUID userId, UUID zoneId) {
        Set<UUID> favs = favoriteSet(userId, list);
        Map<UUID, Integer> stock = inventory.availability(zoneId);
        return list.stream().map(p -> summary(p, lang, favs.contains(p.getId()), stock)).toList();
    }

    private Set<UUID> favoriteSet(UUID userId, List<Product> list) {
        if (userId == null || list.isEmpty()) {
            return Collections.emptySet();
        }
        return favorites.findFavoriteIds(userId, list.stream().map(Product::getId).toList());
    }

    CatalogDtos.ProductSummary summary(Product p, Lang lang, boolean favorite, Map<UUID, Integer> stock) {
        boolean available = p.activeVariants().stream().anyMatch(v -> stock.getOrDefault(v.getId(), 0) > 0);
        String image = p.getImages().isEmpty() ? null : media.resolve(p.getImages().get(0).getUrl());
        return new CatalogDtos.ProductSummary(p.getId(), p.getSlug(), lang.pick(p.getName()), image, p.getPriceFrom(),
                p.getCurrency(), p.getRatingAvg(), p.getRatingCount(), available, favorite, p.getCategory().getSlug());
    }

    public CatalogDtos.ProductDetail detail(String idOrSlug, UUID zoneId, Lang lang, UUID userId) {
        Product p = find(idOrSlug);
        UUID zone = zoneId != null ? delivery.getZone(zoneId).getId() : delivery.defaultZone().getId();
        Map<UUID, Integer> stock = inventory.availability(zone);
        List<CatalogDtos.VariantDto> variants = p.activeVariants().stream().map(v -> {
            int qty = stock.getOrDefault(v.getId(), 0);
            return new CatalogDtos.VariantDto(v.getId(), v.getCode().name(), lang.pick(v.getLabel()), v.getPrice(),
                    v.getStemsCount(), qty > 0, Math.min(qty, 20));
        }).toList();
        boolean fav = userId != null && !favorites.findFavoriteIds(userId, List.of(p.getId())).isEmpty();
        List<CatalogDtos.ImageDto> images = p.getImages().stream()
                .map(i -> new CatalogDtos.ImageDto(media.resolve(i.getUrl()), i.getAlt())).toList();
        return new CatalogDtos.ProductDetail(p.getId(), p.getSlug(), lang.pick(p.getName()),
                lang.pick(p.getDescription()), lang.pick(p.getComposition()), lang.pick(p.getCategory().getName()),
                p.getCategory().getSlug(), images, variants, p.getPriceFrom(), p.getCurrency(), p.getRatingAvg(),
                p.getRatingCount(), variants.stream().anyMatch(CatalogDtos.VariantDto::available), fav,
                p.getPrepMinutes(), clock.instant().plus(Duration.ofMinutes(p.getPrepMinutes())));
    }

    public List<CatalogDtos.ProductSummary> related(String idOrSlug, UUID zoneId, Lang lang, UUID userId) {
        Product p = find(idOrSlug);
        UUID zone = zoneId != null ? delivery.getZone(zoneId).getId() : delivery.defaultZone().getId();
        Specification<Product> spec = ProductSpecs.active().and(ProductSpecs.category(p.getCategory().getSlug()))
                .and(ProductSpecs.excluding(p.getId())).and(ProductSpecs.inStockInZone(zone));
        List<Product> list = products.findAll(spec, PageRequest.of(0, 6, sortFor("popular"))).getContent();
        return summaryList(list, lang, userId, zone);
    }

    public CatalogDtos.HomeResponse home(UUID zoneId, Lang lang, UUID userId) {
        UUID zone = zoneId != null ? delivery.getZone(zoneId).getId() : delivery.defaultZone().getId();
        List<CatalogDtos.BannerDto> bannerDtos = banners.findByActiveTrueOrderBySortOrder().stream()
                .map(b -> toDto(b, lang)).toList();
        Specification<Product> base = ProductSpecs.active().and(ProductSpecs.inStockInZone(zone));
        return new CatalogDtos.HomeResponse(bannerDtos, categories(lang),
                section(base.and(ProductSpecs.flag("featured")), "popular", lang, userId, zone),
                section(base, "popular", lang, userId, zone),
                section(base, "new", lang, userId, zone),
                section(base.and(ProductSpecs.flag("seasonal")), "popular", lang, userId, zone));
    }

    private List<CatalogDtos.ProductSummary> section(Specification<Product> spec, String sort, Lang lang, UUID userId, UUID zone) {
        return summaryList(products.findAll(spec, PageRequest.of(0, 10, sortFor(sort))).getContent(), lang, userId, zone);
    }

    private CatalogDtos.BannerDto toDto(Banner b, Lang lang) {
        return new CatalogDtos.BannerDto(b.getId(), lang.pick(b.getTitle()), lang.pick(b.getSubtitle()),
                media.resolve(b.getImageUrl()), b.getPromoCode(), b.getTargetType(), b.getTargetValue());
    }

    /** Favorite products regardless of stock, flagged with availability for the default zone. */
    public List<CatalogDtos.ProductSummary> favoriteProducts(UUID userId, Lang lang) {
        List<UUID> ids = favorites.findProductIds(userId);
        if (ids.isEmpty()) {
            return List.of();
        }
        Map<UUID, Product> byId = new java.util.HashMap<>();
        products.findAll(ProductSpecs.idIn(ids).and(ProductSpecs.active())).forEach(p -> byId.put(p.getId(), p));
        Map<UUID, Integer> stock = inventory.availability(delivery.defaultZone().getId());
        return ids.stream().map(byId::get).filter(java.util.Objects::nonNull)
                .map(p -> summary(p, lang, true, stock)).toList();
    }

    Product find(String idOrSlug) {
        try {
            UUID id = UUID.fromString(idOrSlug);
            return products.findById(id).filter(Product::isActive).orElseThrow(() -> ApiException.notFound("Product"));
        } catch (IllegalArgumentException notUuid) {
            return products.findBySlug(idOrSlug).filter(Product::isActive)
                    .orElseThrow(() -> ApiException.notFound("Product"));
        }
    }
}
