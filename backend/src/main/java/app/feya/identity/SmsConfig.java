package app.feya.identity;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class SmsConfig {
    /** Default (and the fallback when no gateway is configured): never delivers anything. */
    @Bean
    @ConditionalOnMissingBean(SmsSender.class)
    @ConditionalOnProperty(name = "feya.sms.provider", havingValue = "logging", matchIfMissing = true)
    SmsSender loggingSmsSender() {
        return new LoggingSmsSender();
    }

    @Bean
    @ConditionalOnProperty(name = "feya.sms.provider", havingValue = "twilio")
    SmsSender twilioSmsSender(@Value("${feya.sms.twilio.account-sid:}") String accountSid,
                              @Value("${feya.sms.twilio.auth-token:}") String authToken,
                              @Value("${feya.sms.twilio.from:}") String from,
                              @Value("${feya.sms.twilio.messaging-service-sid:}") String messagingServiceSid,
                              @Value("${feya.sms.twilio.base-url:}") String baseUrl) {
        return new TwilioSmsSender(accountSid, authToken, from, messagingServiceSid, baseUrl);
    }
}
