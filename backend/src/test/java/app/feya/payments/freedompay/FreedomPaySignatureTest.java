package app.feya.payments.freedompay;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

class FreedomPaySignatureTest {

    @Test
    void fieldsAreSortedByNameNotByInsertionOrder() {
        Map<String, String> a = new LinkedHashMap<>();
        a.put("pg_amount", "10.00");
        a.put("pg_merchant_id", "m1");
        Map<String, String> b = new LinkedHashMap<>();
        b.put("pg_merchant_id", "m1");
        b.put("pg_amount", "10.00");
        assertThat(FreedomPaySignature.compute("init_payment.php", a, "secret"))
                .isEqualTo(FreedomPaySignature.compute("init_payment.php", b, "secret"));
    }

    @Test
    void matchesTheDocumentedShape() throws Exception {
        // scriptName;values in ascending field order;secretKey, MD5 hex
        String expected = java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("MD5")
                .digest("init_payment.php;10.00;m1;secret".getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        Map<String, String> fields = Map.of("pg_amount", "10.00", "pg_merchant_id", "m1");
        assertThat(FreedomPaySignature.compute("init_payment.php", fields, "secret")).isEqualTo(expected);
    }

    @Test
    void matchesAcceptsOnlyTheRightSecretScriptAndFields() {
        Map<String, String> fields = Map.of("pg_payment_id", "123", "pg_result", "1");
        String sig = FreedomPaySignature.compute("result.php", fields, "s3cret");
        assertThat(FreedomPaySignature.matches("result.php", fields, "s3cret", sig)).isTrue();
        assertThat(FreedomPaySignature.matches("result.php", fields, "s3cret", sig.toUpperCase())).isTrue();
        assertThat(FreedomPaySignature.matches("result.php", fields, "wrong", sig)).isFalse();
        assertThat(FreedomPaySignature.matches("other.php", fields, "s3cret", sig)).isFalse();
        assertThat(FreedomPaySignature.matches("result.php", Map.of("pg_payment_id", "124", "pg_result", "1"),
                "s3cret", sig)).isFalse();
        assertThat(FreedomPaySignature.matches("result.php", fields, "s3cret", null)).isFalse();
    }
}
