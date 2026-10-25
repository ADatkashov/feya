package app.feya.administration;

import app.feya.catalog.Category;
import app.feya.catalog.CategoryRepository;
import app.feya.common.ApiException;
import app.feya.common.AuditService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
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
@RequestMapping("/api/v1/admin/categories")
@PreAuthorize("hasRole('ADMIN')")
public class AdminCatalogController {
    public record CategoryUpsert(@Pattern(regexp = "[a-z0-9][a-z0-9-]{1,58}") String slug,
                                 @NotEmpty Map<String, String> name, int sortOrder, boolean active) {}

    public record CategoryAdmin(UUID id, String slug, Map<String, String> name, int sortOrder, boolean active) {}

    private final CategoryRepository categories;
    private final AuditService audit;

    public AdminCatalogController(CategoryRepository categories, AuditService audit) {
        this.categories = categories;
        this.audit = audit;
    }

    @GetMapping
    public List<CategoryAdmin> list() {
        return categories.findAll(org.springframework.data.domain.Sort.by("sortOrder")).stream().map(this::dto).toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public CategoryAdmin create(@Valid @RequestBody CategoryUpsert req) {
        if (categories.findBySlug(req.slug()).isPresent()) {
            throw ApiException.conflict("SLUG_TAKEN", "Slug is already in use");
        }
        Category c = new Category();
        apply(c, req);
        c = categories.save(c);
        audit.record("CATEGORY_CREATED", "CATEGORY", c.getId(), c.getSlug());
        return dto(c);
    }

    @PutMapping("/{id}")
    @Transactional
    public CategoryAdmin update(@PathVariable UUID id, @Valid @RequestBody CategoryUpsert req) {
        Category c = categories.findById(id).orElseThrow(() -> ApiException.notFound("Category"));
        categories.findBySlug(req.slug()).filter(o -> !o.getId().equals(id)).ifPresent(o -> {
            throw ApiException.conflict("SLUG_TAKEN", "Slug is already in use");
        });
        apply(c, req);
        audit.record("CATEGORY_UPDATED", "CATEGORY", c.getId(), c.getSlug());
        return dto(c);
    }

    private void apply(Category c, CategoryUpsert req) {
        if (req.name().get("ru") == null || req.name().get("ru").isBlank()) {
            throw ApiException.badRequest("RU_TEXT_REQUIRED", "Russian name is required");
        }
        c.setSlug(req.slug());
        c.setName(req.name());
        c.setSortOrder(req.sortOrder());
        c.setActive(req.active());
    }

    private CategoryAdmin dto(Category c) {
        return new CategoryAdmin(c.getId(), c.getSlug(), c.getName(), c.getSortOrder(), c.isActive());
    }
}
