package app.feya.catalog;

import app.feya.common.ApiException;
import app.feya.common.Lang;
import app.feya.security.Auth;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/favorites")
public class FavoriteController {
    private final FavoriteRepository favorites;
    private final ProductRepository products;
    private final CatalogService catalog;

    public FavoriteController(FavoriteRepository favorites, ProductRepository products, CatalogService catalog) {
        this.favorites = favorites;
        this.products = products;
        this.catalog = catalog;
    }

    @GetMapping
    public List<CatalogDtos.ProductSummary> list(Lang lang) {
        return catalog.favoriteProducts(Auth.userId(), lang);
    }

    @PutMapping("/{productId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void add(@PathVariable UUID productId) {
        UUID userId = Auth.userId();
        if (!products.existsById(productId)) {
            throw ApiException.notFound("Product");
        }
        Favorite.Key key = new Favorite.Key(userId, productId);
        if (!favorites.existsById(key)) {
            favorites.save(new Favorite(userId, productId));
        }
    }

    @DeleteMapping("/{productId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void remove(@PathVariable UUID productId) {
        favorites.deleteById(new Favorite.Key(Auth.userId(), productId));
    }
}
