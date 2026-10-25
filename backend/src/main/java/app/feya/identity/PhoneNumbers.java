package app.feya.identity;

import app.feya.common.ApiException;

/** Normalizes phone numbers to E.164. Kazakhstan numbers (8/7/+7 + 10 digits) are the primary format. */
public final class PhoneNumbers {
    private PhoneNumbers() {}

    public static String normalize(String raw) {
        if (raw == null) {
            throw ApiException.badRequest("INVALID_PHONE", "Phone number is required");
        }
        String digits = raw.replaceAll("[^0-9+]", "");
        boolean plus = digits.startsWith("+");
        digits = digits.replace("+", "");
        if (!plus) {
            if (digits.length() == 11 && digits.startsWith("8")) {
                digits = "7" + digits.substring(1);
            } else if (digits.length() == 10) {
                digits = "7" + digits;
            }
        }
        if (digits.length() < 8 || digits.length() > 15 || digits.startsWith("0")) {
            throw ApiException.badRequest("INVALID_PHONE", "Invalid phone number");
        }
        if (digits.startsWith("7") && (digits.length() != 11 || "012".indexOf(digits.charAt(1)) >= 0)) {
            throw ApiException.badRequest("INVALID_PHONE", "Invalid phone number");
        }
        return "+" + digits;
    }

    public static String mask(String phone) {
        if (phone == null || phone.length() < 6) {
            return "***";
        }
        return phone.substring(0, 3) + "***" + phone.substring(phone.length() - 2);
    }
}
