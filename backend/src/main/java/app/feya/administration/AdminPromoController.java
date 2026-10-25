package app.feya.administration;

import app.feya.common.ApiException;
import app.feya.common.AuditService;
import app.feya.promotions.Banner;
import app.feya.promotions.BannerRepository;
import app.feya.promotions.PromoCode;
import app.feya.promotions.PromoCodeRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminPromoController {
    public record PromoUpsert(@NotNull @Pattern(regexp = "[A-Za-z0-9_-]{3,40}") String code,
                              @NotNull PromoCode.Type type, @NotNull @DecimalMin("0.01") BigDecimal value,
                              @DecimalMin("0") BigDecimal minOrder, @DecimalMin("0") BigDecimal maxDiscount,
                              Instant validFrom, Instant validUntil, Integer usageLimit, Integer perUserLimit,
                              boolean active) {}

    public record PromoAdmin(UUID id, String code, PromoCode.Type type, BigDecimal value, BigDecimal minOrder,
                             BigDecimal maxDiscount, Instant validFrom, Instant validUntil, Integer usageLimit,
                             Integer perUserLimit, int usedCount, boolean active) {}

    public record BannerUpsert(@NotEmpty Map<String, String> title, Map<String, String> subtitle, String imageUrl,
                               String promoCode, String targetType, String targetValue, int sortOrder, boolean active) {}

    public record BannerAdmin(UUID id, Map<String, String> title, Map<String, String> subtitle, String imageUrl,
                              String promoCode, String targetType, String targetValue, int sortOrder, boolean active) {}

    private final PromoCodeRepository promos;
    private final BannerRepository banners;
    private final AuditService audit;

    public AdminPromoController(PromoCodeRepository promos, BannerRepository banners, AuditService audit) {
        this.promos = promos;
        this.banners = banners;
        this.audit = audit;
    }

    @GetMapping("/promos")
    public List<PromoAdmin> promos() {
        return promos.findAll(org.springframework.data.domain.Sort.by("code")).stream().map(this::dto).toList();
    }

    @PostMapping("/promos")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public PromoAdmin create(@Valid @RequestBody PromoUpsert req) {
        if (promos.findByCodeIgnoreCase(req.code()).isPresent()) {
            throw ApiException.conflict("CODE_TAKEN", "Promo code already exists");
        }
        PromoCode p = new PromoCode();
        apply(p, req);
        p = promos.save(p);
        audit.record("PROMO_CREATED", "PROMO", p.getId(), p.getCode());
        return dto(p);
    }

    @PutMapping("/promos/{id}")
    @Transactional
    public PromoAdmin update(@PathVariable UUID id, @Valid @RequestBody PromoUpsert req) {
        PromoCode p = promos.findById(id).orElseThrow(() -> ApiException.notFound("Promo"));
        promos.findByCodeIgnoreCase(req.code()).filter(o -> !o.getId().equals(id)).ifPresent(o -> {
            throw ApiException.conflict("CODE_TAKEN", "Promo code already exists");
        });
        apply(p, req);
        audit.record("PROMO_UPDATED", "PROMO", p.getId(), p.getCode());
        return dto(p);
    }

    private void apply(PromoCode p, PromoUpsert r) {
        if (r.type() == PromoCode.Type.PERCENT && r.value().compareTo(BigDecimal.valueOf(100)) > 0) {
            throw ApiException.badRequest("INVALID_PROMO", "Percent cannot exceed 100");
        }
        if (r.validFrom() != null && r.validUntil() != null && !r.validUntil().isAfter(r.validFrom())) {
            throw ApiException.badRequest("INVALID_PROMO", "Validity end must be after start");
        }
        p.setCode(r.code().toUpperCase());
        p.setType(r.type());
        p.setValue(r.value());
        p.setMinOrder(r.minOrder() == null ? BigDecimal.ZERO : r.minOrder());
        p.setMaxDiscount(r.maxDiscount());
        p.setValidFrom(r.validFrom());
        p.setValidUntil(r.validUntil());
        p.setUsageLimit(r.usageLimit());
        p.setPerUserLimit(r.perUserLimit());
        p.setActive(r.active());
    }

    @GetMapping("/banners")
    public List<BannerAdmin> banners() {
        return banners.findAll(org.springframework.data.domain.Sort.by("sortOrder")).stream().map(this::dto).toList();
    }

    @PostMapping("/banners")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public BannerAdmin createBanner(@Valid @RequestBody BannerUpsert req) {
        Banner b = new Banner();
        apply(b, req);
        b = banners.save(b);
        audit.record("BANNER_CREATED", "BANNER", b.getId(), null);
        return dto(b);
    }

    @PutMapping("/banners/{id}")
    @Transactional
    public BannerAdmin updateBanner(@PathVariable UUID id, @Valid @RequestBody BannerUpsert req) {
        Banner b = banners.findById(id).orElseThrow(() -> ApiException.notFound("Banner"));
        apply(b, req);
        audit.record("BANNER_UPDATED", "BANNER", b.getId(), null);
        return dto(b);
    }

    private void apply(Banner b, BannerUpsert r) {
        if (r.title().get("ru") == null || r.title().get("ru").isBlank()) {
            throw ApiException.badRequest("RU_TEXT_REQUIRED", "Russian title is required");
        }
        b.setTitle(r.title());
        b.setSubtitle(r.subtitle() == null ? Map.of() : r.subtitle());
        b.setImageUrl(r.imageUrl());
        b.setPromoCode(r.promoCode());
        b.setTargetType(r.targetType());
        b.setTargetValue(r.targetValue());
        b.setSortOrder(r.sortOrder());
        b.setActive(r.active());
    }

    private PromoAdmin dto(PromoCode p) {
        return new PromoAdmin(p.getId(), p.getCode(), p.getType(), p.getValue(), p.getMinOrder(), p.getMaxDiscount(),
                p.getValidFrom(), p.getValidUntil(), p.getUsageLimit(), p.getPerUserLimit(), p.getUsedCount(), p.isActive());
    }

    private BannerAdmin dto(Banner b) {
        return new BannerAdmin(b.getId(), b.getTitle(), b.getSubtitle(), b.getImageUrl(), b.getPromoCode(),
                b.getTargetType(), b.getTargetValue(), b.getSortOrder(), b.isActive());
    }
}
