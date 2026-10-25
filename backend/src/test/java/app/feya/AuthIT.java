package app.feya;

import static org.assertj.core.api.Assertions.assertThat;

import app.feya.support.IntegrationTest;
import java.time.Duration;
import java.util.Map;
import org.junit.jupiter.api.Test;

class AuthIT extends IntegrationTest {

    @Test
    void otpLoginCreatesCustomerAndNormalizesPhone() {
        Resp otp = POST("/auth/otp/request", Map.of("phone", "8 (777) 123-45-67"), null);
        assertThat(otp.status()).isEqualTo(200);
        Resp v = POST("/auth/otp/verify", Map.of("phone", "+77771234567", "code", otp.text("devCode")), null);
        assertThat(v.status()).isEqualTo(200);
        assertThat(v.body().get("user").get("phone").asText()).isEqualTo("+77771234567");
        assertThat(v.body().get("user").get("roles").get(0).asText()).isEqualTo("CUSTOMER");
        assertThat(v.body().get("expiresIn").asLong()).isEqualTo(900);
        assertThat(GET("/me", v.text("accessToken")).status()).isEqualTo(200);
    }

    @Test
    void wrongCodesAreCountedAndLockTheCode() {
        Resp otp = POST("/auth/otp/request", Map.of("phone", CUSTOMER), null);
        String real = otp.text("devCode");
        String wrong = real.equals("000000") ? "111111" : "000000";
        for (int i = 0; i < 5; i++) {
            assertThat(POST("/auth/otp/verify", Map.of("phone", CUSTOMER, "code", wrong), null).status()).isEqualTo(400);
        }
        // After 5 failures even the right code is refused.
        assertThat(POST("/auth/otp/verify", Map.of("phone", CUSTOMER, "code", real), null).status()).isEqualTo(400);
    }

    @Test
    void codeIsSingleUseAndExpires() {
        Resp otp = POST("/auth/otp/request", Map.of("phone", CUSTOMER), null);
        assertThat(POST("/auth/otp/verify", Map.of("phone", CUSTOMER, "code", otp.text("devCode")), null).status()).isEqualTo(200);
        assertThat(POST("/auth/otp/verify", Map.of("phone", CUSTOMER, "code", otp.text("devCode")), null).status()).isEqualTo(400);
        Resp otp2 = POST("/auth/otp/request", Map.of("phone", CUSTOMER), null);
        clock.advance(Duration.ofMinutes(6));
        assertThat(POST("/auth/otp/verify", Map.of("phone", CUSTOMER, "code", otp2.text("devCode")), null).status()).isEqualTo(400);
    }

    @Test
    void codeRequestsArePerPhoneRateLimited() {
        for (int i = 0; i < 5; i++) assertThat(POST("/auth/otp/request", Map.of("phone", OTHER_CUSTOMER), null).status()).isEqualTo(200);
        assertThat(POST("/auth/otp/request", Map.of("phone", OTHER_CUSTOMER), null).status()).isEqualTo(429);
    }

    @Test
    void invalidPhonesAreRejected() {
        assertThat(POST("/auth/otp/request", Map.of("phone", "123"), null).status()).isEqualTo(400);
        assertThat(POST("/auth/otp/request", Map.of("phone", "abc"), null).status()).isEqualTo(400);
        assertThat(POST("/auth/otp/request", Map.of(), null).status()).isEqualTo(400);
    }

    @Test
    void refreshTokensRotateAndReuseRevokesTheFamily() {
        Resp login = loginFull(CUSTOMER);
        String r1 = login.text("refreshToken");
        Resp second = POST("/auth/refresh", Map.of("refreshToken", r1), null);
        assertThat(second.status()).isEqualTo(200);
        String r2 = second.text("refreshToken");
        assertThat(r2).isNotEqualTo(r1);
        // Replaying the rotated token is treated as theft and burns the whole family, including r2.
        assertThat(POST("/auth/refresh", Map.of("refreshToken", r1), null).status()).isEqualTo(401);
        assertThat(POST("/auth/refresh", Map.of("refreshToken", r2), null).status()).isEqualTo(401);
    }

    @Test
    void logoutRevokesRefreshToken() {
        Resp login = loginFull(CUSTOMER);
        assertThat(POST("/auth/logout", Map.of("refreshToken", login.text("refreshToken")), null).status()).isEqualTo(200);
        assertThat(POST("/auth/refresh", Map.of("refreshToken", login.text("refreshToken")), null).status()).isEqualTo(401);
    }

    @Test
    void refreshTokensExpire() {
        Resp login = loginFull(CUSTOMER);
        clock.advance(Duration.ofDays(31));
        assertThat(POST("/auth/refresh", Map.of("refreshToken", login.text("refreshToken")), null).status()).isEqualTo(401);
    }

    @Test
    void blockedUsersCannotLoginOrRefresh() {
        Resp login = loginFull(OTHER_CUSTOMER);
        sql("update users set status='BLOCKED' where phone=?", OTHER_CUSTOMER);
        assertThat(POST("/auth/refresh", Map.of("refreshToken", login.text("refreshToken")), null).status()).isEqualTo(403);
        Resp otp = POST("/auth/otp/request", Map.of("phone", OTHER_CUSTOMER), null);
        assertThat(POST("/auth/otp/verify", Map.of("phone", OTHER_CUSTOMER, "code", otp.text("devCode")), null).status()).isEqualTo(403);
    }

    @Test
    void profileUpdateAndDeletionRequest() {
        String token = login(CUSTOMER);
        Resp u = PATCH("/me", Map.of("name", "Анна", "language", "kk", "notifyPromotions", true), token);
        assertThat(u.status()).isEqualTo(200);
        assertThat(u.text("language")).isEqualTo("kk");
        assertThat(PATCH("/me", Map.of("language", "fr"), token).status()).isEqualTo(400);
        assertThat(PATCH("/me", Map.of("email", "not-an-email"), token).status()).isEqualTo(400);
        Resp d = POST("/me/deletion-request", null, token);
        assertThat(d.text("status")).isEqualTo("DELETION_REQUESTED");
        // Sessions are revoked...
        Resp relogin = loginFull(CUSTOMER);
        // ...and logging in again cancels the request.
        assertThat(relogin.body().get("user").get("status").asText()).isEqualTo("ACTIVE");
    }

    @Test
    void deviceRegistrationIsPerUser() {
        String token = login(CUSTOMER);
        assertThat(POST("/me/devices", Map.of("token", "fcm-token-1", "platform", "android"), token).status()).isEqualTo(200);
        assertThat(POST("/me/devices", Map.of("token", "fcm-token-1", "platform", "android"), token).status()).isEqualTo(200); // idempotent
        assertThat(one("select count(*) from device_tokens where token='fcm-token-1'", Integer.class)).isEqualTo(1);
    }

    @Test
    void anonymousAccessToProtectedEndpointsIs401() {
        for (String path : new String[] {"/me", "/orders", "/addresses", "/favorites", "/notifications"}) {
            assertThat(GET(path, null).status()).as(path).isEqualTo(401);
        }
    }
}
