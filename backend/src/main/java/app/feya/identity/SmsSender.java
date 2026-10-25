package app.feya.identity;

/** Delivers one-time codes. Plug a real SMS gateway by providing another bean of this type. */
public interface SmsSender {
    void sendOtp(String phone, String code);
}
