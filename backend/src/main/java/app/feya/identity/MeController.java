package app.feya.identity;

import app.feya.common.ApiException;
import app.feya.common.AuditService;
import app.feya.security.Auth;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Clock;
import java.util.UUID;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/me")
public class MeController {
    public record UpdateProfile(@Size(max = 120) String name, @Email @Size(max = 160) String email,
                                @Pattern(regexp = "ru|kk|en") String language, Boolean notifyPush,
                                Boolean notifyOrderUpdates, Boolean notifyPromotions) {}

    public record DeviceRequest(@NotBlank @Size(max = 512) String token, @NotBlank @Size(max = 16) String platform) {}

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final DeviceTokenRepository devices;
    private final AuditService audit;
    private final Clock clock;

    public MeController(UserRepository users, RefreshTokenRepository refreshTokens, DeviceTokenRepository devices,
                        AuditService audit, Clock clock) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.devices = devices;
        this.audit = audit;
        this.clock = clock;
    }

    @GetMapping
    public AuthDtos.UserDto me() {
        return AuthDtos.UserDto.of(current());
    }

    @PatchMapping
    @Transactional
    public AuthDtos.UserDto update(@Valid @RequestBody UpdateProfile req) {
        User u = current();
        if (req.name() != null) u.setName(req.name().isBlank() ? null : req.name().trim());
        if (req.email() != null) u.setEmail(req.email().isBlank() ? null : req.email().trim());
        if (req.language() != null) u.setLanguage(req.language());
        if (req.notifyPush() != null) u.setNotifyPush(req.notifyPush());
        if (req.notifyOrderUpdates() != null) u.setNotifyOrderUpdates(req.notifyOrderUpdates());
        if (req.notifyPromotions() != null) u.setNotifyPromotions(req.notifyPromotions());
        return AuthDtos.UserDto.of(u);
    }

    /** GDPR-style deletion request: the account is flagged and sessions revoked; erasure is performed by operations. */
    @PostMapping("/deletion-request")
    @Transactional
    public AuthDtos.UserDto requestDeletion() {
        User u = current();
        u.setStatus(UserStatus.DELETION_REQUESTED);
        u.setDeletionRequestedAt(clock.instant());
        refreshTokens.revokeAllForUser(u.getId(), clock.instant());
        audit.record("ACCOUNT_DELETION_REQUESTED", "USER", u.getId(), null);
        return AuthDtos.UserDto.of(u);
    }

    @PostMapping("/devices")
    @Transactional
    public void registerDevice(@Valid @RequestBody DeviceRequest req) {
        UUID uid = Auth.userId();
        DeviceToken d = devices.findByToken(req.token()).orElseGet(DeviceToken::new);
        d.setUserId(uid);
        d.setToken(req.token());
        d.setPlatform(req.platform());
        devices.save(d);
    }

    @DeleteMapping("/devices")
    @Transactional
    public void unregisterDevice(@Valid @RequestBody DeviceRequest req) {
        devices.findByToken(req.token()).filter(d -> d.getUserId().equals(Auth.userId())).ifPresent(devices::delete);
    }

    private User current() {
        return users.findById(Auth.userId()).orElseThrow(() -> ApiException.unauthorized("UNAUTHORIZED", "Unknown user"));
    }
}
