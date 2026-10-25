package app.feya.catalog;

import app.feya.common.Lang;
import app.feya.common.PageResponse;
import app.feya.security.Auth;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class CatalogController {
    private final CatalogService catalog;

    public CatalogController(CatalogService catalog) {
        this.catalog = catalog;
    }

    @GetMapping("/categories")
    public List<CatalogDtos.CategoryDto> categories(Lang lang) {
        return catalog.categories(lang);
    }

    @GetMapping("/home")
    public CatalogDtos.HomeResponse home(@RequestParam(required = false) UUID zoneId, Lang lang) {
        return catalog.home(zoneId, lang, Auth.userIdOrNull());
    }

    @GetMapping("/products")
    public PageResponse<CatalogDtos.ProductSummary> products(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String category,
            @RequestParam(required = false) String collection,
            @RequestParam(required = false) BigDecimal minPrice,
            @RequestParam(required = false) BigDecimal maxPrice,
            @RequestParam(required = false) String sort,
            @RequestParam(required = false) UUID zoneId,
            @RequestParam(defaultValue = "true") boolean availableOnly,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            Lang lang) {
        return catalog.search(new CatalogService.Query(q, category, collection, minPrice, maxPrice, sort, zoneId,
                availableOnly, page, size), lang, Auth.userIdOrNull());
    }

    @GetMapping("/products/{idOrSlug}")
    public CatalogDtos.ProductDetail product(@PathVariable String idOrSlug, @RequestParam(required = false) UUID zoneId,
                                             Lang lang) {
        return catalog.detail(idOrSlug, zoneId, lang, Auth.userIdOrNull());
    }

    @GetMapping("/products/{idOrSlug}/related")
    public List<CatalogDtos.ProductSummary> related(@PathVariable String idOrSlug,
                                                    @RequestParam(required = false) UUID zoneId, Lang lang) {
        return catalog.related(idOrSlug, zoneId, lang, Auth.userIdOrNull());
    }
}
