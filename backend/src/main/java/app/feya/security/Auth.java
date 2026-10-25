package app.feya.security;

import app.feya.common.ApiException;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;

/** Access to the authenticated principal of the current request. */
public final class Auth {
    private Auth() {}

    public static UUID userId() {
        UUID id = userIdOrNull();
        if (id == null) {
            throw ApiException.unauthorized("UNAUTHORIZED", "Authentication required");
        }
        return id;
    }

    public static UUID userIdOrNull() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        if (a != null && a.getPrincipal() instanceof Jwt jwt) {
            try {
                return UUID.fromString(jwt.getSubject());
            } catch (IllegalArgumentException e) {
                return null;
            }
        }
        return null;
    }

    public static Set<String> roles() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        if (a == null) {
            return Set.of();
        }
        return a.getAuthorities().stream().map(GrantedAuthority::getAuthority)
                .filter(s -> s.startsWith("ROLE_")).map(s -> s.substring(5)).collect(Collectors.toSet());
    }

    public static boolean hasRole(String role) {
        return roles().contains(role);
    }

    /** Highest-privilege role of the caller, for audit trails. */
    public static String primaryRoleOrNull() {
        Set<String> r = roles();
        for (String candidate : new String[] {"ADMIN", "SUPPORT", "FLORIST", "COURIER", "CUSTOMER"}) {
            if (r.contains(candidate)) {
                return candidate;
            }
        }
        return null;
    }
}
