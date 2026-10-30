package app.feya;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import app.feya.payments.PaymentController;
import app.feya.payments.PaymentProvider;
import app.feya.payments.PaymentProviders;
import app.feya.payments.PaymentService;
import app.feya.payments.freedompay.FreedomPayProperties;
import app.feya.payments.freedompay.FreedomPayProvider;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

/** FreedomPay posts a form, and the signature must be checked over exactly the bytes it sent. */
class PaymentWebhookFormTest {

    @Test
    void aFormCallbackReachesTheServiceUntouchedAndIsAcknowledgedWithXml() throws Exception {
        PaymentService service = mock(PaymentService.class);
        PaymentProviders providers = mock(PaymentProviders.class);
        PaymentProvider provider = new FreedomPayProvider(
                new FreedomPayProperties("http://localhost", "m", "s", "result.php", null, null));
        when(providers.byId("freedompay")).thenReturn(Optional.of(provider));
        MockMvc mvc = MockMvcBuilders.standaloneSetup(new PaymentController(service, providers)).build();

        String raw = "pg_payment_id=fp-1&pg_result=1&pg_description=a%20b&pg_sig=abc";
        mvc.perform(post("/api/v1/payments/webhook/freedompay").contentType(MediaType.APPLICATION_FORM_URLENCODED)
                        .content(raw))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_XML))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("<pg_status>ok</pg_status>")));
        verify(service).handleWebhook(eq("freedompay"), eq(raw), isNull());
    }

    @Test
    void providersWithoutAnAckGetAnEmptyOk() throws Exception {
        PaymentService service = mock(PaymentService.class);
        PaymentProviders providers = mock(PaymentProviders.class);
        PaymentProvider provider = mock(PaymentProvider.class);
        when(providers.byId("sandbox")).thenReturn(Optional.of(provider));
        MockMvc mvc = MockMvcBuilders.standaloneSetup(new PaymentController(service, providers)).build();
        String body = mvc.perform(post("/api/v1/payments/webhook/sandbox").contentType(MediaType.APPLICATION_JSON)
                        .header("X-Webhook-Signature", "sig").content("{}"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        assertThat(body).isEmpty();
        verify(service).handleWebhook("sandbox", "{}", "sig");
    }
}
