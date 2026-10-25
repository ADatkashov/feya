package app.feya.common;

import java.math.BigDecimal;
import java.time.Duration;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

@ConfigurationProperties("feya")
public record FeyaProperties(
        @DefaultValue("production") String env,
        @DefaultValue("Asia/Almaty") String timezone,
        @DefaultValue("KZT") String currency,
        Jwt jwt,
        Auth auth,
        Payments payments,
        Cors cors,
        Media media,
        Orders orders,
        Tracking tracking,
        RateLimit rateLimit,
        Push push) {

    public boolean production() {
        return "production".equalsIgnoreCase(env);
    }

    public record Jwt(String secret, @DefaultValue("feya") String issuer,
                      @DefaultValue("PT15M") Duration accessTtl, @DefaultValue("P30D") Duration refreshTtl) {}

    public record Auth(@DefaultValue("false") boolean devOtpEnabled, @DefaultValue("PT5M") Duration otpTtl,
                       @DefaultValue("6") int otpLength, @DefaultValue("5") int otpMaxAttempts,
                       @DefaultValue("5") int otpMaxPerPhonePer10min) {}

    public record Payments(@DefaultValue("none") String provider, String webhookSecret,
                           @DefaultValue("CARD,APPLE_PAY,GOOGLE_PAY") List<String> methods) {
        public boolean sandbox() {
            return "sandbox".equalsIgnoreCase(provider);
        }

        public boolean configured() {
            return provider != null && !provider.isBlank() && !"none".equalsIgnoreCase(provider);
        }
    }

    public record Cors(List<String> allowedOrigins, List<String> allowedOriginPatterns) {}

    public record Media(String baseUrl, @DefaultValue("uploads") String uploadDir) {}

    public record Orders(@DefaultValue("PT30M") Duration pendingPaymentTtl,
                         @DefaultValue("20") int maxQuantityPerLine,
                         @DefaultValue("1500") BigDecimal giftWrapFee) {}

    public record Tracking(@DefaultValue("PT5M") Duration locationTtl) {}

    public record RateLimit(@DefaultValue("true") boolean enabled) {}

    public record Push(@DefaultValue("logging") String provider) {}
}
