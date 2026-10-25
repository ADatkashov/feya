package app.feya.notifications;

import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class NotificationConfig {
    @Bean
    @ConditionalOnMissingBean(PushSender.class)
    PushSender loggingPushSender() {
        return new LoggingPushSender();
    }
}
