package com.carevora.dto.metabolic;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MetabolicAssessmentResponse {
    private Long id;
    private Long residentId;
    private String residentName;
    private String assessedBy;
    private String modelVersion;
    private LocalDateTime createdAt;

    /** Inputs as submitted (camelCase keys, nulls omitted). */
    private Map<String, Object> inputs;

    /**
     * AI service result: disclaimer, input_warnings, inputs_not_used and, per outcome
     * (diabetes, cvd, fatty_liver), status, model_tier, risk_tier, probability, risk_range,
     * top_reasons, suggestions and inputs_to_improve_estimate.
     */
    private Map<String, Object> result;
}
