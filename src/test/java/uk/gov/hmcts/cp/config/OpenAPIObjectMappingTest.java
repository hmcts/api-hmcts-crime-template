package uk.gov.hmcts.cp.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.junit.jupiter.api.Test;
import uk.gov.hmcts.cp.openapi.model.Response;

import static org.assertj.core.api.Assertions.assertThat;

class OpenAPIObjectMappingTest {

    private final ObjectMapper mapper = new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

    @Test
    void json_should_map_to_Response_object() throws Exception {
        String json = "{" +
                "    \"results\": [" +
                "        {" +
                "            \"resultText\": \"example result text\"" +
                "        }" +
                "    ]" +
                "}";

        Response response = mapper.readValue(json, Response.class);
        assertThat(response.getResults().get(0).getResultText()).isEqualTo("example result text");
    }
}
