package app.feya.catalog;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public final class ProductAdminDtos {
    private ProductAdminDtos() {}

    public record VariantUpsert(@NotNull VariantCode code, @NotEmpty Map<String, String> label,
                                @NotNull @DecimalMin("1") BigDecimal price, @Min(1) @Max(1001) Integer stemsCount,
                                boolean active) {}

    public record ProductUpsert(@NotBlank @Pattern(regexp = "[a-z0-9][a-z0-9-]{1,118}") String slug,
                                @NotBlank String categorySlug, @NotEmpty Map<String, String> name,
                                @NotEmpty Map<String, String> description, Map<String, String> composition,
                                boolean featured, boolean seasonal, boolean gift,
                                @Min(10) @Max(2880) int prepMinutes, boolean active,
                                @NotEmpty @Valid List<VariantUpsert> variants) {}

    public record ImageRef(UUID id, String url, String alt, int sortOrder) {}

    public record VariantAdmin(UUID id, VariantCode code, Map<String, String> label, BigDecimal price,
                               Integer stemsCount, boolean active) {}

    public record ProductAdmin(UUID id, String slug, String categorySlug, Map<String, String> name,
                               Map<String, String> description, Map<String, String> composition, boolean featured,
                               boolean seasonal, boolean gift, int prepMinutes, boolean active, BigDecimal priceFrom,
                               int soldCount, BigDecimal ratingAvg, int ratingCount, List<ImageRef> images,
                               List<VariantAdmin> variants, Instant updatedAt) {}

    public record ImageUrlRequest(@NotBlank @jakarta.validation.constraints.Size(max = 512) String url,
                                  @jakarta.validation.constraints.Size(max = 200) String alt) {}
}
