package com.carevora.service;

import com.carevora.dto.ApiResponse;
import com.carevora.dto.metabolic.MetabolicAssessmentRequest;
import com.carevora.dto.metabolic.MetabolicAssessmentResponse;
import com.carevora.dto.metabolic.MetabolicHistoryPageResponse;
import com.carevora.dto.metabolic.MetabolicTrendPoint;
import com.carevora.entity.Alert;
import com.carevora.entity.Caregiver;
import com.carevora.entity.MetabolicAssessment;
import com.carevora.entity.Resident;
import com.carevora.entity.User;
import com.carevora.enums.AlertPriority;
import com.carevora.enums.AlertType;
import com.carevora.enums.UserRole;
import com.carevora.exception.BadRequestException;
import com.carevora.exception.ResourceNotFoundException;
import com.carevora.repository.AlertRepository;
import com.carevora.repository.CaregiverRepository;
import com.carevora.repository.MetabolicAssessmentRepository;
import com.carevora.repository.ResidentRepository;
import com.carevora.repository.UserRepository;
import com.carevora.security.SecurityUtils;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Metabolic health risk screening (diabetes, cardiovascular disease, fatty liver).
 * Sends the resident's measurements to the AI service, stores the result and raises a
 * caregiver alert when any outcome lands in the "high" tier. Non-diagnostic.
 */
@Service
public class MetabolicAssessmentService {

    private static final Logger log = LoggerFactory.getLogger(MetabolicAssessmentService.class);
    static final int MAX_PAGE_SIZE = 50;
    private static final Map<String, String> OUTCOME_LABELS = Map.of(
            "diabetes", "diabetes",
            "cvd", "cardiovascular disease",
            "fatty_liver", "fatty liver");

    private final MetabolicAssessmentRepository metabolicAssessmentRepository;
    private final ResidentRepository residentRepository;
    private final UserRepository userRepository;
    private final CaregiverRepository caregiverRepository;
    private final AlertRepository alertRepository;
    private final AiMlService aiMlService;
    private final ObjectMapper objectMapper;

    public MetabolicAssessmentService(
            MetabolicAssessmentRepository metabolicAssessmentRepository,
            ResidentRepository residentRepository,
            UserRepository userRepository,
            CaregiverRepository caregiverRepository,
            AlertRepository alertRepository,
            AiMlService aiMlService,
            ObjectMapper objectMapper) {
        this.metabolicAssessmentRepository = metabolicAssessmentRepository;
        this.residentRepository = residentRepository;
        this.userRepository = userRepository;
        this.caregiverRepository = caregiverRepository;
        this.alertRepository = alertRepository;
        this.aiMlService = aiMlService;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public ApiResponse<MetabolicAssessmentResponse> submitAssessment(Long residentId, MetabolicAssessmentRequest request) {
        Resident resident = findResident(residentId);
        enforceResidentAccess(resident);

        if (request.getAge() == null && resident.getAge() != null) {
            request.setAge(resident.getAge().doubleValue());
        }
        Map<String, Object> inputs = toInputMap(request);
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("resident_id", residentId);
        inputs.forEach((key, value) -> payload.put(toSnakeCase(key), value));

        Map<String, Object> result = aiMlService.predictMetabolic(payload);
        result.remove("resident_id");

        MetabolicAssessment assessment = MetabolicAssessment.builder()
                .resident(resident)
                .assessedBy(SecurityUtils.getCurrentUserEmail().orElse("system"))
                .modelVersion(asString(result.get("model_version")))
                .inputsJson(writeJson(inputs))
                .resultJson(writeJson(result))
                .diabetesTier(outcomeValue(result, "diabetes", "risk_tier"))
                .diabetesProbability(outcomeProbability(result, "diabetes"))
                .cvdTier(outcomeValue(result, "cvd", "risk_tier"))
                .cvdProbability(outcomeProbability(result, "cvd"))
                .fattyLiverTier(outcomeValue(result, "fatty_liver", "risk_tier"))
                .fattyLiverProbability(outcomeProbability(result, "fatty_liver"))
                .build();
        MetabolicAssessment saved = metabolicAssessmentRepository.save(assessment);
        raiseAlertForHighTiers(resident, result);

        return ApiResponse.ok(toResponse(saved), "Metabolic risk screening completed");
    }

    @Transactional(readOnly = true)
    public ApiResponse<List<MetabolicAssessmentResponse>> getResidentAssessments(Long residentId) {
        Resident resident = findResident(residentId);
        enforceResidentAccess(resident);
        List<MetabolicAssessmentResponse> history = metabolicAssessmentRepository
                .findByResidentIdOrderByCreatedAtDesc(residentId).stream()
                .map(this::toResponse)
                .toList();
        return ApiResponse.ok(history, "Metabolic screening history retrieved");
    }

    @Transactional(readOnly = true)
    public ApiResponse<MetabolicHistoryPageResponse> getResidentAssessmentPage(Long residentId, int page, int size) {
        return getResidentAssessmentPage(residentId, page, size, null, null);
    }

    /** One page of history, optionally limited to screenings between {@code from} and {@code to} (inclusive days). */
    @Transactional(readOnly = true)
    public ApiResponse<MetabolicHistoryPageResponse> getResidentAssessmentPage(
            Long residentId, int page, int size, LocalDate from, LocalDate to) {
        if (from != null && to != null && from.isAfter(to)) {
            throw new BadRequestException("from date must be on or before to date");
        }
        if (page < 0) {
            throw new BadRequestException("page must be 0 or greater");
        }
        if (size < 1 || size > MAX_PAGE_SIZE) {
            throw new BadRequestException("size must be between 1 and " + MAX_PAGE_SIZE);
        }
        Resident resident = findResident(residentId);
        enforceResidentAccess(resident);
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("id")));
        Page<MetabolicAssessment> result = (from == null && to == null)
                ? metabolicAssessmentRepository.findByResidentId(residentId, pageRequest)
                : metabolicAssessmentRepository.findByResidentIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                        residentId,
                        (from != null ? from : LocalDate.of(1900, 1, 1)).atStartOfDay(),
                        (to != null ? to : LocalDate.of(9999, 12, 30)).plusDays(1).atStartOfDay(),
                        pageRequest);
        MetabolicHistoryPageResponse body = MetabolicHistoryPageResponse.builder()
                .items(result.getContent().stream().map(this::toResponse).toList())
                .page(result.getNumber())
                .size(result.getSize())
                .totalItems(result.getTotalElements())
                .totalPages(result.getTotalPages())
                .build();
        return ApiResponse.ok(body, "Metabolic screening history page retrieved");
    }

    /**
     * The resident's screenings up to and including {@code assessmentId}, oldest first, at most
     * {@code limit} of them: the data behind the small trend line on each result card.
     */
    @Transactional(readOnly = true)
    public ApiResponse<List<MetabolicTrendPoint>> getTrend(Long residentId, Long assessmentId, int limit) {
        if (limit < 2 || limit > MAX_PAGE_SIZE) {
            throw new BadRequestException("limit must be between 2 and " + MAX_PAGE_SIZE);
        }
        Resident resident = findResident(residentId);
        enforceResidentAccess(resident);
        MetabolicAssessment selected = metabolicAssessmentRepository.findById(assessmentId)
                .filter(a -> a.getResident() != null && residentId.equals(a.getResident().getId()))
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Metabolic screening " + assessmentId + " not found for resident " + residentId));

        List<MetabolicAssessment> upTo;
        if (selected.getCreatedAt() == null) {
            upTo = List.of(selected);
        } else {
            // Fetch a few extra: screenings saved in the same instant but after the selected one are dropped.
            upTo = metabolicAssessmentRepository.findByResidentIdAndCreatedAtLessThanEqual(residentId,
                    selected.getCreatedAt(),
                    PageRequest.of(0, limit + 5, Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("id"))));
        }
        List<MetabolicTrendPoint> points = new ArrayList<>(upTo.stream()
                .filter(a -> a.getCreatedAt() == null || !a.getCreatedAt().equals(selected.getCreatedAt())
                        || a.getId() <= selected.getId())
                .limit(limit)
                .map(this::toTrendPoint)
                .toList());
        Collections.reverse(points);
        return ApiResponse.ok(points, "Metabolic screening trend retrieved");
    }

    private MetabolicTrendPoint toTrendPoint(MetabolicAssessment a) {
        Map<String, MetabolicTrendPoint.OutcomePoint> outcomes = new LinkedHashMap<>();
        if (a.getDiabetesTier() != null) {
            outcomes.put("diabetes", new MetabolicTrendPoint.OutcomePoint(a.getDiabetesTier(), a.getDiabetesProbability()));
        }
        if (a.getCvdTier() != null) {
            outcomes.put("cvd", new MetabolicTrendPoint.OutcomePoint(a.getCvdTier(), a.getCvdProbability()));
        }
        if (a.getFattyLiverTier() != null) {
            outcomes.put("fatty_liver", new MetabolicTrendPoint.OutcomePoint(a.getFattyLiverTier(), a.getFattyLiverProbability()));
        }
        return MetabolicTrendPoint.builder().id(a.getId()).createdAt(a.getCreatedAt()).outcomes(outcomes).build();
    }

    @Transactional(readOnly = true)
    public ApiResponse<MetabolicAssessmentResponse> getLatestAssessment(Long residentId) {
        Resident resident = findResident(residentId);
        enforceResidentAccess(resident);
        MetabolicAssessment latest = metabolicAssessmentRepository.findFirstByResidentIdOrderByCreatedAtDesc(residentId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "No metabolic screening found for resident with id: " + residentId));
        return ApiResponse.ok(toResponse(latest), "Latest metabolic screening retrieved");
    }

    public ApiResponse<Map<String, Object>> getModelInfo() {
        return ApiResponse.ok(aiMlService.getMetabolicModelInfo(), "Metabolic model information retrieved");
    }

    // ------------------------------------------------------------------ helpers

    private Resident findResident(Long residentId) {
        return residentRepository.findById(residentId)
                .orElseThrow(() -> new ResourceNotFoundException("Resident not found with id: " + residentId));
    }

    private Map<String, Object> toInputMap(MetabolicAssessmentRequest request) {
        Map<String, Object> raw = objectMapper.convertValue(request, new TypeReference<Map<String, Object>>() {});
        Map<String, Object> inputs = new LinkedHashMap<>();
        raw.forEach((key, value) -> {
            if (value != null) {
                inputs.put(key, value);
            }
        });
        return inputs;
    }

    /** waistCm -> waist_cm, hba1c -> hba1c, onBpMeds -> on_bp_meds */
    static String toSnakeCase(String camel) {
        return camel.replaceAll("([a-z0-9])([A-Z])", "$1_$2").toLowerCase();
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> outcome(Map<String, Object> result, String name) {
        Object results = result.get("results");
        if (results instanceof Map<?, ?> map && map.get(name) instanceof Map<?, ?> o) {
            return (Map<String, Object>) o;
        }
        return Map.of();
    }

    private static String outcomeValue(Map<String, Object> result, String name, String key) {
        return asString(outcome(result, name).get(key));
    }

    private static Double outcomeProbability(Map<String, Object> result, String name) {
        Object p = outcome(result, name).get("probability");
        return p instanceof Number n ? n.doubleValue() : null;
    }

    private static String asString(Object value) {
        return value != null ? value.toString() : null;
    }

    private void raiseAlertForHighTiers(Resident resident, Map<String, Object> result) {
        List<String> high = new ArrayList<>();
        for (String name : List.of("diabetes", "cvd", "fatty_liver")) {
            if ("high".equals(outcomeValue(result, name, "risk_tier"))) {
                high.add(OUTCOME_LABELS.get(name));
            }
        }
        if (high.isEmpty() || alertRepository == null) {
            return;
        }
        String residentName = resident.getUser() != null
                ? resident.getUser().getFirstName() + " " + resident.getUser().getLastName()
                : "Resident " + resident.getId();
        Alert alert = Alert.builder()
                .resident(resident)
                .title("Metabolic screening: high risk tier")
                .message(residentName + " is in the high screening tier for " + String.join(", ", high)
                        + ". This is not a diagnosis; consider discussing with a doctor or nurse.")
                .type(AlertType.RISK_ALERT)
                .priority(AlertPriority.MEDIUM)
                .isRead(false)
                .build();
        alertRepository.save(alert);
        log.info("Metabolic high-tier alert raised for resident {} ({})", resident.getId(), high);
    }

    private MetabolicAssessmentResponse toResponse(MetabolicAssessment a) {
        Resident r = a.getResident();
        String name = r.getUser() != null ? r.getUser().getFirstName() + " " + r.getUser().getLastName() : null;
        return MetabolicAssessmentResponse.builder()
                .id(a.getId())
                .residentId(r.getId())
                .residentName(name)
                .assessedBy(a.getAssessedBy())
                .modelVersion(a.getModelVersion())
                .createdAt(a.getCreatedAt())
                .inputs(readJson(a.getInputsJson()))
                .result(readJson(a.getResultJson()))
                .build();
    }

    private String writeJson(Map<String, Object> value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Could not serialize metabolic assessment data", e);
        }
    }

    private Map<String, Object> readJson(String json) {
        try {
            return objectMapper.readValue(json, new TypeReference<Map<String, Object>>() {});
        } catch (JsonProcessingException e) {
            log.warn("Unreadable stored metabolic assessment JSON: {}", e.getMessage());
            return Map.of();
        }
    }

    /** Same rules as cognitive assessments: caregivers see their elder home, elders see themselves. */
    private void enforceResidentAccess(Resident resident) {
        Optional<User> currentUserOpt = SecurityUtils.getCurrentUser(userRepository);
        if (currentUserOpt.isEmpty()) {
            return; // Internal / system execution or test context without security context
        }
        User currentUser = currentUserOpt.get();
        UserRole role = currentUser.getRole();
        if (role == UserRole.CAREGIVER) {
            Optional<Caregiver> caregiverOpt = caregiverRepository.findByUserId(currentUser.getId());
            if (caregiverOpt.isEmpty() || caregiverOpt.get().getElderHome() == null ||
                    resident.getElderHome() == null ||
                    !resident.getElderHome().getId().equals(caregiverOpt.get().getElderHome().getId())) {
                throw new AccessDeniedException(
                        "Access denied: You can only view/assess residents belonging to your assigned Elder Home.");
            }
        } else if (role == UserRole.ELDER || role == UserRole.RESIDENT) {
            if (!resident.getUser().getId().equals(currentUser.getId())) {
                throw new AccessDeniedException(
                        "Access denied: Elders are not authorized to view other elders' records.");
            }
        }
    }
}
