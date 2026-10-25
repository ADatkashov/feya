package app.feya.common;

import org.springframework.stereotype.Component;

/** Product images are stored as relative paths (/media/...); an optional CDN base URL is prepended when configured. */
@Component
public class MediaUrls {
    private final String base;

    public MediaUrls(FeyaProperties props) {
        String b = props.media() == null ? null : props.media().baseUrl();
        this.base = b == null ? "" : b.replaceAll("/+$", "");
    }

    public String resolve(String url) {
        if (url == null || url.isBlank()) {
            return null;
        }
        if (url.startsWith("http://") || url.startsWith("https://") || base.isEmpty()) {
            return url;
        }
        return base + (url.startsWith("/") ? url : "/" + url);
    }
}
