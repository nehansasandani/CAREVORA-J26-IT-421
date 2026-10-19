package com.carevora.service;

import com.carevora.dto.ApiResponse;
import com.carevora.dto.metabolic.MetabolicAssessmentRequest;
import com.carevora.dto.metabolic.MetabolicAssessmentResponse;
import com.carevora.entity.Alert;
import com.carevora.entity.MetabolicAssessment;
import com.carevora.entity.Resident;
import com.carevora.entity.User;
import com.carevora.enums.AlertType;
import com.carevora.dto.metabolic.MetabolicHistoryPageResponse;
import com.carevora.exception.BadRequestException;
import com.carevora.exception.ResourceNotFoundException;
import com.carevora.repository.AlertRepository;
import com.carevora.repository.CaregiverRepository;
import com.carevora.repository.MetabolicAssessmentRepository;
import com.carevora.repository.ResidentRepository;
import com.carevora.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MetabolicAssessmentServiceTest {

    @Mock private MetabolicAssessmentRepository metabolicAssessmentRepository;
    @Mock private ResidentRepository residentRepository;
    @Mock private UserRepository userRepository;
    @Mock private CaregiverRepository caregiverRepository;
    @Mock private AlertRepository alertRepository;
    @Mock private AiMlService aiMlService;

    private MetabolicAssessmentService service;
    private Resident resident;

    @BeforeEach
    void setUp() {
        service = new MetabolicAssessmentService(metabolicAssessmentRepository, residentRepository, userRepository,
                caregiverRepository, alertRepository, aiMlService, new ObjectMapper());
        User user = User.builder().id(10L).firstName("Sarah").lastName("Jenkins").build();
        resident = Resident.builder().id(1L).user(user).age(78).roomNumber("Suite 204").build();
    }

    private static Map<String, Object> aiResult(String diabetesTier, String cvdTier) {
        Map<String, Object> results = new HashMap<>();
        results.put("diabetes", Map.of("status", "ok", "risk_tier", diabetesTier, "probability", 0.31));
        results.put("cvd", Map.of("status", "ok", "risk_tier", cvdTier, "probability", 0.21));
        results.put("fatty_liver", Map.of("status", "insufficient_information", "missing_inputs", List.of("waist_cm")));
        Map<String, Object> data = new HashMap<>();
        data.put("resident_id", 1);
        data.put("model_version", "carevora_risk_v1");
        data.put("disclaimer", "This is a screening estimate based on survey data, not a diagnosis.");
        data.put("results", results);
        return data;
    }

    @Test
    void submitSendsSnakeCasePayloadWithResidentAgeAndStoresSummary() {
        when(residentRepository.findById(1L)).thenReturn(Optional.of(resident));
        when(aiMlService.predictMetabolic(any())).thenReturn(aiResult("watch", "low"));
        when(metabolicAssessmentRepository.save(any(MetabolicAssessment.class))).thenAnswer(inv -> inv.getArgument(0));

        MetabolicAssessmentRequest request = MetabolicAssessmentRequest.builder()
                .sex("female").waistCm(96.0).heightCm(160.0).systolicBp(138.0)
                .onBpMeds(true).toldHighCholesterol(false).hba1c(6.1).stepsPerDay(4200.0)
                .build();

        ApiResponse<MetabolicAssessmentResponse> response = service.submitAssessment(1L, request);

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, Object>> payload = ArgumentCaptor.forClass(Map.class);
        verify(aiMlService).predictMetabolic(payload.capture());
        Map<String, Object> sent = payload.getValue();
        assertEquals(1L, sent.get("resident_id"));
        assertEquals(78.0, sent.get("age"));                 // defaulted from the resident record
        assertEquals("female", sent.get("sex"));
        assertEquals(96.0, sent.get("waist_cm"));
        assertEquals(138.0, sent.get("systolic_bp"));
        assertEquals(true, sent.get("on_bp_meds"));
        assertEquals(false, sent.get("told_high_cholesterol"));
        assertEquals(6.1, sent.get("hba1c"));
        assertEquals(4200.0, sent.get("steps_per_day"));
        assertFalse(sent.containsKey("ldl"));                // nulls are not sent

        ArgumentCaptor<MetabolicAssessment> saved = ArgumentCaptor.forClass(MetabolicAssessment.class);
        verify(metabolicAssessmentRepository).save(saved.capture());
        assertEquals("watch", saved.getValue().getDiabetesTier());
        assertEquals(0.31, saved.getValue().getDiabetesProbability());
        assertEquals("low", saved.getValue().getCvdTier());
        assertNull(saved.getValue().getFattyLiverTier());
        assertEquals("carevora_risk_v1", saved.getValue().getModelVersion());

        assertTrue(response.isSuccess());
        assertEquals("Sarah Jenkins", response.getData().getResidentName());
        assertEquals("female", response.getData().getInputs().get("sex"));
        assertFalse(response.getData().getResult().containsKey("resident_id"));
        verify(alertRepository, never()).save(any());
    }

    @Test
    void highTierRaisesNonDiagnosticCaregiverAlert() {
        when(residentRepository.findById(1L)).thenReturn(Optional.of(resident));
        when(aiMlService.predictMetabolic(any())).thenReturn(aiResult("high", "high"));
        when(metabolicAssessmentRepository.save(any(MetabolicAssessment.class))).thenAnswer(inv -> inv.getArgument(0));

        service.submitAssessment(1L, MetabolicAssessmentRequest.builder().sex("female").build());

        ArgumentCaptor<Alert> alert = ArgumentCaptor.forClass(Alert.class);
        verify(alertRepository).save(alert.capture());
        assertEquals(AlertType.RISK_ALERT, alert.getValue().getType());
        assertTrue(alert.getValue().getMessage().contains("diabetes, cardiovascular disease"));
        assertTrue(alert.getValue().getMessage().contains("not a diagnosis"));
    }

    @Test
    void unknownResidentIsRejected() {
        when(residentRepository.findById(99L)).thenReturn(Optional.empty());
        assertThrows(ResourceNotFoundException.class,
                () -> service.submitAssessment(99L, new MetabolicAssessmentRequest()));
        verifyNoInteractions(aiMlService);
    }

    @Test
    void historyIsReturnedNewestFirstWithParsedResult() {
        when(residentRepository.findById(1L)).thenReturn(Optional.of(resident));
        MetabolicAssessment stored = MetabolicAssessment.builder().id(5L).resident(resident)
                .inputsJson("{\"sex\":\"female\"}")
                .resultJson("{\"results\":{\"cvd\":{\"risk_tier\":\"low\"}}}")
                .build();
        when(metabolicAssessmentRepository.findByResidentIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(stored));

        List<MetabolicAssessmentResponse> history = service.getResidentAssessments(1L).getData();

        assertEquals(1, history.size());
        assertEquals(5L, history.get(0).getId());
        assertTrue(history.get(0).getResult().containsKey("results"));
    }

    @Test
    void historyPageIsNewestFirstWithPageMetadata() {
        when(residentRepository.findById(1L)).thenReturn(Optional.of(resident));
        MetabolicAssessment stored = MetabolicAssessment.builder().id(7L).resident(resident)
                .inputsJson("{}").resultJson("{\"results\":{}}").build();
        when(metabolicAssessmentRepository.findByResidentId(eq(1L), any(Pageable.class)))
                .thenAnswer(inv -> new PageImpl<>(List.of(stored), inv.getArgument(1), 12));

        MetabolicHistoryPageResponse page = service.getResidentAssessmentPage(1L, 1, 5).getData();

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(metabolicAssessmentRepository).findByResidentId(eq(1L), pageable.capture());
        assertEquals(PageRequest.of(1, 5, Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("id"))), pageable.getValue());
        assertEquals(1, page.getPage());
        assertEquals(5, page.getSize());
        assertEquals(12, page.getTotalItems());
        assertEquals(3, page.getTotalPages());
        assertEquals(7L, page.getItems().get(0).getId());
    }

    @Test
    void historyPageFiltersByInclusiveDateRange() {
        when(residentRepository.findById(1L)).thenReturn(Optional.of(resident));
        when(metabolicAssessmentRepository.findByResidentIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                eq(1L), any(), any(), any(Pageable.class)))
                .thenAnswer(inv -> new PageImpl<>(List.of(), inv.getArgument(3), 0));

        service.getResidentAssessmentPage(1L, 0, 5,
                java.time.LocalDate.of(2026, 10, 1), java.time.LocalDate.of(2026, 10, 19));

        verify(metabolicAssessmentRepository).findByResidentIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                eq(1L), eq(java.time.LocalDateTime.of(2026, 10, 1, 0, 0)),
                eq(java.time.LocalDateTime.of(2026, 10, 20, 0, 0)), any(Pageable.class));
        verify(metabolicAssessmentRepository, never()).findByResidentId(any(), any());
    }

    @Test
    void historyPageRejectsReversedDateRange() {
        assertThrows(BadRequestException.class, () -> service.getResidentAssessmentPage(1L, 0, 5,
                java.time.LocalDate.of(2026, 10, 19), java.time.LocalDate.of(2026, 10, 1)));
    }

    @Test
    void trendReturnsScreeningsUpToTheSelectedOneOldestFirst() {
        java.time.LocalDateTime t = java.time.LocalDateTime.of(2026, 10, 19, 10, 0);
        MetabolicAssessment older = MetabolicAssessment.builder().id(3L).resident(resident).createdAt(t.minusDays(30))
                .diabetesTier("watch").diabetesProbability(0.22).cvdTier("high").cvdProbability(0.3).build();
        MetabolicAssessment selected = MetabolicAssessment.builder().id(5L).resident(resident).createdAt(t)
                .diabetesTier("low").diabetesProbability(0.16).cvdTier("high").cvdProbability(0.31).build();
        MetabolicAssessment sameInstantLater = MetabolicAssessment.builder().id(6L).resident(resident).createdAt(t)
                .diabetesTier("high").diabetesProbability(0.5).build();
        when(residentRepository.findById(1L)).thenReturn(Optional.of(resident));
        when(metabolicAssessmentRepository.findById(5L)).thenReturn(Optional.of(selected));
        when(metabolicAssessmentRepository.findByResidentIdAndCreatedAtLessThanEqual(eq(1L), eq(t), any(Pageable.class)))
                .thenReturn(List.of(sameInstantLater, selected, older));

        List<com.carevora.dto.metabolic.MetabolicTrendPoint> points = service.getTrend(1L, 5L, 8).getData();

        assertEquals(List.of(3L, 5L), points.stream().map(com.carevora.dto.metabolic.MetabolicTrendPoint::getId).toList());
        assertEquals(0.22, points.get(0).getOutcomes().get("diabetes").getProbability());
        assertEquals("low", points.get(1).getOutcomes().get("diabetes").getRiskTier());
        assertFalse(points.get(1).getOutcomes().containsKey("fatty_liver"));
    }

    @Test
    void trendRejectsAScreeningOfAnotherResident() {
        Resident other = Resident.builder().id(2L).build();
        when(residentRepository.findById(1L)).thenReturn(Optional.of(resident));
        when(metabolicAssessmentRepository.findById(9L))
                .thenReturn(Optional.of(MetabolicAssessment.builder().id(9L).resident(other).build()));
        assertThrows(ResourceNotFoundException.class, () -> service.getTrend(1L, 9L, 8));
        assertThrows(BadRequestException.class, () -> service.getTrend(1L, 9L, 1));
    }

    @Test
    void historyPageRejectsInvalidPaging() {
        assertThrows(BadRequestException.class, () -> service.getResidentAssessmentPage(1L, -1, 5));
        assertThrows(BadRequestException.class, () -> service.getResidentAssessmentPage(1L, 0, 0));
        assertThrows(BadRequestException.class, () -> service.getResidentAssessmentPage(1L, 0, 51));
        verifyNoInteractions(metabolicAssessmentRepository);
    }

    @Test
    void camelCaseFieldNamesMapToServiceInputNames() {
        assertEquals("waist_cm", MetabolicAssessmentService.toSnakeCase("waistCm"));
        assertEquals("on_bp_meds", MetabolicAssessmentService.toSnakeCase("onBpMeds"));
        assertEquals("hba1c", MetabolicAssessmentService.toSnakeCase("hba1c"));
        assertEquals("told_high_cholesterol", MetabolicAssessmentService.toSnakeCase("toldHighCholesterol"));
        assertEquals("vigorous_min_week", MetabolicAssessmentService.toSnakeCase("vigorousMinWeek"));
    }
}
