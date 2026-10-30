package app.feya.identity;

import app.feya.common.ApiException;
import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;

/**
 * SMS delivery through Twilio Programmable Messaging ({@code POST /2010-04-01/Accounts/{sid}/Messages.json}) with the
 * JDK HttpClient, so no SDK dependency. Ported from the proven ZAIRO implementation. Selected with
 * {@code FEYA_SMS_PROVIDER=twilio}; otherwise {@link LoggingSmsSender} stays in place.
 *
 * <p>Set either {@code from} (an E.164 Twilio number) or {@code messagingServiceSid}; the service wins when both are
 * set. Never logs the code or the auth token: only the last four digits of the destination.
 */
public class TwilioSmsSender implements SmsSender {
    private static final Logger log = LoggerFactory.getLogger(TwilioSmsSender.class);
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(10);

    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    private final String accountSid;
    private final String authToken;
    private final String from;
    private final String messagingServiceSid;
    private final String baseUrl;

    public TwilioSmsSender(String accountSid, String authToken, String from, String messagingServiceSid,
                           String baseUrl) {
        if (isBlank(accountSid) || isBlank(authToken) || (isBlank(from) && isBlank(messagingServiceSid))) {
            throw new IllegalStateException("FEYA_SMS_PROVIDER=twilio requires FEYA_SMS_TWILIO_ACCOUNT_SID, "
                    + "FEYA_SMS_TWILIO_AUTH_TOKEN and one of FEYA_SMS_TWILIO_FROM / FEYA_SMS_TWILIO_MESSAGING_SERVICE_SID");
        }
        this.accountSid = accountSid;
        this.authToken = authToken;
        this.from = from;
        this.messagingServiceSid = messagingServiceSid;
        this.baseUrl = isBlank(baseUrl) ? "https://api.twilio.com" : baseUrl;
    }

    @Override
    public void sendOtp(String phone, String code) {
        Map<String, String> form = new LinkedHashMap<>();
        form.put("To", phone);
        if (!isBlank(messagingServiceSid)) {
            form.put("MessagingServiceSid", messagingServiceSid);
        } else {
            form.put("From", from);
        }
        form.put("Body", "FEYA: ваш код " + code + ". Никому его не сообщайте.");

        String credentials = Base64.getEncoder()
                .encodeToString((accountSid + ":" + authToken).getBytes(StandardCharsets.UTF_8));
        HttpRequest request = HttpRequest
                .newBuilder(URI.create(baseUrl + "/2010-04-01/Accounts/" + accountSid + "/Messages.json"))
                .timeout(REQUEST_TIMEOUT)
                .header("Authorization", "Basic " + credentials)
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(encode(form)))
                .build();
        try {
            HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() / 100 != 2) {
                log.error("Twilio rejected SMS to {} status={} body={}", PhoneNumbers.mask(phone),
                        response.statusCode(), response.body());
                throw unavailable();
            }
            log.info("Twilio SMS sent to {}", PhoneNumbers.mask(phone));
        } catch (IOException e) {
            log.error("Twilio SMS request failed: {}", e.getClass().getSimpleName());
            throw unavailable();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw unavailable();
        }
    }

    private static ApiException unavailable() {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "SMS_UNAVAILABLE",
                "The code could not be sent, please try again later");
    }

    private static String encode(Map<String, String> form) {
        return form.entrySet().stream()
                .map(e -> URLEncoder.encode(e.getKey(), StandardCharsets.UTF_8) + "="
                        + URLEncoder.encode(e.getValue(), StandardCharsets.UTF_8))
                .collect(Collectors.joining("&"));
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }
}
