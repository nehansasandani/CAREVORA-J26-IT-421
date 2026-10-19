package com.carevora.controller;

import com.carevora.security.CustomUserDetailsService;
import com.carevora.security.JwtService;
import com.carevora.service.AiMlService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.HashMap;
import java.util.Map;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
class MetabolicAssessmentIntegrationTest {

    private static final String BODY = "{\"sex\":\"female\",\"waistCm\":96,\"heightCm\":160,\"systolicBp\":138}";

    @Autowired private MockMvc mockMvc;
    @Autowired private JwtService jwtService;
    @Autowired private CustomUserDetailsService userDetailsService;

    @MockBean private AiMlService aiMlService;

    private String caregiverToken;
    private String caregiverOtherHomeToken;
    private String elderToken;

    @BeforeEach
    void setUp() {
        caregiverToken = jwtService.generateToken(userDetailsService.loadUserByUsername("eleanor.vance@carevora.com"));
        caregiverOtherHomeToken = jwtService.generateToken(userDetailsService.loadUserByUsername("david.silva@carevora.com"));
        elderToken = jwtService.generateToken(userDetailsService.loadUserByUsername("sarah.jenkins@carevora.com"));

        when(aiMlService.predictMetabolic(any())).thenAnswer(inv -> {
            Map<String, Object> results = new HashMap<>();
            results.put("diabetes", Map.of("status", "ok", "model_tier", "home", "risk_tier", "watch", "probability", 0.27));
            results.put("cvd", Map.of("status", "ok", "model_tier", "home", "risk_tier", "low", "probability", 0.06));
            results.put("fatty_liver", Map.of("status", "ok", "model_tier", "home", "risk_tier", "watch", "probability", 0.58));
            Map<String, Object> data = new HashMap<>();
            data.put("model_version", "carevora_risk_v1");
            data.put("disclaimer", "This is a screening estimate based on survey data, not a diagnosis.");
            data.put("results", results);
            return data;
        });
    }

    @Test
    void unauthenticatedSubmitReturns401() throws Exception {
        mockMvc.perform(post("/api/residents/1/metabolic-assessments")
                        .contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void caregiverSameHomeCanSubmitAndReadHistory() throws Exception {
        mockMvc.perform(post("/api/residents/1/metabolic-assessments")
                        .header("Authorization", "Bearer " + caregiverToken)
                        .contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.residentId").value(1))
                .andExpect(jsonPath("$.data.result.results.diabetes.risk_tier").value("watch"))
                .andExpect(jsonPath("$.data.inputs.sex").value("female"));

        mockMvc.perform(get("/api/residents/1/metabolic-assessments/latest")
                        .header("Authorization", "Bearer " + caregiverToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.result.results.cvd.risk_tier").value("low"));

        mockMvc.perform(get("/api/residents/1/metabolic-assessments")
                        .header("Authorization", "Bearer " + caregiverToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data").isArray());
    }

    @Test
    void historyIsPaginatedNewestFirst() throws Exception {
        for (int i = 0; i < 3; i++) {
            mockMvc.perform(post("/api/residents/2/metabolic-assessments")
                            .header("Authorization", "Bearer " + caregiverToken)
                            .contentType(MediaType.APPLICATION_JSON).content(BODY))
                    .andExpect(status().isOk());
        }
        mockMvc.perform(get("/api/residents/2/metabolic-assessments/history?page=0&size=2")
                        .header("Authorization", "Bearer " + caregiverToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items.length()").value(2))
                .andExpect(jsonPath("$.data.page").value(0))
                .andExpect(jsonPath("$.data.size").value(2))
                .andExpect(jsonPath("$.data.totalItems").isNumber())
                .andExpect(jsonPath("$.data.totalPages").isNumber());

        String today = java.time.LocalDate.now().toString();
        mockMvc.perform(get("/api/residents/2/metabolic-assessments/history?from=" + today + "&to=" + today)
                        .header("Authorization", "Bearer " + caregiverToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalItems").value(org.hamcrest.Matchers.greaterThanOrEqualTo(3)));
        mockMvc.perform(get("/api/residents/2/metabolic-assessments/history?from=2000-01-01&to=2000-12-31")
                        .header("Authorization", "Bearer " + caregiverToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalItems").value(0));
        mockMvc.perform(get("/api/residents/2/metabolic-assessments/history?from=2026-10-19&to=2026-10-01")
                        .header("Authorization", "Bearer " + caregiverToken))
                .andExpect(status().isBadRequest());

        mockMvc.perform(get("/api/residents/2/metabolic-assessments/history?page=0&size=500")
                        .header("Authorization", "Bearer " + caregiverToken))
                .andExpect(status().isBadRequest());
    }

    @Test
    void trendListsScreeningsUpToTheSelectedOne() throws Exception {
        long lastId = 0;
        for (int i = 0; i < 3; i++) {
            String body = mockMvc.perform(post("/api/residents/1/metabolic-assessments")
                            .header("Authorization", "Bearer " + caregiverToken)
                            .contentType(MediaType.APPLICATION_JSON).content(BODY))
                    .andExpect(status().isOk())
                    .andReturn().getResponse().getContentAsString();
            lastId = com.jayway.jsonpath.JsonPath.parse(body).read("$.data.id", Long.class);
        }
        mockMvc.perform(get("/api/residents/1/metabolic-assessments/" + lastId + "/trend?limit=3")
                        .header("Authorization", "Bearer " + caregiverToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(3))
                .andExpect(jsonPath("$.data[2].id").value(lastId))
                .andExpect(jsonPath("$.data[2].outcomes.diabetes.riskTier").value("watch"))
                .andExpect(jsonPath("$.data[2].outcomes.diabetes.probability").value(0.27));

        mockMvc.perform(get("/api/residents/1/metabolic-assessments/" + lastId + "/trend")
                        .header("Authorization", "Bearer " + caregiverOtherHomeToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void caregiverFromOtherHomeIsForbidden() throws Exception {
        mockMvc.perform(post("/api/residents/1/metabolic-assessments")
                        .header("Authorization", "Bearer " + caregiverOtherHomeToken)
                        .contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("ACCESS_DENIED"));
    }

    @Test
    void elderCannotReadAnotherResident() throws Exception {
        mockMvc.perform(get("/api/residents/2/metabolic-assessments")
                        .header("Authorization", "Bearer " + elderToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void invalidSexIsRejectedBeforeCallingTheAiService() throws Exception {
        mockMvc.perform(post("/api/residents/1/metabolic-assessments")
                        .header("Authorization", "Bearer " + caregiverToken)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"sex\":\"unknown\"}"))
                .andExpect(status().isBadRequest());
    }
}
