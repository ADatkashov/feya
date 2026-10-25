package app.feya;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import app.feya.support.TestClockConfig;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

/**
 * The other API tests share one transaction per test, which can hide bugs that only appear when each request has its
 * own transaction boundary (this is how a real server behaves). These requests run without a surrounding transaction.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(TestClockConfig.class)
class NonTransactionalApiIT {
    @Autowired MockMvc mvc;

    private int status(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder b) throws Exception {
        return mvc.perform(b).andReturn().getResponse().getStatus();
    }

    @Test
    void readOnlyPublicEndpointsWorkOutsideATransaction() throws Exception {
        assertThat(status(get("/api/v1/delivery/slots?days=3"))).isEqualTo(200);
        assertThat(status(get("/api/v1/delivery/zones"))).isEqualTo(200);
        assertThat(status(get("/api/v1/home"))).isEqualTo(200);
        assertThat(status(get("/api/v1/products?size=5"))).isEqualTo(200);
        assertThat(status(get("/api/v1/products/romantika"))).isEqualTo(200);
        assertThat(status(get("/api/v1/products/romantika/related"))).isEqualTo(200);
        assertThat(status(get("/api/v1/categories"))).isEqualTo(200);
        assertThat(status(get("/api/v1/payments/methods"))).isEqualTo(200);
        assertThat(status(get("/actuator/health"))).isEqualTo(200);
    }

    @Test
    void quoteWorksOutsideATransaction() throws Exception {
        String body = """
                {"items":[{"variantId":"%s","quantity":1}]}""".formatted(
                mvc.perform(get("/api/v1/products/romantika")).andReturn().getResponse().getContentAsString()
                        .replaceAll("(?s).*\"variants\":\\[\\{\"id\":\"([0-9a-f-]+)\".*", "$1"));
        var res = mvc.perform(post("/api/v1/cart/quote").contentType(MediaType.APPLICATION_JSON).content(body)).andReturn();
        assertThat(res.getResponse().getStatus()).isEqualTo(200);
    }
}
