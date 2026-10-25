package app.feya.identity;

import app.feya.common.ApiException;
import app.feya.common.FeyaProperties;
import app.feya.security.JwtService;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
    private final OtpService otp;
    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final JwtService jwt;
    private final FeyaProperties props;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();

    public AuthService(OtpService otp, UserRepository users, RefreshTokenRepository refreshTokens, JwtService jwt,
                       FeyaProperties props, Clock clock) {
        this.otp = otp;
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.jwt = jwt;
        this.props = props;
        this.clock = clock;
    }

    @Transactional
    public AuthDtos.TokenResponse loginWithOtp(String rawPhone, String code) {
        String phone = PhoneNumbers.normalize(rawPhone);
        otp.verify(phone, code);
        User user = users.findByPhone(phone).orElseGet(() -> {
            User u = new User();
            u.setPhone(phone);
            return users.save(u);
        });
        if (user.getStatus() == UserStatus.BLOCKED) {
            throw ApiException.forbidden("Account is blocked");
        }
        if (user.getStatus() == UserStatus.DELETION_REQUESTED) {
            // Logging in again cancels a pending deletion request.
            user.setStatus(UserStatus.ACTIVE);
            user.setDeletionRequestedAt(null);
        }
        user.setLastLoginAt(clock.instant());
        return issue(user, UUID.randomUUID());
    }

    @Transactional(noRollbackFor = ApiException.class)
    public AuthDtos.TokenResponse refresh(String refreshToken) {
        RefreshToken stored = refreshTokens.findByTokenHash(hash(refreshToken))
                .orElseThrow(() -> ApiException.unauthorized("INVALID_REFRESH_TOKEN", "Invalid refresh token"));
        Instant now = clock.instant();
        if (stored.getRevokedAt() != null) {
            // A rotated token was presented again: treat as theft and burn the whole family.
            refreshTokens.revokeFamily(stored.getFamilyId(), now);
            throw ApiException.unauthorized("INVALID_REFRESH_TOKEN", "Invalid refresh token");
        }
        if (stored.getExpiresAt().isBefore(now)) {
            throw ApiException.unauthorized("INVALID_REFRESH_TOKEN", "Refresh token expired");
        }
        User user = users.findById(stored.getUserId())
                .orElseThrow(() -> ApiException.unauthorized("INVALID_REFRESH_TOKEN", "Invalid refresh token"));
        if (user.getStatus() == UserStatus.BLOCKED) {
            throw ApiException.forbidden("Account is blocked");
        }
        stored.setRevokedAt(now);
        return issue(user, stored.getFamilyId());
    }

    @Transactional
    public void logout(String refreshToken) {
        refreshTokens.findByTokenHash(hash(refreshToken)).ifPresent(t -> {
            if (t.getRevokedAt() == null) {
                refreshTokens.revokeFamily(t.getFamilyId(), clock.instant());
            }
        });
    }

    private AuthDtos.TokenResponse issue(User user, UUID familyId) {
        byte[] raw = new byte[48];
        random.nextBytes(raw);
        String refresh = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        RefreshToken t = new RefreshToken();
        t.setUserId(user.getId());
        t.setFamilyId(familyId);
        t.setTokenHash(hash(refresh));
        t.setCreatedAt(clock.instant());
        t.setExpiresAt(clock.instant().plus(props.jwt().refreshTtl()));
        refreshTokens.save(t);
        String access = jwt.issueAccessToken(user.getId(), user.getRoles());
        return new AuthDtos.TokenResponse(access, refresh, jwt.accessTtlSeconds(), AuthDtos.UserDto.of(user));
    }

    static String hash(String token) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
