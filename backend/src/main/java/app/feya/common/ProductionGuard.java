package app.feya.common;

import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/** Fails fast at startup when the configuration is unsafe for the declared environment. */
@Component
public class ProductionGuard {
    private static final Logger log = LoggerFactory.getLogger(ProductionGuard.class);
    private final FeyaProperties props;

    public ProductionGuard(FeyaProperties props) {
        this.props = props;
    }

    @PostConstruct
    void validate() {
        String secret = props.jwt() == null ? null : props.jwt().secret();
        if (secret == null || secret.getBytes().length < 32) {
            throw new IllegalStateException("FEYA_JWT_SECRET must be set and at least 32 bytes long");
        }
        if (props.production()) {
            if (props.auth().devOtpEnabled()) {
                throw new IllegalStateException("Dev OTP must be disabled in production (FEYA_DEV_OTP_ENABLED)");
            }
            if (props.payments().sandbox()) {
                throw new IllegalStateException("Sandbox payments must not be enabled in production");
            }
            if (secret.startsWith("dev-only")) {
                throw new IllegalStateException("A development JWT secret is configured in production");
            }
            if (props.payments().configured()
                    && (props.payments().webhookSecret() == null || props.payments().webhookSecret().isBlank())) {
                throw new IllegalStateException("FEYA_PAYMENTS_WEBHOOK_SECRET is required when a payment provider is configured");
            }
        } else {
            log.warn("FEYA runs in NON-PRODUCTION mode (env={}): dev OTP={}, payments provider={}",
                    props.env(), props.auth().devOtpEnabled(), props.payments().provider());
        }
    }
}
