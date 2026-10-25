package app.feya;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import app.feya.common.ApiException;
import app.feya.common.FeyaProperties;
import app.feya.common.Lang;
import app.feya.common.ProductionGuard;
import app.feya.identity.PhoneNumbers;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class UnitTests {

    @ParameterizedTest
    @CsvSource({"87011234567,+77011234567", "+7 (701) 123-45-67,+77011234567", "7011234567,+77011234567",
            "77011234567,+77011234567", "+447911123456,+447911123456"})
    void phoneNumbersAreNormalizedToE164(String raw, String expected) {
        assertThat(PhoneNumbers.normalize(raw)).isEqualTo(expected);
    }

    @ParameterizedTest
    @CsvSource({"123", "+7701123", "0123456789", "1234567890", "abc", "+7701123456789012"})
    void invalidPhonesAreRejected(String raw) {
        assertThatThrownBy(() -> PhoneNumbers.normalize(raw)).isInstanceOf(ApiException.class);
    }

    @Test
    void phonesAreMaskedForLogs() {
        assertThat(PhoneNumbers.mask("+77011234567")).isEqualTo("+77***67");
    }

    @Test
    void languagePickingFallsBackToRussian() {
        Map<String, String> m = Map.of("ru", "Роза", "en", "Rose");
        assertThat(Lang.KK.pick(m)).isEqualTo("Роза");
        assertThat(Lang.EN.pick(m)).isEqualTo("Rose");
        assertThat(Lang.fromAcceptLanguage("kk-KZ,kk;q=0.9,ru;q=0.8")).isEqualTo(Lang.KK);
        assertThat(Lang.fromAcceptLanguage("de-DE,en;q=0.5")).isEqualTo(Lang.EN);
        assertThat(Lang.fromAcceptLanguage("fr")).isEqualTo(Lang.RU);
        assertThat(Lang.parse(null)).isEqualTo(Lang.RU);
    }

    private FeyaProperties props(String env, boolean devOtp, String payments, String jwt, String webhookSecret) {
        return new FeyaProperties(env, "Asia/Almaty", "KZT", new FeyaProperties.Jwt(jwt, "feya", Duration.ofMinutes(15), Duration.ofDays(30)),
                new FeyaProperties.Auth(devOtp, Duration.ofMinutes(5), 6, 5, 5),
                new FeyaProperties.Payments(payments, webhookSecret, List.of("CARD")), new FeyaProperties.Cors(List.of(), List.of()),
                new FeyaProperties.Media("", "uploads"), new FeyaProperties.Orders(Duration.ofMinutes(30), 20, java.math.BigDecimal.valueOf(1500)),
                new FeyaProperties.Tracking(Duration.ofMinutes(5)), new FeyaProperties.RateLimit(true), new FeyaProperties.Push("logging"));
    }

    @Test
    void productionRefusesUnsafeConfiguration() {
        String good = "0123456789abcdef0123456789abcdef-prod";
        new ProductionGuard(props("production", false, "none", good, null)).validate(); // safe: passes
        assertThatThrownBy(() -> new ProductionGuard(props("production", true, "none", good, null)).validate())
                .hasMessageContaining("Dev OTP");
        assertThatThrownBy(() -> new ProductionGuard(props("production", false, "sandbox", good, "x")).validate())
                .hasMessageContaining("Sandbox");
        assertThatThrownBy(() -> new ProductionGuard(props("production", false, "none", "dev-only-secret-dev-only-secret-0123456789", null)).validate())
                .hasMessageContaining("development JWT secret");
        assertThatThrownBy(() -> new ProductionGuard(props("production", false, "none", "short", null)).validate())
                .hasMessageContaining("FEYA_JWT_SECRET");
        assertThatThrownBy(() -> new ProductionGuard(props("production", false, "acmepay", good, "")).validate())
                .hasMessageContaining("WEBHOOK_SECRET");
    }

    @Test
    void nonProductionAllowsDevSwitches() {
        new ProductionGuard(props("dev", true, "sandbox", "dev-only-secret-dev-only-secret-0123456789", "s")).validate();
    }
}
