package com.carevora.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

/**
 * One metabolic risk screening of a resident: the inputs sent to the AI service, the full
 * model result, and per-outcome summary columns (risk tier + probability) for listing.
 */
@Entity
@Table(name = "metabolic_assessments")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MetabolicAssessment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "resident_id", nullable = false)
    private Resident resident;

    @Column(name = "assessed_by", length = 100)
    private String assessedBy;

    @Column(name = "model_version", length = 50)
    private String modelVersion;

    @Lob
    @Column(name = "inputs_json", nullable = false)
    private String inputsJson;

    @Lob
    @Column(name = "result_json", nullable = false)
    private String resultJson;

    @Column(name = "diabetes_tier", length = 20)
    private String diabetesTier;

    @Column(name = "diabetes_probability")
    private Double diabetesProbability;

    @Column(name = "cvd_tier", length = 20)
    private String cvdTier;

    @Column(name = "cvd_probability")
    private Double cvdProbability;

    @Column(name = "fatty_liver_tier", length = 20)
    private String fattyLiverTier;

    @Column(name = "fatty_liver_probability")
    private Double fattyLiverProbability;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
