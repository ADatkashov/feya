package app.feya.identity;

import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private final OtpService otp;
    private final AuthService auth;

    public AuthController(OtpService otp, AuthService auth) {
        this.otp = otp;
        this.auth = auth;
    }

    @PostMapping("/otp/request")
    public AuthDtos.OtpResponse requestOtp(@Valid @RequestBody AuthDtos.OtpRequest req) {
        OtpService.Issued issued = otp.request(PhoneNumbers.normalize(req.phone()));
        return new AuthDtos.OtpResponse(issued.expiresAt(), issued.devCode());
    }

    @PostMapping("/otp/verify")
    public AuthDtos.TokenResponse verifyOtp(@Valid @RequestBody AuthDtos.OtpVerifyRequest req) {
        return auth.loginWithOtp(req.phone(), req.code());
    }

    @PostMapping("/refresh")
    public AuthDtos.TokenResponse refresh(@Valid @RequestBody AuthDtos.RefreshRequest req) {
        return auth.refresh(req.refreshToken());
    }

    @PostMapping("/logout")
    public void logout(@Valid @RequestBody AuthDtos.RefreshRequest req) {
        auth.logout(req.refreshToken());
    }
}
