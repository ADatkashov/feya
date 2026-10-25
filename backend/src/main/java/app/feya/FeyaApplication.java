package app.feya;

import app.feya.common.FeyaProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableConfigurationProperties(FeyaProperties.class)
@EnableScheduling
public class FeyaApplication {
    public static void main(String[] args) {
        SpringApplication.run(FeyaApplication.class, args);
    }
}
