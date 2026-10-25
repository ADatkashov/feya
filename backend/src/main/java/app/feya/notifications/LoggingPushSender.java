package app.feya.notifications;

import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** Fallback used when no push provider (e.g. FCM) is configured: the in-app inbox still works. */
public class LoggingPushSender implements PushSender {
    private static final Logger log = LoggerFactory.getLogger(LoggingPushSender.class);

    @Override
    public void send(List<String> deviceTokens, String title, String body, String data) {
        log.info("Push provider not configured; skipped push to {} device(s)", deviceTokens.size());
    }
}
