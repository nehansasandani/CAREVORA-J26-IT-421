package com.carevora.controller;

import com.carevora.dto.ApiResponse;
import com.carevora.dto.metabolic.MetabolicAssessmentRequest;
import com.carevora.dto.metabolic.MetabolicAssessmentResponse;
import com.carevora.dto.metabolic.MetabolicHistoryPageResponse;
import com.carevora.dto.metabolic.MetabolicTrendPoint;
import com.carevora.service.MetabolicAssessmentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@Tag(name = "Metabolic Health", description = "Metabolic risk screening (diabetes, cardiovascular disease, fatty liver) with low / watch / high tiers")
public class MetabolicAssessmentController {

    private final MetabolicAssessmentService metabolicAssessmentService;

    public MetabolicAssessmentController(MetabolicAssessmentService metabolicAssessmentService) {
        this.metabolicAssessmentService = metabolicAssessmentService;
    }

    @PostMapping("/api/residents/{residentId}/metabolic-assessments")
    @Operation(summary = "Run a metabolic risk screening for a resident and store the result")
    public ResponseEntity<ApiResponse<MetabolicAssessmentResponse>> submitAssessment(
            @PathVariable Long residentId,
            @Valid @RequestBody MetabolicAssessmentRequest request
    ) {
        return ResponseEntity.ok(metabolicAssessmentService.submitAssessment(residentId, request));
    }

    @GetMapping("/api/residents/{residentId}/metabolic-assessments")
    @Operation(summary = "Get a resident's metabolic screening history (newest first)")
    public ResponseEntity<ApiResponse<List<MetabolicAssessmentResponse>>> getResidentAssessments(
            @PathVariable Long residentId
    ) {
        return ResponseEntity.ok(metabolicAssessmentService.getResidentAssessments(residentId));
    }

    @GetMapping("/api/residents/{residentId}/metabolic-assessments/history")
    @Operation(summary = "Get one page of a resident's metabolic screening history (newest first), "
            + "optionally between from and to dates (yyyy-MM-dd, inclusive)")
    public ResponseEntity<ApiResponse<MetabolicHistoryPageResponse>> getResidentAssessmentPage(
            @PathVariable Long residentId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "5") int size,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        return ResponseEntity.ok(metabolicAssessmentService.getResidentAssessmentPage(residentId, page, size, from, to));
    }

    @GetMapping("/api/residents/{residentId}/metabolic-assessments/{assessmentId}/trend")
    @Operation(summary = "Risk tier and probability per outcome for the screenings up to this one (oldest first)")
    public ResponseEntity<ApiResponse<List<MetabolicTrendPoint>>> getTrend(
            @PathVariable Long residentId,
            @PathVariable Long assessmentId,
            @RequestParam(defaultValue = "8") int limit
    ) {
        return ResponseEntity.ok(metabolicAssessmentService.getTrend(residentId, assessmentId, limit));
    }

    @GetMapping("/api/residents/{residentId}/metabolic-assessments/latest")
    @Operation(summary = "Get a resident's most recent metabolic screening")
    public ResponseEntity<ApiResponse<MetabolicAssessmentResponse>> getLatestAssessment(
            @PathVariable Long residentId
    ) {
        return ResponseEntity.ok(metabolicAssessmentService.getLatestAssessment(residentId));
    }

    @GetMapping("/api/metabolic/model-info")
    @Operation(summary = "Metabolic model version, required inputs, tier thresholds and test performance")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getModelInfo() {
        return ResponseEntity.ok(metabolicAssessmentService.getModelInfo());
    }
}
