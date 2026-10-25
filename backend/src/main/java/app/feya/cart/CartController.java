package app.feya.cart;

import app.feya.common.Lang;
import app.feya.security.Auth;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/cart")
public class CartController {
    private final CartService cart;

    public CartController(CartService cart) {
        this.cart = cart;
    }

    /**
     * Stateless authoritative quote for a client-held cart. The cart itself is persisted on the device; every
     * price shown at checkout comes from this endpoint, and orders re-price server-side.
     */
    @PostMapping("/quote")
    public CartDtos.QuoteResponse quote(@Valid @RequestBody CartDtos.QuoteRequest req, Lang lang) {
        return cart.quote(req, Auth.userIdOrNull(), lang);
    }
}
