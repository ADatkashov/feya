package app.feya.payments.freedompay;

/** A transport-level failure talking to FreedomPay (network, non-2xx, malformed XML). Never a payment outcome. */
public class FreedomPayException extends RuntimeException {
    public FreedomPayException(String message) {
        super(message);
    }

    public FreedomPayException(String message, Throwable cause) {
        super(message, cause);
    }
}
