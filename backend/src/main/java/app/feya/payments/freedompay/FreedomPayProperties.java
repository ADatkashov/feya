package app.feya.payments.freedompay;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * {@code feya.payments.freedompay.*} (FreedomPay classic {@code pg_*} API, docs.freedompay.kz). The same
 * {@code secretKey} signs outgoing requests and verifies incoming Result-notify webhooks: FreedomPay has no separate
 * webhook secret. There is no hardcoded API host: set it explicitly per environment.
 *
 * @param resultNotifyScriptName the script name FreedomPay signs its Result-notify callback with; it is whatever the
 *                               merchant panel is configured to call, so confirm it there (see docs/INTEGRATIONS.md)
 * @param successUrl             where the customer's browser lands after paying (UX only, not a trust boundary)
 * @param failureUrl             where it lands after a failed or cancelled payment
 */
@ConfigurationProperties(prefix = "feya.payments.freedompay")
public record FreedomPayProperties(String apiUrl, String merchantId, String secretKey,
                                   @DefaultValue("result.php") String resultNotifyScriptName,
                                   String successUrl, String failureUrl) {
}
