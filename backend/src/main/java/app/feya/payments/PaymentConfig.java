package app.feya.payments;

import app.feya.common.FeyaProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class PaymentConfig {
    /** Registered only when explicitly selected; never in production. */
    @Bean
    @org.springframework.boot.autoconfigure.condition.ConditionalOnProperty(name = "feya.payments.provider", havingValue = "sandbox")
    SandboxPaymentProvider sandboxPaymentProvider(FeyaProperties props, ObjectMapper mapper) {
        return new SandboxPaymentProvider(props, mapper);
    }

    @Bean
    PaymentProviders paymentProviders(List<PaymentProvider> providers, FeyaProperties props) {
        return new PaymentProviders(providers, props);
    }
}
