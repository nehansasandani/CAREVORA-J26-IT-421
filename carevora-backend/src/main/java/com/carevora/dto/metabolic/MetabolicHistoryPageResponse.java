package com.carevora.dto.metabolic;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/** One page of a resident's metabolic screening history, newest first. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MetabolicHistoryPageResponse {
    private List<MetabolicAssessmentResponse> items;
    /** Zero-based page index. */
    private int page;
    private int size;
    private long totalItems;
    private int totalPages;
}
