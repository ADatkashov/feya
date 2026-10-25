package app.feya.catalog;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class CatalogDtos {
    private CatalogDtos() {}

    public record CategoryDto(UUID id, String slug, String name) {}

    public record ProductSummary(UUID id, String slug, String name, String imageUrl, BigDecimal priceFrom,
                                 String currency, BigDecimal ratingAvg, int ratingCount, boolean available,
                                 boolean favorite, String category) {}

    public record ImageDto(String url, String alt) {}

    public record VariantDto(UUID id, String code, String label, BigDecimal price, Integer stemsCount,
                             boolean available, int maxQuantity) {}

    public record ProductDetail(UUID id, String slug, String name, String description, String composition,
                                String category, String categorySlug, List<ImageDto> images,
                                List<VariantDto> variants, BigDecimal priceFrom, String currency,
                                BigDecimal ratingAvg, int ratingCount, boolean available, boolean favorite,
                                int prepMinutes, Instant earliestDeliveryHint) {}

    public record BannerDto(UUID id, String title, String subtitle, String imageUrl, String promoCode,
                            String targetType, String targetValue) {}

    public record HomeResponse(List<BannerDto> banners, List<CategoryDto> categories, List<ProductSummary> featured,
                               List<ProductSummary> popular, List<ProductSummary> newArrivals,
                               List<ProductSummary> seasonal) {}
}
