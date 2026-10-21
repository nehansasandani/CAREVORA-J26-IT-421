package com.carevora.dto.metabolic;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.Map;

/** One screening reduced to what a trend line needs: per outcome, the risk tier and probability. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MetabolicTrendPoint {
    private Long id;
    private LocalDateTime createdAt;
    /** Keyed by outcome: diabetes, cvd, fatty_liver. Missing when that outcome had no estimate. */
    private Map<String, OutcomePoint> outcomes;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class OutcomePoint {
        private String riskTier;
        private Double probability;
    }
}
