package app.feya.payments.freedompay;

import java.io.IOException;
import java.io.StringReader;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.InputSource;

/**
 * Form-POST/XML transport for FreedomPay's classic {@code pg_*} API, on the JDK HttpClient (no new dependency).
 * Never logs a request or response body: they may carry {@code pg_sig} and card-adjacent fields.
 */
final class FreedomPayHttpClient {

    private static final Logger log = LoggerFactory.getLogger(FreedomPayHttpClient.class);
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(15);

    private final HttpClient httpClient;
    private final String apiUrl;

    FreedomPayHttpClient(String apiUrl) {
        this.apiUrl = apiUrl;
        this.httpClient = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    }

    /** @param scriptPath e.g. {@code "init_payment.php"} — appended to the configured api-url. */
    Map<String, String> post(String scriptPath, Map<String, String> formFields) {
        String body = formFields.entrySet().stream()
                .map(e -> encode(e.getKey()) + "=" + encode(e.getValue() == null ? "" : e.getValue()))
                .collect(Collectors.joining("&"));

        HttpRequest request = HttpRequest.newBuilder().uri(URI.create(apiUrl + "/" + scriptPath))
                .timeout(REQUEST_TIMEOUT).header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(body, StandardCharsets.UTF_8)).build();

        long startedAt = System.nanoTime();
        HttpResponse<String> response;
        try {
            response = httpClient.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        } catch (IOException e) {
            log.warn("Freedom Pay {} network error after {}ms: {}", scriptPath, elapsedMs(startedAt),
                    e.getClass().getSimpleName());
            throw new FreedomPayException("Network error calling Freedom Pay " + scriptPath, e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new FreedomPayException("Interrupted calling Freedom Pay " + scriptPath, e);
        }

        long elapsedMs = elapsedMs(startedAt);
        if (response.statusCode() / 100 != 2) {
            log.warn("Freedom Pay {} returned HTTP {} after {}ms", scriptPath, response.statusCode(), elapsedMs);
            throw new FreedomPayException("Freedom Pay " + scriptPath + " returned HTTP " + response.statusCode());
        }
        log.info("Freedom Pay {} responded HTTP {} in {}ms", scriptPath, response.statusCode(), elapsedMs);
        return parseXml(response.body(), scriptPath);
    }

    private static long elapsedMs(long startedAtNanos) {
        return (System.nanoTime() - startedAtNanos) / 1_000_000;
    }

    private static String encode(String value) {
        return java.net.URLEncoder.encode(value, StandardCharsets.UTF_8);
    }

    /** Flat {@code <response><pg_field>value</pg_field>...</response>} shape only — matches every documented response. */
    private static Map<String, String> parseXml(String xml, String scriptPath) {
        try {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            // No DOCTYPE / external entities: this is a trust boundary.
            factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
            factory.setXIncludeAware(false);
            factory.setExpandEntityReferences(false);
            DocumentBuilder builder = factory.newDocumentBuilder();
            Element root = builder.parse(new InputSource(new StringReader(xml))).getDocumentElement();

            Map<String, String> result = new LinkedHashMap<>();
            NodeList children = root.getChildNodes();
            for (int i = 0; i < children.getLength(); i++) {
                Node node = children.item(i);
                if (node.getNodeType() == Node.ELEMENT_NODE) {
                    result.put(node.getNodeName(), node.getTextContent());
                }
            }
            return result;
        } catch (Exception e) {
            throw new FreedomPayException("Malformed XML response from Freedom Pay " + scriptPath + ": "
                    + e.getMessage(), e);
        }
    }
}
