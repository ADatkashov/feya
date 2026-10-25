package app.feya.identity;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class AuthDtos {
    private AuthDtos() {}

    public record OtpRequest(@NotBlank @Size(max = 24) String phone) {}

    public record OtpResponse(Instant expiresAt, String devCode) {}

    public record OtpVerifyRequest(@NotBlank @Size(max = 24) String phone, @NotBlank @Size(min = 4, max = 8) String code) {}

    public record RefreshRequest(@NotBlank String refreshToken) {}

    public record UserDto(UUID id, String phone, String name, String email, String language, List<String> roles,
                          boolean notifyPush, boolean notifyOrderUpdates, boolean notifyPromotions, String status) {
        public static UserDto of(User u) {
            return new UserDto(u.getId(), u.getPhone(), u.getName(), u.getEmail(), u.getLanguage(),
                    u.getRoles().stream().map(Enum::name).sorted().toList(), u.isNotifyPush(),
                    u.isNotifyOrderUpdates(), u.isNotifyPromotions(), u.getStatus().name());
        }
    }

    public record TokenResponse(String accessToken, String refreshToken, long expiresIn, UserDto user) {}
}
