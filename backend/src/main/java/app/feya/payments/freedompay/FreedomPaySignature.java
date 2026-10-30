package app.feya.payments.freedompay;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Map;
import java.util.SortedMap;
import java.util.TreeMap;

/**
 * FreedomPay's {@code pg_sig}: MD5 hex of {@code scriptName;value1;value2;...;secretKey}, with the values of every
 * {@code pg_*} field except {@code pg_sig} in ascending order of field name. MD5 is FreedomPay's own documented
 * choice: a stronger hash would simply not match what their servers compute. Pure function, no I/O.
 */
final class FreedomPaySignature {

    private FreedomPaySignature() {
    }

    /** {@code fields} must not contain {@code pg_sig}: a stray field is a loud mismatch, not silently ignored. */
    static String compute(String scriptName, Map<String, String> fields, String secretKey) {
        SortedMap<String, String> sorted = new TreeMap<>(fields);
        StringBuilder toSign = new StringBuilder(scriptName);
        for (String value : sorted.values()) {
            toSign.append(';').append(value == null ? "" : value);
        }
        toSign.append(';').append(secretKey);
        return md5Hex(toSign.toString());
    }

    static boolean matches(String scriptName, Map<String, String> fields, String secretKey, String expectedSig) {
        if (expectedSig == null) {
            return false;
        }
        return MessageDigest.isEqual(compute(scriptName, fields, secretKey).getBytes(StandardCharsets.UTF_8),
                expectedSig.trim().toLowerCase(java.util.Locale.ROOT).getBytes(StandardCharsets.UTF_8));
    }

    private static String md5Hex(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("MD5");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                hex.append(Character.forDigit((b >> 4) & 0xF, 16));
                hex.append(Character.forDigit(b & 0xF, 16));
            }
            return hex.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("MD5 not available", e);
        }
    }
}
