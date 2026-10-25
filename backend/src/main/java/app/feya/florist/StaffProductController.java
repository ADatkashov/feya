package app.feya.florist;

import app.feya.catalog.ProductAdminDtos;
import app.feya.catalog.ProductAdminService;
import app.feya.common.PageResponse;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** Catalog management for florists and admins (support staff cannot change the catalog). */
@RestController
@RequestMapping({"/api/v1/florist/products", "/api/v1/admin/products"})
@PreAuthorize("hasAnyRole('ADMIN','FLORIST')")
public class StaffProductController {
    private final ProductAdminService service;

    public StaffProductController(ProductAdminService service) {
        this.service = service;
    }

    @GetMapping
    public PageResponse<ProductAdminDtos.ProductAdmin> list(@RequestParam(required = false) String q,
                                                            @RequestParam(defaultValue = "0") int page,
                                                            @RequestParam(defaultValue = "20") int size) {
        return PageResponse.of(service.list(q, page, size));
    }

    @GetMapping("/{id}")
    public ProductAdminDtos.ProductAdmin get(@PathVariable UUID id) {
        return service.get(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ProductAdminDtos.ProductAdmin create(@Valid @RequestBody ProductAdminDtos.ProductUpsert req) {
        return service.upsert(null, req);
    }

    @PutMapping("/{id}")
    public ProductAdminDtos.ProductAdmin update(@PathVariable UUID id, @Valid @RequestBody ProductAdminDtos.ProductUpsert req) {
        return service.upsert(id, req);
    }

    @PostMapping("/{id}/images")
    public ProductAdminDtos.ProductAdmin addImageUrl(@PathVariable UUID id, @Valid @RequestBody ProductAdminDtos.ImageUrlRequest req) {
        return service.addImageUrl(id, req.url(), req.alt());
    }

    @PostMapping(value = "/{id}/images/upload", consumes = "multipart/form-data")
    public ProductAdminDtos.ProductAdmin upload(@PathVariable UUID id, @RequestParam("file") MultipartFile file) {
        return service.addImageFile(id, file);
    }

    @DeleteMapping("/{id}/images/{imageId}")
    public ProductAdminDtos.ProductAdmin removeImage(@PathVariable UUID id, @PathVariable UUID imageId) {
        return service.removeImage(id, imageId);
    }
}
