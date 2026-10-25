package app.feya.common;

import java.time.Clock;
import java.time.ZoneId;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {
    private final LangArgumentResolver langResolver;
    private final FeyaProperties props;

    public WebConfig(LangArgumentResolver langResolver, FeyaProperties props) {
        this.langResolver = langResolver;
        this.props = props;
    }

    @Override
    public void addArgumentResolvers(List<HandlerMethodArgumentResolver> resolvers) {
        resolvers.add(langResolver);
    }

    @Override
    public void addViewControllers(org.springframework.web.servlet.config.annotation.ViewControllerRegistry registry) {
        registry.addRedirectViewController("/admin", "/admin/index.html");
        registry.addRedirectViewController("/admin/", "/admin/index.html");
    }

    @Override
    public void addResourceHandlers(org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry registry) {
        String dir = java.nio.file.Path.of(props.media().uploadDir()).toAbsolutePath().toUri().toString();
        registry.addResourceHandler("/media/uploads/**").addResourceLocations(dir);
        registry.addResourceHandler("/media/**").addResourceLocations("classpath:/media/")
                .setCacheControl(org.springframework.http.CacheControl.maxAge(java.time.Duration.ofDays(7)).cachePublic());
    }

    @Bean
    public Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    public ZoneId businessZone(FeyaProperties props) {
        return ZoneId.of(props.timezone());
    }
}
