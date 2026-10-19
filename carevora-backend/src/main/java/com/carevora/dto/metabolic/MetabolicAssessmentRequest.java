package com.carevora.dto.metabolic;

import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Inputs for a metabolic risk screening. All fields are optional: the AI service uses the
 * highest tier whose inputs are complete (home, then clinic labs, then extended labs) and
 * reports which inputs are missing. Plausible ranges are checked by the AI service.
 * If age is omitted, the resident's recorded age is used.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MetabolicAssessmentRequest {

    // ---- Home tier
    @PositiveOrZero private Double age;
    @Pattern(regexp = "male|female", message = "sex must be 'male' or 'female'")
    private String sex;
    @PositiveOrZero private Double heightCm;
    @PositiveOrZero private Double weightKg;
    @PositiveOrZero private Double waistCm;
    @PositiveOrZero private Double systolicBp;
    @PositiveOrZero private Double diastolicBp;
    @PositiveOrZero private Double restingHr;
    @Pattern(regexp = "never|former|current", message = "smokingStatus must be 'never', 'former' or 'current'")
    private String smokingStatus;
    @PositiveOrZero private Double drinksPerWeek;
    @PositiveOrZero private Double vigorousMinWeek;
    @PositiveOrZero private Double moderateMinWeek;
    @PositiveOrZero private Double sedentaryHours;
    private Boolean onBpMeds;
    private Boolean onCholesterolMeds;
    private Boolean onDiabetesMeds;
    private Boolean toldHypertension;
    private Boolean toldHighCholesterol;
    private Boolean toldDiabetes;

    // ---- Clinic tier (fasting blood tests)
    @PositiveOrZero private Double fastingGlucose;
    @PositiveOrZero private Double hba1c;
    @PositiveOrZero private Double hdl;
    @PositiveOrZero private Double ldl;
    @PositiveOrZero private Double triglycerides;

    // ---- Extended tier (liver and kidney blood tests)
    @PositiveOrZero private Double alt;
    @PositiveOrZero private Double ast;
    @PositiveOrZero private Double ggt;
    @PositiveOrZero private Double creatinine;

    // ---- Wearable feature table (accepted; steps and sleep are not used by the current models)
    @PositiveOrZero private Double stepsPerDay;
    @PositiveOrZero private Double sleepHours;
}
