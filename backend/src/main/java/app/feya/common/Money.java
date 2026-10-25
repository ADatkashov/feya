package app.feya.common;

import java.math.BigDecimal;
import java.math.RoundingMode;

/** Monetary helpers. All amounts are KZT with 2 decimal digits; discounts round to whole tenge (HALF_UP). */
public final class Money {
    public static final String KZT = "KZT";
    public static final BigDecimal ZERO = BigDecimal.ZERO.setScale(2);

    private Money() {}

    public static BigDecimal of(long value) {
        return BigDecimal.valueOf(value).setScale(2, RoundingMode.UNNECESSARY);
    }

    public static BigDecimal scale(BigDecimal value) {
        return value.setScale(2, RoundingMode.HALF_UP);
    }

    public static BigDecimal wholeTenge(BigDecimal value) {
        return value.setScale(0, RoundingMode.HALF_UP).setScale(2);
    }

    public static BigDecimal min(BigDecimal a, BigDecimal b) {
        return a.compareTo(b) <= 0 ? a : b;
    }

    public static BigDecimal max(BigDecimal a, BigDecimal b) {
        return a.compareTo(b) >= 0 ? a : b;
    }
}
