package app.feya.catalog;

import app.feya.common.ApiException;
import app.feya.common.AuditService;
import app.feya.common.FeyaProperties;
import app.feya.common.MediaUrls;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/** Product management shared by the florist and admin APIs. */
@Service
public class ProductAdminService {
    private static final Map<String, String> IMAGE_TYPES = Map.of("image/jpeg", ".jpg", "image/png", ".png",
            "image/webp", ".webp");

    private final ProductRepository products;
    private final CategoryRepository categories;
    private final AuditService audit;
    private final FeyaProperties props;
    private final MediaUrls media;

    public ProductAdminService(ProductRepository products, CategoryRepository categories, AuditService audit,
                               FeyaProperties props, MediaUrls media) {
        this.products = products;
        this.categories = categories;
        this.audit = audit;
        this.props = props;
        this.media = media;
    }

    @Transactional(readOnly = true)
    public Page<ProductAdminDtos.ProductAdmin> list(String q, int page, int size) {
        Specification<Product> spec = (r, cq, cb) -> cb.conjunction();
        if (q != null && !q.isBlank()) {
            spec = spec.and(ProductSpecs.text(q.trim()));
        }
        return products.findAll(spec, PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 100)),
                Sort.by(Sort.Order.desc("updatedAt")))).map(this::toDto);
    }

    @Transactional(readOnly = true)
    public ProductAdminDtos.ProductAdmin get(UUID id) {
        return toDto(products.findById(id).orElseThrow(() -> ApiException.notFound("Product")));
    }

    @Transactional
    public ProductAdminDtos.ProductAdmin upsert(UUID id, ProductAdminDtos.ProductUpsert req) {
        requireRu(req.name(), "name");
        requireRu(req.description(), "description");
        Category category = categories.findBySlug(req.categorySlug())
                .orElseThrow(() -> ApiException.badRequest("INVALID_CATEGORY", "Unknown category"));
        Set<VariantCode> codes = new HashSet<>();
        for (ProductAdminDtos.VariantUpsert v : req.variants()) {
            if (!codes.add(v.code())) {
                throw ApiException.badRequest("DUPLICATE_VARIANT", "Duplicate variant " + v.code());
            }
            requireRu(v.label(), "variant label");
        }
        if (req.variants().stream().noneMatch(ProductAdminDtos.VariantUpsert::active)) {
            throw ApiException.badRequest("NO_ACTIVE_VARIANT", "At least one variant must be active");
        }
        Product p;
        if (id == null) {
            if (products.findBySlug(req.slug()).isPresent()) {
                throw ApiException.conflict("SLUG_TAKEN", "Slug is already in use");
            }
            p = new Product();
        } else {
            p = products.findById(id).orElseThrow(() -> ApiException.notFound("Product"));
            products.findBySlug(req.slug()).filter(o -> !o.getId().equals(id)).ifPresent(o -> {
                throw ApiException.conflict("SLUG_TAKEN", "Slug is already in use");
            });
        }
        p.setSlug(req.slug());
        p.setCategory(category);
        p.setName(req.name());
        p.setDescription(req.description());
        p.setComposition(req.composition() == null ? Map.of() : req.composition());
        p.setFeatured(req.featured());
        p.setSeasonal(req.seasonal());
        p.setGift(req.gift());
        p.setPrepMinutes(req.prepMinutes());
        p.setActive(req.active());

        // Variants are matched by code and updated in place: order items reference variant ids, so never delete.
        for (ProductAdminDtos.VariantUpsert in : req.variants()) {
            ProductVariant v = p.getVariants().stream().filter(x -> x.getCode() == in.code()).findFirst()
                    .orElseGet(() -> {
                        ProductVariant nv = new ProductVariant();
                        nv.setProduct(p);
                        nv.setCode(in.code());
                        p.getVariants().add(nv);
                        return nv;
                    });
            v.setLabel(in.label());
            v.setPrice(app.feya.common.Money.scale(in.price()));
            v.setStemsCount(in.stemsCount());
            v.setActive(in.active());
            v.setSortOrder(in.code().ordinal());
        }
        for (ProductVariant existing : p.getVariants()) {
            if (!codes.contains(existing.getCode())) {
                existing.setActive(false);
            }
        }
        p.refreshDerived();
        Product saved = products.saveAndFlush(p);
        audit.record(id == null ? "PRODUCT_CREATED" : "PRODUCT_UPDATED", "PRODUCT", saved.getId(), saved.getSlug());
        return toDto(saved);
    }

    @Transactional
    public ProductAdminDtos.ProductAdmin addImageUrl(UUID productId, String url, String alt) {
        if (!url.startsWith("/media/") && !url.startsWith("https://")) {
            throw ApiException.badRequest("INVALID_IMAGE_URL", "Image URL must be an https URL or a /media path");
        }
        Product p = products.findById(productId).orElseThrow(() -> ApiException.notFound("Product"));
        ProductImage img = new ProductImage();
        img.setProduct(p);
        img.setUrl(url);
        img.setAlt(alt);
        img.setSortOrder(p.getImages().size());
        p.getImages().add(img);
        audit.record("PRODUCT_IMAGE_ADDED", "PRODUCT", p.getId(), url);
        return toDto(products.saveAndFlush(p));
    }

    @Transactional
    public ProductAdminDtos.ProductAdmin addImageFile(UUID productId, MultipartFile file) {
        String ext = IMAGE_TYPES.get(file.getContentType());
        if (ext == null || file.isEmpty()) {
            throw ApiException.badRequest("INVALID_IMAGE", "Only JPEG, PNG or WebP images are accepted");
        }
        try (InputStream in = file.getInputStream()) {
            byte[] head = in.readNBytes(12);
            if (!looksLikeImage(head, ext)) {
                throw ApiException.badRequest("INVALID_IMAGE", "File content does not match its type");
            }
        } catch (IOException e) {
            throw ApiException.badRequest("INVALID_IMAGE", "Unreadable file");
        }
        String name = UUID.randomUUID() + ext;
        Path dir = Path.of(props.media().uploadDir()).toAbsolutePath();
        try {
            Files.createDirectories(dir);
            try (InputStream in = file.getInputStream()) {
                Files.copy(in, dir.resolve(name), StandardCopyOption.REPLACE_EXISTING);
            }
        } catch (IOException e) {
            throw new IllegalStateException("Cannot store upload", e);
        }
        return addImageUrl(productId, "/media/uploads/" + name, null);
    }

    private static boolean looksLikeImage(byte[] h, String ext) {
        if (h.length < 12) return false;
        return switch (ext) {
            case ".jpg" -> (h[0] & 0xFF) == 0xFF && (h[1] & 0xFF) == 0xD8;
            case ".png" -> (h[0] & 0xFF) == 0x89 && h[1] == 'P' && h[2] == 'N' && h[3] == 'G';
            case ".webp" -> h[0] == 'R' && h[1] == 'I' && h[2] == 'F' && h[3] == 'F' && h[8] == 'W' && h[9] == 'E';
            default -> false;
        };
    }

    @Transactional
    public ProductAdminDtos.ProductAdmin removeImage(UUID productId, UUID imageId) {
        Product p = products.findById(productId).orElseThrow(() -> ApiException.notFound("Product"));
        if (!p.getImages().removeIf(i -> i.getId().equals(imageId))) {
            throw ApiException.notFound("Image");
        }
        int n = 0;
        for (ProductImage i : p.getImages()) {
            i.setSortOrder(n++);
        }
        audit.record("PRODUCT_IMAGE_REMOVED", "PRODUCT", p.getId(), imageId.toString());
        return toDto(products.saveAndFlush(p));
    }

    private static void requireRu(Map<String, String> m, String field) {
        if (m == null || m.get("ru") == null || m.get("ru").isBlank()) {
            throw ApiException.badRequest("RU_TEXT_REQUIRED", "Russian " + field + " is required");
        }
    }

    ProductAdminDtos.ProductAdmin toDto(Product p) {
        List<ProductAdminDtos.ImageRef> images = p.getImages().stream()
                .map(i -> new ProductAdminDtos.ImageRef(i.getId(), media.resolve(i.getUrl()), i.getAlt(), i.getSortOrder())).toList();
        List<ProductAdminDtos.VariantAdmin> variants = p.getVariants().stream()
                .map(v -> new ProductAdminDtos.VariantAdmin(v.getId(), v.getCode(), v.getLabel(), v.getPrice(),
                        v.getStemsCount(), v.isActive())).toList();
        return new ProductAdminDtos.ProductAdmin(p.getId(), p.getSlug(), p.getCategory().getSlug(), p.getName(),
                p.getDescription(), p.getComposition(), p.isFeatured(), p.isSeasonal(), p.isGift(), p.getPrepMinutes(),
                p.isActive(), p.getPriceFrom(), p.getSoldCount(), p.getRatingAvg(), p.getRatingCount(), images,
                variants, p.getUpdatedAt());
    }
}
