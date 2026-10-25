package app.feya.support;

import java.time.Instant;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

@TestConfiguration
public class TestClockConfig {
    /** Monday 2026-11-02 11:00 in Asia/Almaty (UTC+5). */
    public static final Instant DEFAULT_NOW = Instant.parse("2026-11-02T06:00:00Z");

    @Bean
    @Primary
    public MutableClock testClock() {
        return new MutableClock(DEFAULT_NOW);
    }
}
