package app.feya;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import app.feya.common.ApiException;
import app.feya.identity.TwilioSmsSender;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class TwilioSmsSenderTest {
    private HttpServer server;
    private final AtomicReference<String> path = new AtomicReference<>();
    private final AtomicReference<String> auth = new AtomicReference<>();
    private final AtomicReference<String> body = new AtomicReference<>();
    private volatile int status = 201;
    private String baseUrl;

    @BeforeEach
    void start() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", ex -> {
            path.set(ex.getRequestURI().getPath());
            auth.set(ex.getRequestHeaders().getFirst("Authorization"));
            body.set(URLDecoder.decode(new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8),
                    StandardCharsets.UTF_8));
            ex.sendResponseHeaders(status, -1);
            ex.close();
        });
        server.start();
        baseUrl = "http://127.0.0.1:" + server.getAddress().getPort();
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    @Test
    void sendsTheCodeFromANumberWithBasicAuth() {
        new TwilioSmsSender("AC123", "tok", "+15005550006", "", baseUrl).sendOtp("+77010000000", "123456");
        assertThat(path.get()).isEqualTo("/2010-04-01/Accounts/AC123/Messages.json");
        assertThat(auth.get()).isEqualTo("Basic " + Base64.getEncoder().encodeToString("AC123:tok".getBytes()));
        assertThat(body.get()).contains("To=+77010000000").contains("From=+15005550006").contains("123456");
        assertThat(body.get()).doesNotContain("MessagingServiceSid");
    }

    @Test
    void aMessagingServiceWinsOverTheFromNumber() {
        new TwilioSmsSender("AC123", "tok", "+15005550006", "MG999", baseUrl).sendOtp("+77010000000", "654321");
        assertThat(body.get()).contains("MessagingServiceSid=MG999").doesNotContain("From=");
    }

    @Test
    void aGatewayErrorBecomesServiceUnavailable() {
        status = 400;
        assertThatThrownBy(() -> new TwilioSmsSender("AC123", "tok", "+1", "", baseUrl).sendOtp("+77010000000", "111111"))
                .isInstanceOfSatisfying(ApiException.class, e -> {
                    assertThat(e.status().value()).isEqualTo(503);
                    assertThat(e.getMessage()).doesNotContain("111111");
                });
    }

    @Test
    void anUnreachableGatewayBecomesServiceUnavailable() {
        server.stop(0);
        assertThatThrownBy(() -> new TwilioSmsSender("AC123", "tok", "+1", "", baseUrl).sendOtp("+77010000000", "111111"))
                .isInstanceOf(ApiException.class);
    }

    @Test
    void incompleteConfigurationFailsAtStartup() {
        assertThatThrownBy(() -> new TwilioSmsSender("AC123", "", "+1", "", baseUrl)).isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> new TwilioSmsSender("AC123", "tok", "", "", baseUrl)).isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> new TwilioSmsSender("", "tok", "+1", "", baseUrl)).isInstanceOf(IllegalStateException.class);
    }
}
