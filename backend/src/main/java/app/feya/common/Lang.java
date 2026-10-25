package app.feya.common;

import java.util.Locale;
import java.util.Map;

/** Supported UI languages. Russian is the default and the fallback. */
public enum Lang {
    RU("ru"), KK("kk"), EN("en");

    private final String code;

    Lang(String code) {
        this.code = code;
    }

    public String code() {
        return code;
    }

    public static Lang parse(String value) {
        if (value == null || value.isBlank()) {
            return RU;
        }
        String v = value.trim().toLowerCase(Locale.ROOT);
        for (Lang l : values()) {
            if (v.equals(l.code) || v.startsWith(l.code + "-") || v.startsWith(l.code + "_")) {
                return l;
            }
        }
        return RU;
    }

    /** Parses an Accept-Language header, picking the first supported language. */
    public static Lang fromAcceptLanguage(String header) {
        if (header == null || header.isBlank()) {
            return RU;
        }
        for (String part : header.split(",")) {
            String tag = part.split(";")[0].trim().toLowerCase(Locale.ROOT);
            for (Lang l : values()) {
                if (tag.equals(l.code) || tag.startsWith(l.code + "-")) {
                    return l;
                }
            }
        }
        return RU;
    }

    public String pick(Map<String, String> texts) {
        if (texts == null || texts.isEmpty()) {
            return "";
        }
        String v = texts.get(code);
        if (v != null && !v.isBlank()) {
            return v;
        }
        v = texts.get("ru");
        if (v != null && !v.isBlank()) {
            return v;
        }
        return texts.values().stream().filter(s -> s != null && !s.isBlank()).findFirst().orElse("");
    }
}
