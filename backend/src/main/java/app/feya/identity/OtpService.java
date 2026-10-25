package app.feya.identity;

import app.feya.common.ApiException;
import app.feya.common.FeyaProperties;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OtpService {
    public record Issued(Instant expiresAt, String devCode) {}

    private final OtpCodeRepository repo;
    private final SmsSender sms;
    private final FeyaProperties props;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();

    public OtpService(OtpCodeRepository repo, SmsSender sms, FeyaProperties props, Clock clock) {
        this.repo = repo;
        this.sms = sms;
        this.props = props;
        this.clock = clock;
    }

    @Transactional
    public Issued request(String phone) {
        Instant now = clock.instant();
        long recent = repo.countByPhoneAndCreatedAtAfter(phone, now.minus(Duration.ofMinutes(10)));
        if (recent >= props.auth().otpMaxPerPhonePer10min()) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "OTP_RATE_LIMITED", "Too many code requests, try later");
        }
        int len = props.auth().otpLength();
        StringBuilder code = new StringBuilder();
        for (int i = 0; i < len; i++) {
            code.append(random.nextInt(10));
        }
        OtpCode otp = new OtpCode();
        otp.setPhone(phone);
        otp.setCodeHash(hash(phone, code.toString()));
        otp.setCreatedAt(now);
        otp.setExpiresAt(now.plus(props.auth().otpTtl()));
        repo.save(otp);
        sms.sendOtp(phone, code.toString());
        return new Issued(otp.getExpiresAt(), props.auth().devOtpEnabled() ? code.toString() : null);
    }

    /** Verifies and consumes the latest active code for the phone. Wrong guesses are counted and capped. */
    @Transactional(noRollbackFor = ApiException.class)
    public void verify(String phone, String code) {
        Instant now = clock.instant();
        OtpCode otp = repo.findFirstByPhoneAndConsumedFalseOrderByCreatedAtDesc(phone)
                .orElseThrow(() -> ApiException.badRequest("OTP_INVALID", "Invalid or expired code"));
        if (otp.getExpiresAt().isBefore(now) || otp.getAttempts() >= props.auth().otpMaxAttempts()) {
            otp.setConsumed(true);
            throw ApiException.badRequest("OTP_INVALID", "Invalid or expired code");
        }
        boolean ok = code != null && MessageDigest.isEqual(
                hash(phone, code).getBytes(StandardCharsets.UTF_8), otp.getCodeHash().getBytes(StandardCharsets.UTF_8));
        if (!ok) {
            otp.setAttempts(otp.getAttempts() + 1);
            throw ApiException.badRequest("OTP_INVALID", "Invalid or expired code");
        }
        otp.setConsumed(true);
    }

    private String hash(String phone, String code) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(props.jwt().secret().getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal((phone + ":" + code).getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    @Scheduled(cron = "0 15 * * * *")
    @Transactional
    public void cleanup() {
        repo.deleteExpired(clock.instant().minus(Duration.ofHours(1)));
    }
}
