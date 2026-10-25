package app.feya.identity;

import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class SmsConfig {
    @Bean
    @ConditionalOnMissingBean(SmsSender.class)
    SmsSender loggingSmsSender() {
        return new LoggingSmsSender();
    }
}
