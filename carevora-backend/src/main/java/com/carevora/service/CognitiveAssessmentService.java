package com.carevora.service;

import com.carevora.dto.ApiResponse;
import com.carevora.dto.cognitive.CognitiveAiResult;
import com.carevora.dto.cognitive.CognitiveAssessmentResponse;
import com.carevora.dto.cognitive.CognitiveAssessmentSubmissionRequest;
import com.carevora.dto.cognitive.CognitiveSessionResponse;
import com.carevora.dto.cognitive.SaveCognitiveResponsesRequest;
import com.carevora.dto.cognitive.StartCognitiveSessionRequest;
import com.carevora.entity.Alert;
import com.carevora.entity.Caregiver;
import com.carevora.entity.CognitiveAssessment;
import com.carevora.entity.CognitiveAssessmentSession;
import com.carevora.entity.Resident;
import com.carevora.entity.User;
import com.carevora.enums.AlertPriority;
import com.carevora.enums.AlertType;
import com.carevora.enums.UserRole;
import com.carevora.exception.BadRequestException;
import com.carevora.exception.ResourceNotFoundException;
import com.carevora.repository.AlertRepository;
import com.carevora.repository.CaregiverRepository;
import com.carevora.repository.CognitiveAssessmentRepository;
import com.carevora.repository.CognitiveAssessmentSessionRepository;
import com.carevora.repository.ResidentRepository;
import com.carevora.repository.UserRepository;
import com.carevora.security.SecurityUtils;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Service
public class CognitiveAssessmentService {

    private static final Logger log = LoggerFactory.getLogger(CognitiveAssessmentService.class);

    private final CognitiveAssessmentRepository cognitiveAssessmentRepository;
    private final ResidentRepository residentRepository;
    private final UserRepository userRepository;
    private final CaregiverRepository caregiverRepository;
    private final AiMlService aiMlService;
    private final ObjectMapper objectMapper;
    private CognitiveAssessmentSessionRepository cognitiveAssessmentSessionRepository;
    private AlertRepository alertRepository;

    public CognitiveAssessmentService(
            CognitiveAssessmentRepository cognitiveAssessmentRepository,
            ResidentRepository residentRepository,
            UserRepository userRepository,
            CaregiverRepository caregiverRepository,
            AiMlService aiMlService,
            ObjectMapper objectMapper) {
        this.cognitiveAssessmentRepository = cognitiveAssessmentRepository;
        this.residentRepository = residentRepository;
        this.userRepository = userRepository;
        this.caregiverRepository = caregiverRepository;
        this.aiMlService = aiMlService;
        this.objectMapper = objectMapper;
    }

    @Autowired(required = false)
    public void setCognitiveAssessmentSessionRepository(
            CognitiveAssessmentSessionRepository cognitiveAssessmentSessionRepository) {
        this.cognitiveAssessmentSessionRepository = cognitiveAssessmentSessionRepository;
    }

    @Autowired(required = false)
    public void setAlertRepository(AlertRepository alertRepository) {
        this.alertRepository = alertRepository;
    }

    // Fixed ACRF Base Weights established in system specifications
    private static final Map<String, Double> ACRF_WEIGHTS = Map.of(
            "memory", 0.25,
            "attention", 0.20,
            "orientation", 0.20,
            "recall", 0.20,
            "reasoning", 0.15);

    @Transactional
    public ApiResponse<CognitiveSessionResponse> startSession(StartCognitiveSessionRequest request) {
        if (request == null || request.getResidentId() == null) {
            throw new BadRequestException("Resident ID is required to start a cognitive session");
        }

        Resident resident = residentRepository.findById(request.getResidentId())
                .orElseThrow(
                        () -> new ResourceNotFoundException("Resident not found with id: " + request.getResidentId()));

        enforceResidentAccess(resident);

        String currentUserName = SecurityUtils.getCurrentUser(userRepository)
                .map(User::getFullName)
                .orElse("Care Specialist");

        String sessionId = "cog-sess-" + UUID.randomUUID().toString();

        CognitiveAssessmentSession session = CognitiveAssessmentSession.builder()
                .sessionId(sessionId)
                .resident(resident)
                .status("IN_PROGRESS")
                .initiatedBy(currentUserName)
                .build();

        if (cognitiveAssessmentSessionRepository != null) {
            session = cognitiveAssessmentSessionRepository.save(session);
        }

        return ApiResponse.ok(mapToSessionResponse(session), "Cognitive assessment session initiated successfully");
    }

    @Transactional
    public ApiResponse<CognitiveSessionResponse> saveResponses(String sessionId,
            SaveCognitiveResponsesRequest request) {
        if (sessionId == null || sessionId.isBlank()) {
            throw new BadRequestException("Session ID is required");
        }

        CognitiveAssessmentSession session = null;
        if (cognitiveAssessmentSessionRepository != null) {
            session = cognitiveAssessmentSessionRepository.findBySessionId(sessionId)
                    .orElseThrow(
                            () -> new ResourceNotFoundException("Assessment session not found with id: " + sessionId));
        } else {
            throw new ResourceNotFoundException("Session persistence repository is unavailable");
        }

        enforceResidentAccess(session.getResident());

        if ("COMPLETED".equalsIgnoreCase(session.getStatus())
                || "COMPLETED_PREDICTION_UNAVAILABLE".equalsIgnoreCase(session.getStatus())) {
            throw new BadRequestException(
                    "Assessment session " + sessionId + " has already been completed and cannot be modified.");
        }

        if (request.getResponses() != null && !request.getResponses().isEmpty()) {
            try {
                session.setResponsesJson(objectMapper.writeValueAsString(request.getResponses()));
                Map<Integer, Double> autoGrades = CognitiveScoringService.scoreBattery(request.getResponses(),
                        LocalDate.now());
                if (!autoGrades.isEmpty()) {
                    session.setGradesJson(objectMapper.writeValueAsString(autoGrades));
                }
            } catch (Exception e) {
                throw new BadRequestException("Failed to serialize resident responses");
            }
        }

        if (request.getQuestionTimes() != null && !request.getQuestionTimes().isEmpty()) {
            try {
                session.setQuestionTimesJson(objectMapper.writeValueAsString(request.getQuestionTimes()));
            } catch (Exception e) {
                throw new BadRequestException("Failed to serialize question durations");
            }
        }

        if (request.getStatus() != null && !request.getStatus().isBlank()) {
            session.setStatus(request.getStatus());
        } else {
            session.setStatus("PENDING_CAREGIVER_REVIEW");
        }
        CognitiveAssessmentSession updated = cognitiveAssessmentSessionRepository.save(session);

        return ApiResponse.ok(mapToSessionResponse(updated), "Resident responses saved successfully");
    }

    @Transactional(readOnly = true)
    public ApiResponse<CognitiveSessionResponse> getPendingSession(Long residentId) {
        Resident resident = residentRepository.findById(residentId)
                .orElseThrow(() -> new ResourceNotFoundException("Resident not found with id: " + residentId));

        enforceResidentAccess(resident);

        if (cognitiveAssessmentSessionRepository == null) {
            return ApiResponse.ok(null, "No pending cognitive assessment session found for resident");
        }

        Optional<CognitiveAssessmentSession> pendingSession = cognitiveAssessmentSessionRepository
                .findFirstByResidentIdAndStatusOrderByCreatedAtDesc(residentId, "PENDING_CAREGIVER_REVIEW");

        if (pendingSession.isEmpty()) {
            pendingSession = cognitiveAssessmentSessionRepository
                    .findFirstByResidentIdAndStatusOrderByCreatedAtDesc(residentId, "IN_PROGRESS");
        }

        if (pendingSession.isEmpty()) {
            return ApiResponse.ok(null, "No pending cognitive assessment session found for resident");
        }

        return ApiResponse.ok(mapToSessionResponse(pendingSession.get()),
                "Pending cognitive assessment session retrieved successfully");
    }

    @Transactional
    public ApiResponse<CognitiveAssessmentResponse> submitAssessment(CognitiveAssessmentSubmissionRequest request) {
        // Automatic grading and domain calculation when responses are provided
        if (request.getResponses() != null && !request.getResponses().isEmpty()) {
            List<Integer> unanswered = CognitiveScoringService.getUnansweredQuestionIds(request.getResponses());
            if (!unanswered.isEmpty()) {
                throw new BadRequestException("Cannot finalize assessment: Question(s) " + unanswered
                        + " must be answered before finalization. Missing responses cannot be evaluated.");
            }

            Map<Integer, Double> autoGrades = CognitiveScoringService.scoreBattery(request.getResponses(),
                    LocalDate.now());
            if (request.getGrades() == null || request.getGrades().isEmpty()) {
                request.setGrades(autoGrades);
            } else {
                // Ensure Sinhala answers are properly scored if prior auto-grades had 0.0
                Map<Integer, Double> mergedGrades = new HashMap<>(request.getGrades());
                for (Map.Entry<Integer, Double> entry : autoGrades.entrySet()) {
                    Double existing = mergedGrades.get(entry.getKey());
                    if (existing == null || (existing == 0.0 && entry.getValue() != null && entry.getValue() > 0.0)) {
                        mergedGrades.put(entry.getKey(), entry.getValue());
                    }
                }
                request.setGrades(mergedGrades);
            }

            Map<String, Double> accs = CognitiveScoringService.calculateDomainAccuracies(request.getGrades());
            Map<String, Double> taskScores = CognitiveScoringService.calculateDomainScores(accs);

            if (request.getMemory() == null)
                request.setMemory(taskScores.get("memory"));
            if (request.getAttention() == null)
                request.setAttention(taskScores.get("attention"));
            if (request.getOrientation() == null)
                request.setOrientation(taskScores.get("orientation"));
            if (request.getRecall() == null)
                request.setRecall(taskScores.get("recall"));
            if (request.getReasoning() == null)
                request.setReasoning(taskScores.get("reasoning"));
            if (request.getAccuracies() == null || request.getAccuracies().isEmpty()) {
                request.setAccuracies(accs);
            }
        }

        validateCategoryScores(request);
        validateOptionalMlFeatures(request);

        Resident resident = residentRepository.findById(request.getResidentId())
                .orElseThrow(
                        () -> new ResourceNotFoundException("Resident not found with id: " + request.getResidentId()));

        enforceResidentAccess(resident);

        CognitiveAssessmentSession session = null;
        if (request.getSessionId() != null && !request.getSessionId().isBlank()) {
            if (cognitiveAssessmentRepository != null
                    && cognitiveAssessmentRepository.existsBySessionId(request.getSessionId())) {
                throw new BadRequestException("Duplicate submission detected: Assessment session "
                        + request.getSessionId() + " has already been finalized.");
            }
            if (cognitiveAssessmentSessionRepository != null) {
                session = cognitiveAssessmentSessionRepository.findBySessionId(request.getSessionId()).orElse(null);
                if (session != null) {
                    if ("COMPLETED".equalsIgnoreCase(session.getStatus())
                            || "COMPLETED_PREDICTION_UNAVAILABLE".equalsIgnoreCase(session.getStatus())) {
                        throw new BadRequestException("Duplicate submission detected: Assessment session "
                                + request.getSessionId() + " has already been completed.");
                    }
                    if (!session.getResident().getId().equals(resident.getId())) {
                        throw new BadRequestException("Session " + request.getSessionId()
                                + " does not belong to resident " + resident.getId());
                    }
                    if ((request.getResponses() == null || request.getResponses().isEmpty())
                            && session.getResponsesJson() != null && !session.getResponsesJson().isBlank()) {
                        try {
                            Map<Integer, String> parsed = objectMapper.readValue(session.getResponsesJson(),
                                    new TypeReference<Map<Integer, String>>() {
                                    });
                            request.setResponses(parsed);
                        } catch (Exception ignored) {
                        }
                    }
                }
            }
        }

        if ((request.getResponseTimes() == null || request.getResponseTimes().isEmpty()) && session != null
                && session.getQuestionTimesJson() != null) {
            try {
                Map<Integer, Double> parsedTimes = objectMapper.readValue(session.getQuestionTimesJson(),
                        new TypeReference<Map<Integer, Double>>() {
                        });
                Map<String, Double> aggTimes = CognitiveScoringService.aggregateDomainResponseTimes(parsedTimes);
                request.setResponseTimes(aggTimes);
            } catch (Exception ignored) {
            }
        }

        // Determine effective demographics without inventing or synthesizing missing
        // values
        Integer effectiveAge = request.getAge() != null ? request.getAge() : resident.getAge();
        Integer effectiveEducationYears = request.getEducationYears() != null ? request.getEducationYears()
                : resident.getEducationYears();

        if (request.getEducationYears() != null && resident.getEducationYears() == null) {
            resident.setEducationYears(request.getEducationYears());
        }
        if (request.getAge() != null && resident.getAge() == null) {
            resident.setAge(request.getAge());
        }

        // Call FastAPI AI Microservice for ACRF scoring and ML model inference
        CognitiveAiResult aiResult;
        try {
            aiResult = aiMlService.predictCognitive(
                    resident.getId(),
                    request.getMemory(),
                    request.getAttention(),
                    request.getOrientation(),
                    request.getRecall(),
                    request.getReasoning(),
                    effectiveAge,
                    effectiveEducationYears,
                    request.getAccuracies(),
                    request.getResponseTimes());
        } catch (Exception ex) {
            log.warn(
                    "AI microservice call failed during cognitive assessment submission: {}. Falling back to authoritative local scoring without ML risk prediction.",
                    ex.getMessage());
            aiResult = buildFallbackAiResult(
                    request.getMemory(),
                    request.getAttention(),
                    request.getOrientation(),
                    request.getRecall(),
                    request.getReasoning(),
                    "AI microservice unavailable: " + ex.getMessage());
        }

        String currentUserName = SecurityUtils.getCurrentUser(userRepository)
                .map(User::getFullName)
                .orElse("Care Specialist");

        CognitiveAssessmentResponse.MlModelStatusDto mlEval = aiResult.getMlModelEvaluation();
        boolean mlAvailable = mlEval != null && mlEval.isAvailable();
        String mlPrediction = mlAvailable && mlEval.getPrediction() != null
                ? String.valueOf(mlEval.getPrediction())
                : null;
        String resolvedRisk = resolveRiskLevel(mlPrediction, aiResult.getAcrfScore());
        boolean isHighRisk = (mlAvailable && Boolean.TRUE.equals(mlEval.getAlertTriggered()))
                || (aiResult.getAcrfScore() != null && aiResult.getAcrfScore() < 50.0)
                || "High".equalsIgnoreCase(mlPrediction)
                || "High Risk".equalsIgnoreCase(resolvedRisk);
        Boolean alertTriggered = isHighRisk;
        String finalStatus = mlAvailable ? "COMPLETED" : "COMPLETED_PREDICTION_UNAVAILABLE";

        Double highRiskProb = null;
        String classProbsJson = null;
        if (mlAvailable && mlEval.getProbabilities() != null) {
            highRiskProb = mlEval.getProbabilities().get("High");
            try {
                classProbsJson = objectMapper.writeValueAsString(mlEval.getProbabilities());
            } catch (Exception ignored) {
            }
        }

        String responsesJson = null;
        if (request.getResponses() != null && !request.getResponses().isEmpty()) {
            try {
                responsesJson = objectMapper.writeValueAsString(request.getResponses());
            } catch (Exception ignored) {
            }
        } else if (session != null && session.getResponsesJson() != null) {
            responsesJson = session.getResponsesJson();
        }

        String gradesJson = null;
        if (request.getGrades() != null && !request.getGrades().isEmpty()) {
            try {
                gradesJson = objectMapper.writeValueAsString(request.getGrades());
            } catch (Exception ignored) {
            }
        }

        String accuraciesJson = null;
        if (request.getAccuracies() != null && !request.getAccuracies().isEmpty()) {
            try {
                accuraciesJson = objectMapper.writeValueAsString(request.getAccuracies());
            } catch (Exception ignored) {
            }
        }

        String responseTimesJson = null;
        if (request.getResponseTimes() != null && !request.getResponseTimes().isEmpty()) {
            try {
                responseTimesJson = objectMapper.writeValueAsString(request.getResponseTimes());
            } catch (Exception ignored) {
            }
        }

        String effectiveSessionId = request.getSessionId() != null && !request.getSessionId().isBlank()
                ? request.getSessionId()
                : (session != null ? session.getSessionId() : "cog-sess-" + UUID.randomUUID().toString());

        CognitiveAssessment entity = CognitiveAssessment.builder()
                .resident(resident)
                .sessionId(effectiveSessionId)
                .status(finalStatus)
                .responsesJson(responsesJson)
                .gradesJson(gradesJson)
                .accuraciesJson(accuraciesJson)
                .responseTimesJson(responseTimesJson)
                .memoryScore(request.getMemory())
                .attentionScore(request.getAttention())
                .orientationScore(request.getOrientation())
                .recallScore(request.getRecall())
                .reasoningScore(request.getReasoning())
                .acrfScore(aiResult.getAcrfScore())
                .assessedBy(currentUserName)
                .mlAvailable(mlAvailable)
                .mlPrediction(mlPrediction)
                .alertTriggered(alertTriggered)
                .highRiskProbability(highRiskProb)
                .classProbabilities(classProbsJson)
                .build();

        CognitiveAssessment saved = cognitiveAssessmentRepository.save(entity);

        if (session != null && cognitiveAssessmentSessionRepository != null) {
            session.setStatus(finalStatus);
            if (gradesJson != null) {
                session.setGradesJson(gradesJson);
            }
            session.setReviewedBy(currentUserName);
            cognitiveAssessmentSessionRepository.save(session);
        }

        // Update Resident current cognitive snapshot (without modifying emotional or
        // social scores)
        resident.setCognitiveScore(aiResult.getAcrfScore());
        resident.setLastAssessmentDate(LocalDateTime.now());
        residentRepository.save(resident);

        if (isHighRisk && alertRepository != null) {
            String resName = (resident.getUser() != null && resident.getUser().getFullName() != null)
                    ? resident.getUser().getFullName()
                    : "Resident";
            String room = resident.getRoomNumber() != null ? resident.getRoomNumber() : "105";
            double score = aiResult.getAcrfScore() != null ? aiResult.getAcrfScore() : 0.0;

            String alertTitle = "High Cognitive Impairment Risk: " + resName;
            String alertMessage = String.format(
                    "Cognitive assessment score (%.1f/100) indicates acute cognitive decline risk for %s in room %s. Urgent caregiver review and clinical attention required.",
                    score, resName, room);

            Alert cognitiveAlert = Alert.builder()
                    .resident(resident)
                    .title(alertTitle)
                    .message(alertMessage)
                    .type(AlertType.RISK_ALERT)
                    .priority(AlertPriority.HIGH)
                    .isRead(false)
                    .build();
            alertRepository.save(cognitiveAlert);
            log.info("Persisted high cognitive risk alert in AlertRepository for resident: {} (ID: {}) with score: {}",
                    resName, resident.getId(), score);
        }

        CognitiveAssessmentResponse response = mapToResponse(saved, aiResult, request.getResponses(),
                request.getGrades(), request.getAccuracies(), request.getResponseTimes());
        return ApiResponse.ok(response, "Cognitive assessment evaluated and saved successfully");
    }

    @Transactional(readOnly = true)
    public ApiResponse<List<CognitiveAssessmentResponse>> getResidentCognitiveAssessments(Long residentId) {
        Resident resident = residentRepository.findById(residentId)
                .orElseThrow(() -> new ResourceNotFoundException("Resident not found with id: " + residentId));

        enforceResidentAccess(resident);

        List<CognitiveAssessment> history = cognitiveAssessmentRepository
                .findByResidentIdOrderByCreatedAtDesc(residentId);
        List<CognitiveAssessmentResponse> responses = history.stream()
                .map(this::mapHistoryToResponse)
                .collect(Collectors.toList());

        // Include any active sessions that have not yet been completed into history
        if (cognitiveAssessmentSessionRepository != null) {
            List<CognitiveAssessmentSession> sessions = cognitiveAssessmentSessionRepository
                    .findByResidentIdOrderByCreatedAtDesc(residentId);
            java.util.Set<String> completedSessionIds = history.stream()
                    .map(CognitiveAssessment::getSessionId)
                    .filter(java.util.Objects::nonNull)
                    .collect(Collectors.toSet());

            for (CognitiveAssessmentSession sess : sessions) {
                if (sess.getSessionId() != null &&
                        !completedSessionIds.contains(sess.getSessionId()) &&
                        !"COMPLETED".equalsIgnoreCase(sess.getStatus()) &&
                        !"COMPLETED_PREDICTION_UNAVAILABLE".equalsIgnoreCase(sess.getStatus())) {
                    responses.add(mapSessionToAssessmentResponse(sess));
                }
            }

            // Sort combined newest first by createdAt DESC
            responses.sort((a, b) -> {
                if (a.getCreatedAt() == null && b.getCreatedAt() == null)
                    return 0;
                if (a.getCreatedAt() == null)
                    return 1;
                if (b.getCreatedAt() == null)
                    return -1;
                return b.getCreatedAt().compareTo(a.getCreatedAt());
            });
        }

        return ApiResponse.ok(responses, "Resident cognitive assessment history retrieved successfully");
    }

    private void validateCategoryScores(CognitiveAssessmentSubmissionRequest req) {
        validateFiniteNumber(req.getMemory(), "Memory");
        validateFiniteNumber(req.getAttention(), "Attention");
        validateFiniteNumber(req.getOrientation(), "Orientation");
        validateFiniteNumber(req.getRecall(), "Recall");
        validateFiniteNumber(req.getReasoning(), "Reasoning");
    }

    private void validateOptionalMlFeatures(CognitiveAssessmentSubmissionRequest req) {
        if (req.getEducationYears() != null) {
            if (req.getEducationYears() < 0 || req.getEducationYears() > 40) {
                throw new BadRequestException("Education years must be between 0 and 40");
            }
        }
        if (req.getAge() != null) {
            if (req.getAge() <= 0 || req.getAge() > 130) {
                throw new BadRequestException("Age must be between 1 and 130");
            }
        }
        if (req.getAccuracies() != null) {
            for (Map.Entry<String, Double> entry : req.getAccuracies().entrySet()) {
                Double acc = entry.getValue();
                if (acc != null) {
                    if (Double.isNaN(acc) || Double.isInfinite(acc) || acc < 0.0 || acc > 100.0) {
                        throw new BadRequestException(
                                "Accuracy for '" + entry.getKey() + "' must be a finite number in range [0.0, 100.0]");
                    }
                }
            }
        }
        if (req.getResponseTimes() != null) {
            for (Map.Entry<String, Double> entry : req.getResponseTimes().entrySet()) {
                Double rt = entry.getValue();
                if (rt != null) {
                    if (Double.isNaN(rt) || Double.isInfinite(rt) || rt <= 0.0) {
                        throw new BadRequestException(
                                "Response time for '" + entry.getKey() + "' must be a finite number > 0.0 seconds");
                    }
                }
            }
        }
    }

    private void validateFiniteNumber(Double val, String fieldName) {
        if (val == null) {
            throw new BadRequestException(fieldName + " score is required");
        }
        if (Double.isNaN(val) || Double.isInfinite(val)) {
            throw new BadRequestException(fieldName + " score cannot be NaN or infinite");
        }
        if (val < 0.0 || val > 100.0) {
            throw new BadRequestException(fieldName + " score must be within range [0.0, 100.0]");
        }
    }

    private void enforceResidentAccess(Resident resident) {
        Optional<User> currentUserOpt = SecurityUtils.getCurrentUser(userRepository);
        if (currentUserOpt.isEmpty()) {
            return; // Internal / system execution or test context without security context
        }

        User currentUser = currentUserOpt.get();
        UserRole role = currentUser.getRole();

        // 1. Caregiver can only access residents in their assigned Elder Home
        if (role == UserRole.CAREGIVER) {
            Optional<Caregiver> caregiverOpt = caregiverRepository.findByUserId(currentUser.getId());
            if (caregiverOpt.isEmpty() || caregiverOpt.get().getElderHome() == null ||
                    resident.getElderHome() == null ||
                    !resident.getElderHome().getId().equals(caregiverOpt.get().getElderHome().getId())) {
                throw new AccessDeniedException(
                        "Access denied: You can only view/assess residents belonging to your assigned Elder Home.");
            }
        }
        // 2. Elder can only access their own assessments
        else if (role == UserRole.ELDER || role == UserRole.RESIDENT) {
            if (!resident.getUser().getId().equals(currentUser.getId())) {
                throw new AccessDeniedException(
                        "Access denied: Elders are not authorized to view other elders' records.");
            }
        }
        // 3. DOCTOR and ADMIN have full cross-facility authorization
    }

    private CognitiveSessionResponse mapToSessionResponse(CognitiveAssessmentSession s) {
        Map<Integer, String> parsedResponses = null;
        if (s.getResponsesJson() != null && !s.getResponsesJson().isBlank()) {
            try {
                parsedResponses = objectMapper.readValue(
                        s.getResponsesJson(),
                        new TypeReference<Map<Integer, String>>() {
                        });
            } catch (Exception ignored) {
            }
        }

        Map<Integer, Double> parsedGrades = null;
        if (s.getGradesJson() != null && !s.getGradesJson().isBlank()) {
            try {
                parsedGrades = objectMapper.readValue(
                        s.getGradesJson(),
                        new TypeReference<Map<Integer, Double>>() {
                        });
            } catch (Exception ignored) {
            }
        }

        Map<Integer, Double> parsedTimes = null;
        if (s.getQuestionTimesJson() != null && !s.getQuestionTimesJson().isBlank()) {
            try {
                parsedTimes = objectMapper.readValue(
                        s.getQuestionTimesJson(),
                        new TypeReference<Map<Integer, Double>>() {
                        });
            } catch (Exception ignored) {
            }
        }

        return CognitiveSessionResponse.builder()
                .sessionId(s.getSessionId())
                .residentId(s.getResident().getId())
                .residentName(s.getResident().getUser().getFullName())
                .status(s.getStatus())
                .responses(parsedResponses)
                .grades(parsedGrades)
                .questionTimes(parsedTimes)
                .initiatedBy(s.getInitiatedBy())
                .reviewedBy(s.getReviewedBy())
                .createdAt(s.getCreatedAt())
                .updatedAt(s.getUpdatedAt())
                .build();
    }

    private CognitiveAssessmentResponse mapToResponse(
            CognitiveAssessment saved,
            CognitiveAiResult aiResult,
            Map<Integer, String> reqResponses,
            Map<Integer, Double> reqGrades,
            Map<String, Double> reqAccuracies,
            Map<String, Double> reqResponseTimes) {

        Map<Integer, String> parsedResponses = reqResponses;
        if (parsedResponses == null && saved.getResponsesJson() != null && !saved.getResponsesJson().isBlank()) {
            try {
                parsedResponses = objectMapper.readValue(saved.getResponsesJson(),
                        new TypeReference<Map<Integer, String>>() {
                        });
            } catch (Exception ignored) {
            }
        }

        Map<Integer, Double> parsedGrades = reqGrades;
        if (parsedGrades == null && saved.getGradesJson() != null && !saved.getGradesJson().isBlank()) {
            try {
                parsedGrades = objectMapper.readValue(saved.getGradesJson(), new TypeReference<Map<Integer, Double>>() {
                });
            } catch (Exception ignored) {
            }
        }

        Map<String, Double> parsedAccuracies = reqAccuracies;
        if (parsedAccuracies == null && saved.getAccuraciesJson() != null && !saved.getAccuraciesJson().isBlank()) {
            try {
                parsedAccuracies = objectMapper.readValue(saved.getAccuraciesJson(),
                        new TypeReference<Map<String, Double>>() {
                        });
            } catch (Exception ignored) {
            }
        }

        Map<String, Double> parsedTimes = reqResponseTimes;
        if (parsedTimes == null && saved.getResponseTimesJson() != null && !saved.getResponseTimesJson().isBlank()) {
            try {
                parsedTimes = objectMapper.readValue(saved.getResponseTimesJson(),
                        new TypeReference<Map<String, Double>>() {
                        });
            } catch (Exception ignored) {
            }
        }

        return CognitiveAssessmentResponse.builder()
                .id(saved.getId())
                .residentId(saved.getResident().getId())
                .residentName(saved.getResident().getUser().getFullName())
                .memory(saved.getMemoryScore())
                .attention(saved.getAttentionScore())
                .orientation(saved.getOrientationScore())
                .recall(saved.getRecallScore())
                .reasoning(saved.getReasoningScore())
                .acrfScore(aiResult.getAcrfScore())
                .mlPrediction(saved.getMlPrediction())
                .riskLevel(resolveRiskLevel(saved.getMlPrediction(), aiResult.getAcrfScore()))
                .alertTriggered(saved.getAlertTriggered())
                .categoryContributions(aiResult.getCategoryContributions())
                .weightsApplied(aiResult.getWeightsApplied())
                .mlModelEvaluation(aiResult.getMlModelEvaluation())
                .methodology(aiResult.getMethodology())
                .clinicalDisclaimer(aiResult.getClinicalDisclaimer())
                .assessedBy(saved.getAssessedBy())
                .createdAt(saved.getCreatedAt())
                .sessionId(saved.getSessionId())
                .status(saved.getStatus() != null ? saved.getStatus() : "COMPLETED")
                .responses(parsedResponses)
                .grades(parsedGrades)
                .accuracies(parsedAccuracies)
                .responseTimes(parsedTimes)
                .build();
    }

    private CognitiveAssessmentResponse mapHistoryToResponse(CognitiveAssessment c) {
        List<CognitiveAssessmentResponse.CategoryContributionDto> contributions = new ArrayList<>();
        contributions.add(createContrib("memory", c.getMemoryScore(), 0.25));
        contributions.add(createContrib("attention", c.getAttentionScore(), 0.20));
        contributions.add(createContrib("orientation", c.getOrientationScore(), 0.20));
        contributions.add(createContrib("recall", c.getRecallScore(), 0.20));
        contributions.add(createContrib("reasoning", c.getReasoningScore(), 0.15));

        Map<String, Double> parsedProbs = null;
        if (c.getClassProbabilities() != null && !c.getClassProbabilities().isBlank()) {
            try {
                parsedProbs = objectMapper.readValue(
                        c.getClassProbabilities(),
                        new TypeReference<Map<String, Double>>() {
                        });
            } catch (Exception ignored) {
            }
        }

        Map<Integer, String> parsedResponses = null;
        if (c.getResponsesJson() != null && !c.getResponsesJson().isBlank()) {
            try {
                parsedResponses = objectMapper.readValue(c.getResponsesJson(),
                        new TypeReference<Map<Integer, String>>() {
                        });
            } catch (Exception ignored) {
            }
        }

        Map<Integer, Double> parsedGrades = null;
        if (c.getGradesJson() != null && !c.getGradesJson().isBlank()) {
            try {
                parsedGrades = objectMapper.readValue(c.getGradesJson(), new TypeReference<Map<Integer, Double>>() {
                });
            } catch (Exception ignored) {
            }
        }

        Map<String, Double> parsedAccuracies = null;
        if (c.getAccuraciesJson() != null && !c.getAccuraciesJson().isBlank()) {
            try {
                parsedAccuracies = objectMapper.readValue(c.getAccuraciesJson(),
                        new TypeReference<Map<String, Double>>() {
                        });
            } catch (Exception ignored) {
            }
        }

        Map<String, Double> parsedTimes = null;
        if (c.getResponseTimesJson() != null && !c.getResponseTimesJson().isBlank()) {
            try {
                parsedTimes = objectMapper.readValue(c.getResponseTimesJson(),
                        new TypeReference<Map<String, Double>>() {
                        });
            } catch (Exception ignored) {
            }
        }

        boolean mlAvailable = Boolean.TRUE.equals(c.getMlAvailable());
        CognitiveAssessmentResponse.MlModelStatusDto mlStatus;
        if (mlAvailable) {
            mlStatus = CognitiveAssessmentResponse.MlModelStatusDto.builder()
                    .available(true)
                    .modelType("RandomForestClassifier")
                    .statusMessage(
                            "Experimental prediction generated using artifact trained on synthetic data. Non-clinical demonstration metric.")
                    .prediction(c.getMlPrediction())
                    .probabilities(parsedProbs)
                    .alertTriggered(c.getAlertTriggered())
                    .alertThreshold(0.48)
                    .experimentalLabel("Synthetic Data Experiment (Non-Clinical)")
                    .build();
        } else {
            String missingMsg;
            if (c.getResident() != null && c.getResident().getEducationYears() == null) {
                missingMsg = "Random Forest model inference was unavailable (missing resident education years at assessment time)";
            } else if (c.getResident() != null && c.getResident().getAge() == null) {
                missingMsg = "Random Forest model inference was unavailable (missing resident age at assessment time)";
            } else if (c.getAccuraciesJson() == null || c.getAccuraciesJson().isBlank()) {
                missingMsg = "Random Forest model inference was unavailable (missing domain accuracy metrics at assessment time)";
            } else if (c.getResponseTimesJson() == null || c.getResponseTimesJson().isBlank()) {
                missingMsg = "Random Forest model inference was unavailable (missing domain response times at assessment time)";
            } else {
                missingMsg = "Random Forest model inference was unavailable (missing required task metrics at assessment time)";
            }
            mlStatus = CognitiveAssessmentResponse.MlModelStatusDto.builder()
                    .available(false)
                    .modelType("RandomForestClassifier")
                    .statusMessage(missingMsg)
                    .prediction(null)
                    .probabilities(null)
                    .alertTriggered(false)
                    .alertThreshold(0.48)
                    .experimentalLabel("Synthetic Data Experiment (Non-Clinical)")
                    .build();
        }

        return CognitiveAssessmentResponse.builder()
                .id(c.getId())
                .residentId(c.getResident().getId())
                .residentName(c.getResident().getUser().getFullName())
                .memory(c.getMemoryScore())
                .attention(c.getAttentionScore())
                .orientation(c.getOrientationScore())
                .recall(c.getRecallScore())
                .reasoning(c.getReasoningScore())
                .acrfScore(c.getAcrfScore())
                .mlPrediction(c.getMlPrediction())
                .riskLevel(resolveRiskLevel(c.getMlPrediction(), c.getAcrfScore()))
                .alertTriggered(c.getAlertTriggered())
                .categoryContributions(contributions)
                .weightsApplied(ACRF_WEIGHTS)
                .mlModelEvaluation(mlStatus)
                .methodology("ACRF Fixed Base Weights")
                .clinicalDisclaimer("The ACRF score is an arithmetic weighted wellness metric. Non-diagnostic.")
                .assessedBy(c.getAssessedBy())
                .createdAt(c.getCreatedAt())
                .sessionId(c.getSessionId())
                .status(c.getStatus() != null ? c.getStatus()
                        : (Boolean.TRUE.equals(c.getMlAvailable()) ? "COMPLETED" : "COMPLETED_PREDICTION_UNAVAILABLE"))
                .responses(parsedResponses)
                .grades(parsedGrades)
                .accuracies(parsedAccuracies)
                .responseTimes(parsedTimes)
                .build();
    }

    private CognitiveAssessmentResponse mapSessionToAssessmentResponse(CognitiveAssessmentSession s) {
        Map<Integer, String> parsedResponses = null;
        if (s.getResponsesJson() != null && !s.getResponsesJson().isBlank()) {
            try {
                parsedResponses = objectMapper.readValue(s.getResponsesJson(),
                        new TypeReference<Map<Integer, String>>() {
                        });
            } catch (Exception ignored) {
            }
        }

        Map<Integer, Double> parsedGrades = null;
        if (s.getGradesJson() != null && !s.getGradesJson().isBlank()) {
            try {
                parsedGrades = objectMapper.readValue(s.getGradesJson(), new TypeReference<Map<Integer, Double>>() {
                });
            } catch (Exception ignored) {
            }
        }

        Map<String, Double> parsedTimes = null;
        if (s.getQuestionTimesJson() != null && !s.getQuestionTimesJson().isBlank()) {
            try {
                Map<Integer, Double> intTimes = objectMapper.readValue(s.getQuestionTimesJson(),
                        new TypeReference<Map<Integer, Double>>() {
                        });
                if (intTimes != null) {
                    parsedTimes = new HashMap<>();
                    for (Map.Entry<Integer, Double> entry : intTimes.entrySet()) {
                        parsedTimes.put("Q" + entry.getKey(), entry.getValue());
                    }
                }
            } catch (Exception ignored) {
            }
        }

        CognitiveAssessmentResponse.MlModelStatusDto mlStatus = CognitiveAssessmentResponse.MlModelStatusDto.builder()
                .available(false)
                .modelType("RandomForestClassifier")
                .statusMessage("Pending clinical review: AI inference will be evaluated upon caregiver completion.")
                .prediction(null)
                .alertTriggered(false)
                .build();

        return CognitiveAssessmentResponse.builder()
                .id(null)
                .residentId(s.getResident().getId())
                .residentName(s.getResident().getUser().getFullName())
                .memory(null)
                .attention(null)
                .orientation(null)
                .recall(null)
                .reasoning(null)
                .acrfScore(null)
                .mlPrediction(null)
                .riskLevel("Not Available")
                .alertTriggered(false)
                .categoryContributions(Collections.emptyList())
                .weightsApplied(ACRF_WEIGHTS)
                .mlModelEvaluation(mlStatus)
                .methodology("Pending Caregiver Clinical Review")
                .clinicalDisclaimer("Awaiting caregiver review and clinical grading.")
                .assessedBy(s.getInitiatedBy() != null ? s.getInitiatedBy() : "Caregiver Session")
                .createdAt(s.getCreatedAt())
                .sessionId(s.getSessionId())
                .status(s.getStatus() != null ? s.getStatus() : "PENDING_CAREGIVER_REVIEW")
                .responses(parsedResponses)
                .grades(parsedGrades)
                .responseTimes(parsedTimes)
                .build();
    }

    private String resolveRiskLevel(String mlPrediction, Double acrfScore) {
        if (mlPrediction != null && !mlPrediction.isBlank() && !"Not Available".equalsIgnoreCase(mlPrediction.trim())
                && !"Prediction Unavailable".equalsIgnoreCase(mlPrediction.trim())) {
            String p = mlPrediction.trim();
            if (p.equalsIgnoreCase("Low") || p.equalsIgnoreCase("Low Risk"))
                return "Low Risk";
            if (p.equalsIgnoreCase("Moderate") || p.equalsIgnoreCase("Moderate Risk"))
                return "Moderate Risk";
            if (p.equalsIgnoreCase("High") || p.equalsIgnoreCase("High Risk"))
                return "High Risk";
            return p;
        }
        if (acrfScore != null && !Double.isNaN(acrfScore)) {
            double s = (acrfScore <= 1.0 && acrfScore > 0.0) ? acrfScore * 100.0 : acrfScore;
            if (s >= 70.0)
                return "Low Risk";
            if (s >= 50.0)
                return "Moderate Risk";
            return "High Risk";
        }
        return "Not Available";
    }

    private CognitiveAssessmentResponse.CategoryContributionDto createContrib(String category, Double score,
            Double weight) {
        double contribution = Math.round(score * weight * 10000.0) / 10000.0;
        return CognitiveAssessmentResponse.CategoryContributionDto.builder()
                .category(category)
                .score(score)
                .weight(weight)
                .contribution(contribution)
                .weightPercentage((int) (weight * 100) + "%")
                .build();
    }

    private CognitiveAiResult buildFallbackAiResult(
            Double memory,
            Double attention,
            Double orientation,
            Double recall,
            Double reasoning,
            String reason) {
        Double acrfScore = CognitiveScoringService.calculateAcrfScore(memory, attention, orientation, recall,
                reasoning);
        Map<String, Double> weightsApplied = new HashMap<>();
        weightsApplied.put("memory", 0.25);
        weightsApplied.put("attention", 0.20);
        weightsApplied.put("orientation", 0.20);
        weightsApplied.put("recall", 0.20);
        weightsApplied.put("reasoning", 0.15);

        Map<String, Double> categoryScores = new HashMap<>();
        categoryScores.put("memory", memory != null ? memory : 0.0);
        categoryScores.put("attention", attention != null ? attention : 0.0);
        categoryScores.put("orientation", orientation != null ? orientation : 0.0);
        categoryScores.put("recall", recall != null ? recall : 0.0);
        categoryScores.put("reasoning", reasoning != null ? reasoning : 0.0);

        List<CognitiveAssessmentResponse.CategoryContributionDto> contributions = new ArrayList<>();
        contributions.add(createContrib("memory", categoryScores.get("memory"), 0.25));
        contributions.add(createContrib("attention", categoryScores.get("attention"), 0.20));
        contributions.add(createContrib("orientation", categoryScores.get("orientation"), 0.20));
        contributions.add(createContrib("recall", categoryScores.get("recall"), 0.20));
        contributions.add(createContrib("reasoning", categoryScores.get("reasoning"), 0.15));

        CognitiveAssessmentResponse.MlModelStatusDto mlStatus = CognitiveAssessmentResponse.MlModelStatusDto.builder()
                .available(false)
                .modelType("RandomForestClassifier")
                .statusMessage(reason != null && !reason.isBlank()
                        ? "AI microservice is unavailable (" + reason
                                + "). ACRF cognitive score calculated authoritatively by backend scoring engine."
                        : "AI microservice is unavailable. ACRF cognitive score calculated authoritatively by backend scoring engine.")
                .prediction(null)
                .probabilities(null)
                .alertTriggered(false)
                .alertThreshold(0.48)
                .experimentalLabel("Synthetic Benchmark")
                .missingFeatures(List.of("AI Microservice Connection"))
                .build();

        return CognitiveAiResult.builder()
                .acrfScore(acrfScore)
                .rawWeightedScore(acrfScore)
                .scale("0-100")
                .scoringDirection("Higher is better")
                .weightsApplied(weightsApplied)
                .categoryScores(categoryScores)
                .categoryContributions(contributions)
                .mlModelEvaluation(mlStatus)
                .methodology("ACRF Fixed Base Weights")
                .clinicalDisclaimer("Non-diagnostic wellness metric. Assessment evaluated by backend scoring engine.")
                .build();
    }
}
