package com.carevora.service;

import com.carevora.dto.cognitive.CognitiveAiResult;
import com.carevora.entity.CognitiveAssessment;
import com.carevora.repository.AssessmentRepository;
import com.carevora.repository.CognitiveAssessmentRepository;
import com.carevora.repository.ResidentRepository;
import com.carevora.repository.SocialAuditRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestTemplate;

import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AiMlServiceTest {

    @Mock
    private RestTemplate restTemplate;

    @Mock
    private AssessmentRepository assessmentRepository;

    @Mock
    private ResidentRepository residentRepository;

    @Mock
    private SocialAuditRepository socialAuditRepository;

    @Mock
    private CognitiveAssessmentRepository cognitiveAssessmentRepository;

    private ObjectMapper objectMapper;
    private AiMlService aiMlService;

    @BeforeEach
    void setUp() {
        objectMapper = new ObjectMapper();
        aiMlService = new AiMlService(
                restTemplate,
                assessmentRepository,
                residentRepository,
                socialAuditRepository,
                cognitiveAssessmentRepository,
                objectMapper,
                "http://127.0.0.1:8000"
        );
    }

    private Map<String, Object> createMockFastApiResponse(double acrfScore, String prediction) {
        Map<String, Object> body = new HashMap<>();
        body.put("success", true);

        Map<String, Object> data = new HashMap<>();
        Map<String, Object> acrf = new HashMap<>();
        acrf.put("acrf_score", acrfScore);
        acrf.put("raw_weighted_score", acrfScore);
        acrf.put("scale", "0-100");
        acrf.put("scoring_direction", "Higher is better");
        data.put("acrf_assessment", acrf);

        Map<String, Object> mlStatus = new HashMap<>();
        mlStatus.put("available", true);
        mlStatus.put("model_type", "RandomForestClassifier");
        mlStatus.put("prediction", prediction);
        Map<String, Double> probs = new HashMap<>();
        probs.put("Low", 0.2);
        probs.put("Moderate", 0.7);
        probs.put("High", 0.1);
        mlStatus.put("probabilities", probs);
        mlStatus.put("alert_triggered", false);
        data.put("ml_model_evaluation", mlStatus);

        data.put("category_scores", Collections.emptyMap());
        data.put("category_contributions", Collections.emptyList());
        data.put("weights_applied", Collections.emptyMap());

        body.put("data", data);
        return body;
    }

    @Test
    void testPredictCognitive_ForwardsHistoricalResponseTimesCorrectly() {
        Long residentId = 37L;

        CognitiveAssessment past1 = CognitiveAssessment.builder()
                .id(91L)
                .memoryScore(75.0)
                .attentionScore(100.0)
                .orientationScore(50.0)
                .recallScore(75.0)
                .reasoningScore(50.0)
                .responseTimesJson("{\"memory\":6.38,\"attention\":2.24,\"orientation\":53.54,\"recall\":4.41,\"reasoning\":5.10}")
                .build();

        when(cognitiveAssessmentRepository.findByResidentIdOrderByCreatedAtDesc(residentId))
                .thenReturn(List.of(past1));

        when(restTemplate.postForEntity(eq("http://127.0.0.1:8000/api/ml/predict-cognitive"), any(), eq(Map.class)))
                .thenReturn(new ResponseEntity<>(createMockFastApiResponse(100.0, "Moderate"), HttpStatus.OK));

        Map<String, Double> accuracies = Map.of(
                "memory", 1.0, "attention", 1.0, "orientation", 1.0, "recall", 1.0, "reasoning", 1.0
        );
        Map<String, Double> responseTimes = Map.of(
                "memory", 12.03, "attention", 5.80, "orientation", 21.20, "recall", 18.23, "reasoning", 10.88
        );

        CognitiveAiResult result = aiMlService.predictCognitive(
                residentId, 100.0, 100.0, 100.0, 100.0, 100.0,
                78, 12, accuracies, responseTimes
        );

        assertNotNull(result);
        assertEquals(100.0, result.getAcrfScore());
        assertEquals("Moderate", result.getMlModelEvaluation().getPrediction());

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, Object>> captor = ArgumentCaptor.forClass(Map.class);
        verify(restTemplate).postForEntity(eq("http://127.0.0.1:8000/api/ml/predict-cognitive"), captor.capture(), eq(Map.class));

        Map<String, Object> sentPayload = captor.getValue();
        assertEquals(residentId, sentPayload.get("resident_id"));
        assertEquals(2, sentPayload.get("assessment_number"));

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> sentHistory = (List<Map<String, Object>>) sentPayload.get("history");
        assertNotNull(sentHistory);
        assertEquals(1, sentHistory.size());

        Map<String, Object> h0 = sentHistory.get(0);
        assertEquals(75.0, h0.get("memory_score"));
        assertEquals(100.0, h0.get("attention_score"));
        assertEquals(50.0, h0.get("orientation_score"));

        // Verify historical response times are parsed and forwarded directly
        assertEquals(6.38, (Double) h0.get("memory_response_time"), 0.001);
        assertEquals(2.24, (Double) h0.get("attention_response_time"), 0.001);
        assertEquals(53.54, (Double) h0.get("orientation_response_time"), 0.001);
        assertEquals(4.41, (Double) h0.get("recall_response_time"), 0.001);
        assertEquals(5.10, (Double) h0.get("reasoning_response_time"), 0.001);
    }

    @Test
    void testPredictCognitive_HandlesNullOrMalformedHistoricalResponseTimesSafely() {
        Long residentId = 37L;

        CognitiveAssessment malformedPast = CognitiveAssessment.builder()
                .id(90L)
                .memoryScore(100.0)
                .attentionScore(100.0)
                .orientationScore(100.0)
                .recallScore(100.0)
                .reasoningScore(50.0)
                .responseTimesJson("{invalid-json-content: true")
                .build();

        CognitiveAssessment nullRtPast = CognitiveAssessment.builder()
                .id(89L)
                .memoryScore(80.0)
                .attentionScore(80.0)
                .orientationScore(80.0)
                .recallScore(80.0)
                .reasoningScore(80.0)
                .responseTimesJson(null)
                .build();

        // Pass chronological reverse (returned DESC by repository)
        when(cognitiveAssessmentRepository.findByResidentIdOrderByCreatedAtDesc(residentId))
                .thenReturn(List.of(malformedPast, nullRtPast));

        when(restTemplate.postForEntity(eq("http://127.0.0.1:8000/api/ml/predict-cognitive"), any(), eq(Map.class)))
                .thenReturn(new ResponseEntity<>(createMockFastApiResponse(92.5, "Low"), HttpStatus.OK));

        Map<String, Double> accuracies = Map.of(
                "memory", 1.0, "attention", 1.0, "orientation", 1.0, "recall", 1.0, "reasoning", 0.5
        );
        Map<String, Double> responseTimes = Map.of(
                "memory", 4.93, "attention", 2.07, "orientation", 6.00, "recall", 5.40, "reasoning", 5.25
        );

        assertDoesNotThrow(() -> {
            CognitiveAiResult result = aiMlService.predictCognitive(
                    residentId, 100.0, 100.0, 100.0, 100.0, 50.0,
                    78, 12, accuracies, responseTimes
            );
            assertNotNull(result);
        });

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, Object>> captor = ArgumentCaptor.forClass(Map.class);
        verify(restTemplate).postForEntity(eq("http://127.0.0.1:8000/api/ml/predict-cognitive"), captor.capture(), eq(Map.class));

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> sentHistory = (List<Map<String, Object>>) captor.getValue().get("history");
        assertNotNull(sentHistory);
        assertEquals(2, sentHistory.size());

        // Verify that for malformed and null records, no fake response times were fabricated
        assertFalse(sentHistory.get(0).containsKey("memory_response_time"));
        assertFalse(sentHistory.get(1).containsKey("memory_response_time"));
    }

    @Test
    void predictMetabolicPostsPayloadAndReturnsData() {
        Map<String, Object> data = Map.of("model_version", "carevora_risk_v1", "results", Map.of());
        when(restTemplate.postForEntity(eq("http://127.0.0.1:8000/api/ml/predict-metabolic"), any(), eq(Map.class)))
                .thenReturn(new ResponseEntity<>(Map.of("success", true, "data", data), HttpStatus.OK));

        Map<String, Object> payload = Map.of("age", 70.0, "sex", "male");
        Map<String, Object> result = aiMlService.predictMetabolic(payload);

        assertEquals("carevora_risk_v1", result.get("model_version"));
        verify(restTemplate).postForEntity(eq("http://127.0.0.1:8000/api/ml/predict-metabolic"), eq(payload), eq(Map.class));
    }

    @Test
    void predictMetabolicMapsValidationErrorsAndOutages() {
        when(restTemplate.postForEntity(eq("http://127.0.0.1:8000/api/ml/predict-metabolic"), any(), eq(Map.class)))
                .thenThrow(org.springframework.web.client.HttpClientErrorException.create(
                        HttpStatus.UNPROCESSABLE_ENTITY, "Unprocessable", null, "{\"detail\":\"sex\"}".getBytes(), null))
                .thenThrow(new org.springframework.web.client.ResourceAccessException("Connection refused"));

        assertThrows(com.carevora.exception.BadRequestException.class, () -> aiMlService.predictMetabolic(Map.of()));
        assertThrows(com.carevora.exception.AiServiceException.class, () -> aiMlService.predictMetabolic(Map.of()));
    }
}
