# Model card: CareVora metabolic risk tiers (carevora_risk_v1)

**Not a diagnostic tool.** These models give screening estimates of how common a condition is
among people with similar measurements. They must not be used to diagnose, treat or rule out disease.

## Intended use
- Adults aged 40+ (older adults are the target users), alongside a clinician or caregiver.
- Output: a low / watch / high tier, a probability range, the top three reasons and a
  non-diagnostic suggestion, for diabetes, cardiovascular disease and fatty liver.
- Three input levels: **home** (questionnaire, body measures, blood pressure, wearable resting
  heart rate and sitting time), **clinic** (+ fasting glucose, HbA1c, HDL, LDL, triglycerides),
  **extended** (+ ALT, AST, GGT, creatinine). `predict_risk` uses the highest level whose inputs are complete.

## Training data
- US NHANES 2013-2014, 2015-2016, 2017-2018 (questionnaire, examination, laboratory and
  standard biochemistry files), adults aged 40-80 (age top-coded at 80), n = 11,463.
- Split by person: 70% train / 15% validation / 15% test, stratified by age band and outcomes.
- Unweighted prediction models (survey weights checked in the robustness analysis).
- Population: US civilian, non-institutionalized. Not validated outside the US or in care homes.

## Outcome definitions (current status / history, NOT future events)
- **Diabetes**: told by a doctor (DIQ010 = 1), or HbA1c >= 6.5%, or fasting glucose >= 126 mg/dL. Includes undiagnosed cases.
- **Cardiovascular disease**: ever told of heart failure, coronary heart disease, heart attack or stroke.
- **Fatty liver (estimated)**: Fatty Liver Index >= 60 or Hepatic Steatosis Index > 36 (fasting subsample only). This is an index-based estimate, not imaging or biopsy.
- Leakage rule: no model uses a variable that defines its own label (e.g. the diabetes model never sees HbA1c, glucose or diabetes diagnosis/medication; the fatty liver model never sees triglycerides, BMI, waist, liver enzymes, sex or diabetes diagnosis).

## Models

| outcome | tier | form | calibration | features |
|---|---|---|---|---|
| diabetes | home | logistic regression with cubic splines | none (well calibrated on validation) | age, female, waist_to_height, sbp, dbp, resting_hr, smoking_former, smoking_current, log_drinks_week, log_met_min_week, sedentary_hours, bp_meds, chol_meds, htn_dx, high_chol_dx |
| diabetes | clinic | logistic regression with cubic splines | none (well calibrated on validation) | age, female, waist_to_height, sbp, dbp, resting_hr, smoking_former, smoking_current, log_drinks_week, log_met_min_week, sedentary_hours, bp_meds, chol_meds, htn_dx, high_chol_dx, hdl, ldl, log_triglycerides |
| diabetes | extended | logistic regression with cubic splines | none (well calibrated on validation) | age, female, waist_to_height, sbp, dbp, resting_hr, smoking_former, smoking_current, log_drinks_week, log_met_min_week, sedentary_hours, bp_meds, chol_meds, htn_dx, high_chol_dx, hdl, ldl, log_triglycerides, log_alt, log_ast, log_ggt, egfr |
| cvd | home | logistic regression | none (well calibrated on validation) | age, female, waist_to_height, sbp, dbp, resting_hr, smoking_former, smoking_current, log_drinks_week, log_met_min_week, sedentary_hours, bp_meds, chol_meds, diab_meds, htn_dx, high_chol_dx, diabetes_dx |
| cvd | clinic | logistic regression with cubic splines | none (well calibrated on validation) | age, female, waist_to_height, sbp, dbp, resting_hr, smoking_former, smoking_current, log_drinks_week, log_met_min_week, sedentary_hours, bp_meds, chol_meds, diab_meds, htn_dx, high_chol_dx, diabetes_dx, fasting_glucose, hba1c, hdl, ldl, log_triglycerides |
| cvd | extended | logistic regression | none (well calibrated on validation) | age, female, waist_to_height, sbp, dbp, resting_hr, smoking_former, smoking_current, log_drinks_week, log_met_min_week, sedentary_hours, bp_meds, chol_meds, diab_meds, htn_dx, high_chol_dx, diabetes_dx, fasting_glucose, hba1c, hdl, ldl, log_triglycerides, log_alt, log_ast, log_ggt, egfr |
| fatty_liver | home | logistic regression with cubic splines | none (well calibrated on validation) | age, sbp, dbp, resting_hr, smoking_former, smoking_current, log_drinks_week, log_met_min_week, sedentary_hours, bp_meds, chol_meds, htn_dx, high_chol_dx |
| fatty_liver | clinic | logistic regression with cubic splines | none (well calibrated on validation) | age, sbp, dbp, resting_hr, smoking_former, smoking_current, log_drinks_week, log_met_min_week, sedentary_hours, bp_meds, chol_meds, htn_dx, high_chol_dx, fasting_glucose, hba1c, hdl, ldl |
| fatty_liver | extended | logistic regression with cubic splines | none (well calibrated on validation) | age, sbp, dbp, resting_hr, smoking_former, smoking_current, log_drinks_week, log_met_min_week, sedentary_hours, bp_meds, chol_meds, htn_dx, high_chol_dx, fasting_glucose, hba1c, hdl, ldl |

## Performance (test)

| outcome | tier | n | prevalence | auc | auc_ci | auprc | brier | cal_slope | cal_intercept |
|---|---|---|---|---|---|---|---|---|---|
| diabetes | home | 1610 | 0.273 | 0.772 | 0.745-0.795 | 0.573 | 0.161 | 1.027 | 0.019 |
| diabetes | clinic | 1610 | 0.273 | 0.790 | 0.764-0.814 | 0.602 | 0.155 | 1.069 | -0.009 |
| diabetes | extended | 1610 | 0.273 | 0.803 | 0.778-0.825 | 0.624 | 0.151 | 1.075 | -0.017 |
| cvd | home | 1708 | 0.149 | 0.796 | 0.769-0.825 | 0.406 | 0.107 | 0.962 | -0.002 |
| cvd | clinic | 1708 | 0.149 | 0.800 | 0.773-0.830 | 0.430 | 0.105 | 0.934 | -0.013 |
| cvd | extended | 1708 | 0.149 | 0.809 | 0.783-0.836 | 0.435 | 0.105 | 0.972 | -0.024 |
| fatty_liver | home | 695 | 0.636 | 0.678 | 0.638-0.715 | 0.790 | 0.212 | 0.910 | 0.032 |
| fatty_liver | clinic | 695 | 0.636 | 0.749 | 0.714-0.786 | 0.834 | 0.192 | 0.894 | -0.001 |
| fatty_liver | extended | 695 | 0.636 | 0.749 | 0.714-0.786 | 0.834 | 0.192 | 0.894 | -0.001 |

Subgroups flagged (AUC > 0.05 below overall, or observed/expected outside 0.8-1.25):

| outcome | tier | group | level | n | auc | O/E | flag |
|---|---|---|---|---|---|---|---|
| diabetes | home | age_band | 80+ | 153 | 0.666 | 1.061 | lower AUC |
| diabetes | home | ethnicity | Non-Hispanic Asian | 215 | 0.829 | 1.281 | under-predicts |
| diabetes | home | ethnicity | Other Hispanic | 149 | 0.718 | 1.079 | lower AUC |
| diabetes | clinic | age_band | 80+ | 153 | 0.725 | 1.004 | lower AUC |
| diabetes | extended | age_band | 80+ | 153 | 0.728 | 1.029 | lower AUC |
| cvd | home | age_band | 70-79 | 258 | 0.687 | 1.003 | lower AUC |
| cvd | home | age_band | 80+ | 169 | 0.632 | 1.030 | lower AUC |
| cvd | home | ethnicity | Mexican American | 247 | 0.723 | 0.657 | lower AUC, over-predicts |
| cvd | home | ethnicity | Other / multiracial | 50 | 0.897 | 2.047 | under-predicts |
| cvd | home | ethnicity | Other Hispanic | 158 | 0.746 | 0.958 | lower AUC |
| cvd | clinic | age_band | 40-59 | 835 | 0.736 | 0.980 | lower AUC |
| cvd | clinic | age_band | 70-79 | 258 | 0.707 | 0.967 | lower AUC |
| cvd | clinic | age_band | 80+ | 169 | 0.653 | 1.065 | lower AUC |
| cvd | clinic | ethnicity | Mexican American | 247 | 0.720 | 0.676 | lower AUC, over-predicts |
| cvd | clinic | ethnicity | Other / multiracial | 50 | 0.865 | 1.837 | under-predicts |
| cvd | clinic | ethnicity | Other Hispanic | 158 | 0.717 | 0.929 | lower AUC |
| cvd | extended | age_band | 70-79 | 258 | 0.727 | 0.996 | lower AUC |
| cvd | extended | age_band | 80+ | 169 | 0.637 | 1.005 | lower AUC |
| cvd | extended | ethnicity | Mexican American | 247 | 0.743 | 0.705 | lower AUC, over-predicts |
| cvd | extended | ethnicity | Other / multiracial | 50 | 0.889 | 1.887 | under-predicts |
| cvd | extended | ethnicity | Other Hispanic | 158 | 0.748 | 1.005 | lower AUC |
| fatty_liver | home | age_band | 80+ | 56 | 0.517 | 0.867 | lower AUC |
| fatty_liver | home | ethnicity | Non-Hispanic Asian | 95 | 0.756 | 0.658 | over-predicts |
| fatty_liver | home | ethnicity | Other Hispanic | 66 | 0.573 | 1.189 | lower AUC |
| fatty_liver | clinic | age_band | 80+ | 56 | 0.664 | 0.811 | lower AUC |
| fatty_liver | clinic | ethnicity | Non-Hispanic Asian | 95 | 0.774 | 0.670 | over-predicts |
| fatty_liver | clinic | ethnicity | Other Hispanic | 66 | 0.682 | 1.136 | lower AUC |
| fatty_liver | extended | age_band | 80+ | 56 | 0.664 | 0.812 | lower AUC |
| fatty_liver | extended | ethnicity | Non-Hispanic Asian | 95 | 0.774 | 0.669 | over-predicts |
| fatty_liver | extended | ethnicity | Other Hispanic | 66 | 0.684 | 1.136 | lower AUC |

## Tier thresholds (chosen on validation; see configs/tiers.yaml)

Low -> watch captures >= 90% of true cases. Watch -> high is where at least
50% (diabetes), 30% (cvd), 80% (fatty_liver) of people flagged have the outcome.

| model | low_to_watch | watch_to_high |
|---|---|---|
| diabetes_home | 0.1669 | 0.3424 |
| diabetes_clinic | 0.1696 | 0.3317 |
| diabetes_extended | 0.1676 | 0.3131 |
| cvd_home | 0.0737 | 0.1602 |
| cvd_clinic | 0.0777 | 0.1388 |
| cvd_extended | 0.0810 | 0.1376 |
| fatty_liver_home | 0.4547 | 0.7273 |
| fatty_liver_clinic | 0.4324 | 0.6887 |
| fatty_liver_extended | 0.4333 | 0.6882 |

## Limitations
- NHANES measures each person once: labels describe current status, so outputs are not future
  risk predictions. Several associations are reverse-causal (e.g. in the CVD model, lower LDL and
  blood pressure track treatment after diagnosis).
- Self-reported diagnoses can be wrong or missing.
- Fatty liver labels come from indices (FLI/HSI) whose definition overlaps the features they
  exclude, and the "either index" rule labels 63% of this age group positive; the fatty liver
  model is the weakest of the three.
- Wearable steps and sleep are accepted by `predict_risk` but not used: NHANES 2013-2018 has no
  comparable measures. Activity comes from self-reported minutes per week.
- Performance is lower in people aged 80+ and some ethnic groups (see subgroup flags).
- Associations are not causes; suggestions are general advice, not treatment.
