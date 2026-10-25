package app.feya.notifications;

import java.util.List;

/** Delivers push messages to device tokens. The default implementation only logs (no credentials needed). */
public interface PushSender {
    void send(List<String> deviceTokens, String title, String body, String data);
}
