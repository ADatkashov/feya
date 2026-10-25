package app.feya.payments;

import app.feya.common.ApiException;
import app.feya.common.FeyaProperties;
import java.util.List;
import java.util.Optional;
import org.springframework.http.HttpStatus;

/** Resolves the configured provider; payments fail closed (503) when none is configured. */
public class PaymentProviders {
    private final List<PaymentProvider> providers;
    private final FeyaProperties props;

    public PaymentProviders(List<PaymentProvider> providers, FeyaProperties props) {
        this.providers = providers;
        this.props = props;
    }

    public PaymentProvider active() {
        return byId(props.payments().provider()).orElseThrow(() -> new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                "PAYMENTS_NOT_CONFIGURED", "Online payments are not configured"));
    }

    public Optional<PaymentProvider> byId(String id) {
        return providers.stream().filter(p -> p.id().equalsIgnoreCase(id)).findFirst();
    }

    public boolean configured() {
        return byId(props.payments().provider()).isPresent();
    }
}
