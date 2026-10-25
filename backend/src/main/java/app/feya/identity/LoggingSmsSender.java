package app.feya.identity;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** Default sender when no SMS gateway is configured: does NOT log the code, only that a message would be sent. */
public class LoggingSmsSender implements SmsSender {
    private static final Logger log = LoggerFactory.getLogger(LoggingSmsSender.class);

    @Override
    public void sendOtp(String phone, String code) {
        log.warn("No SMS gateway configured; OTP for {} was NOT delivered", PhoneNumbers.mask(phone));
    }
}
