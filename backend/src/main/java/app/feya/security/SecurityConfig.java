package app.feya.security;

import app.feya.common.ErrorResponse;
import app.feya.common.FeyaProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    JwtDecoder jwtDecoder(JwtService jwtService) {
        return jwtService.decoder();
    }

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http, ObjectMapper mapper, RateLimitFilter rateLimitFilter)
            throws Exception {
        http.csrf(c -> c.disable())
                .cors(c -> {})
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .headers(h -> h.referrerPolicy(r -> r.policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.NO_REFERRER))
                        .contentTypeOptions(c -> {})
                        .frameOptions(f -> f.deny()))
                .authorizeHttpRequests(a -> a
                        .requestMatchers("/api/v1/auth/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/v1/categories", "/api/v1/home",
                                "/api/v1/products", "/api/v1/products/*", "/api/v1/products/*/related",
                                "/api/v1/products/*/reviews").permitAll()
                        .requestMatchers("/api/v1/delivery/**").permitAll()
                        .requestMatchers(HttpMethod.POST, "/api/v1/cart/quote").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/v1/payments/methods").permitAll()
                        .requestMatchers("/api/v1/payments/webhook/**").permitAll()
                        .requestMatchers("/media/**", "/admin/**", "/error", "/favicon.ico").permitAll()
                        .requestMatchers("/actuator/health/**", "/actuator/health", "/actuator/info").permitAll()
                        .requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll()
                        .requestMatchers("/api/v1/admin/**").hasAnyRole("ADMIN", "SUPPORT")
                        .requestMatchers("/api/v1/florist/**").hasAnyRole("FLORIST", "ADMIN")
                        .requestMatchers("/api/v1/courier/**").hasRole("COURIER")
                        .requestMatchers("/api/v1/**").authenticated()
                        .anyRequest().denyAll())
                .oauth2ResourceServer(o -> o.jwt(j -> j.jwtAuthenticationConverter(jwtConverter()))
                        .authenticationEntryPoint((req, res, ex) -> writeError(mapper, res, 401, "UNAUTHORIZED",
                                "Authentication required"))
                        .accessDeniedHandler((req, res, ex) -> writeError(mapper, res, 403, "FORBIDDEN", "Access denied")))
                .exceptionHandling(e -> e
                        .authenticationEntryPoint((req, res, ex) -> writeError(mapper, res, 401, "UNAUTHORIZED",
                                "Authentication required"))
                        .accessDeniedHandler((req, res, ex) -> writeError(mapper, res, 403, "FORBIDDEN", "Access denied")))
                .addFilterBefore(rateLimitFilter, org.springframework.security.web.authentication.www.BasicAuthenticationFilter.class);
        return http.build();
    }

    private static void writeError(ObjectMapper mapper, jakarta.servlet.http.HttpServletResponse res, int status,
                                   String code, String message) throws java.io.IOException {
        res.setStatus(status);
        res.setContentType(MediaType.APPLICATION_JSON_VALUE);
        mapper.writeValue(res.getOutputStream(), ErrorResponse.of(code, message));
    }

    private Converter<Jwt, AbstractAuthenticationToken> jwtConverter() {
        JwtAuthenticationConverter c = new JwtAuthenticationConverter();
        c.setJwtGrantedAuthoritiesConverter(jwt -> {
            Collection<GrantedAuthority> out = new ArrayList<>();
            List<String> roles = jwt.getClaimAsStringList("roles");
            if (roles != null) {
                roles.forEach(r -> out.add(new SimpleGrantedAuthority("ROLE_" + r)));
            }
            return out;
        });
        return c;
    }

    @Bean
    CorsConfigurationSource corsConfigurationSource(FeyaProperties props) {
        CorsConfiguration cfg = new CorsConfiguration();
        if (props.cors() != null) {
            if (props.cors().allowedOrigins() != null) {
                cfg.setAllowedOrigins(props.cors().allowedOrigins().stream().filter(s -> !s.isBlank()).toList());
            }
            if (props.cors().allowedOriginPatterns() != null) {
                cfg.setAllowedOriginPatterns(props.cors().allowedOriginPatterns().stream().filter(s -> !s.isBlank()).toList());
            }
        }
        cfg.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        cfg.setAllowedHeaders(List.of("Authorization", "Content-Type", "Accept-Language", "Idempotency-Key",
                "X-Webhook-Signature"));
        cfg.setExposedHeaders(List.of("Retry-After"));
        cfg.setMaxAge(3600L);
        UrlBasedCorsConfigurationSource src = new UrlBasedCorsConfigurationSource();
        src.registerCorsConfiguration("/api/**", cfg);
        return src;
    }
}
