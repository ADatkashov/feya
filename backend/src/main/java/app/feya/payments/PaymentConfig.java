package app.feya.payments;

import app.feya.common.FeyaProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import app.feya.payments.freedompay.FreedomPayProperties;
import app.feya.payments.freedompay.FreedomPayProvider;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@org.springframework.boot.context.properties.EnableConfigurationProperties(FreedomPayProperties.class)
public class PaymentConfig {
    /** Registered only when explicitly selected; never in production. */
    @Bean
    @org.springframework.boot.autoconfigure.condition.ConditionalOnProperty(name = "feya.payments.provider", havingValue = "sandbox")
    SandboxPaymentProvider sandboxPaymentProvider(FeyaProperties props, ObjectMapper mapper) {
        return new SandboxPaymentProvider(props, mapper);
    }

    /** Registered only when explicitly selected (FEYA_PAYMENTS_PROVIDER=freedompay); fails at startup if misconfigured. */
    @Bean
    @org.springframework.boot.autoconfigure.condition.ConditionalOnProperty(name = "feya.payments.provider", havingValue = "freedompay")
    FreedomPayProvider freedomPayProvider(FreedomPayProperties props) {
        return new FreedomPayProvider(props);
    }

    @Bean
    PaymentProviders paymentProviders(List<PaymentProvider> providers, FeyaProperties props) {
        return new PaymentProviders(providers, props);
    }
}
