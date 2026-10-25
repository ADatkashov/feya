package app.feya.florist;

import app.feya.common.ApiException;
import app.feya.identity.Role;
import app.feya.identity.User;
import app.feya.identity.UserRepository;
import app.feya.security.Auth;
import java.util.UUID;
import org.springframework.stereotype.Component;

/** Resolves which florist the caller may operate on: florists only their own shop, admins any (explicit id). */
@Component
public class FloristContext {
    private final UserRepository users;

    public FloristContext(UserRepository users) {
        this.users = users;
    }

    public UUID resolve(UUID requestedFloristId) {
        User u = users.findById(Auth.userId()).orElseThrow(() -> ApiException.unauthorized("UNAUTHORIZED", "Unknown user"));
        if (u.hasRole(Role.ADMIN)) {
            return requestedFloristId;
        }
        if (u.hasRole(Role.FLORIST) && u.getFloristId() != null) {
            if (requestedFloristId != null && !requestedFloristId.equals(u.getFloristId())) {
                throw ApiException.forbidden("You can only manage your own florist shop");
            }
            return u.getFloristId();
        }
        throw ApiException.forbidden("No florist shop is assigned to this account");
    }

    public UUID require(UUID requestedFloristId) {
        UUID id = resolve(requestedFloristId);
        if (id == null) {
            throw ApiException.badRequest("FLORIST_REQUIRED", "floristId is required");
        }
        return id;
    }
}
