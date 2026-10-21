# Generated copy of ML/carevora_risk/features.py; edit the original and run ML/scripts/deploy_to_ai_service.py
"""
Feature construction shared by training and by predict_risk.

Two steps:
    nhanes_to_inputs(df)    NHANES codes  -> plain-language inputs (one row per person)
    inputs_to_features(df)  plain inputs  -> model features

The second step is the only one used at prediction time, so the training data and
live data go through exactly the same derivations.
"""
import numpy as np
import pandas as pd

# Plain-language inputs accepted by the model, with units and plausible ranges.
# Values outside the range are treated as missing (and reported) by predict_risk.
INPUTS = {
    # name: (unit, (min, max))
    "age": ("years", (18, 120)),
    "sex": ("'male' or 'female'", None),
    "height_cm": ("cm", (120, 210)),
    "weight_kg": ("kg", (25, 250)),
    "bmi": ("kg/m2", (12, 70)),
    "waist_cm": ("cm", (40, 200)),
    "systolic_bp": ("mmHg", (70, 260)),
    "diastolic_bp": ("mmHg", (30, 150)),
    "resting_hr": ("beats per minute", (30, 200)),
    "smoking_status": ("'never', 'former' or 'current'", None),
    "drinks_per_week": ("alcoholic drinks per week", (0, 140)),
    "vigorous_min_week": ("minutes per week of vigorous activity", (0, 5040)),
    "moderate_min_week": ("minutes per week of moderate activity incl. walking", (0, 5040)),
    "sedentary_hours": ("hours per day sitting", (0, 24)),
    "on_bp_meds": ("true/false", None),
    "on_cholesterol_meds": ("true/false", None),
    "on_diabetes_meds": ("true/false", None),
    "told_hypertension": ("true/false", None),
    "told_high_cholesterol": ("true/false", None),
    "told_diabetes": ("true/false", None),
    "fasting_glucose": ("mg/dL", (40, 600)),
    "hba1c": ("%", (3, 18)),
    "hdl": ("mg/dL", (10, 200)),
    "ldl": ("mg/dL", (10, 400)),
    "total_cholesterol": ("mg/dL", (50, 500)),
    "triglycerides": ("mg/dL", (20, 2000)),
    "alt": ("U/L", (3, 2000)),
    "ast": ("U/L", (3, 2000)),
    "ggt": ("U/L", (2, 3000)),
    "creatinine": ("mg/dL", (0.2, 15)),
}

BOOL_INPUTS = [k for k, (unit, _) in INPUTS.items() if unit == "true/false"]

# Inputs each model feature needs (used to tell the user what is missing).
FEATURE_INPUTS = {
    "age": ["age"], "female": ["sex"], "bmi": ["bmi"], "waist_to_height": ["waist_cm", "height_cm"],
    "sbp": ["systolic_bp"], "dbp": ["diastolic_bp"], "resting_hr": ["resting_hr"],
    "smoking_former": ["smoking_status"], "smoking_current": ["smoking_status"],
    "log_drinks_week": ["drinks_per_week"], "log_met_min_week": ["vigorous_min_week", "moderate_min_week"],
    "sedentary_hours": ["sedentary_hours"], "bp_meds": ["on_bp_meds"], "chol_meds": ["on_cholesterol_meds"],
    "diab_meds": ["on_diabetes_meds"], "htn_dx": ["told_hypertension"], "high_chol_dx": ["told_high_cholesterol"],
    "diabetes_dx": ["told_diabetes"], "fasting_glucose": ["fasting_glucose"], "hba1c": ["hba1c"],
    "hdl": ["hdl"], "ldl": ["ldl"], "log_triglycerides": ["triglycerides"], "log_alt": ["alt"],
    "log_ast": ["ast"], "log_ggt": ["ggt"], "egfr": ["creatinine", "age", "sex"],
}

# Wearable feature-table names mapped onto model inputs. Inputs mapped to None are accepted
# but not used by the current models (NHANES 2013-2018 has no step count or comparable sleep item).
WEARABLE_ALIASES = {
    "resting_hr_avg": "resting_hr",
    "sedentary_hours": "sedentary_hours",
    "steps_per_day": None,
    "sleep_hours": None,
}


# ---------------------------------------------------------------- NHANES -> inputs

def _yes_no(s: pd.Series) -> pd.Series:
    """1 = yes -> 1.0, 2 = no -> 0.0, anything else -> NaN."""
    return s.map({1: 1.0, 2: 0.0})


def _codes_to_nan(s: pd.Series, codes) -> pd.Series:
    return s.where(~s.isin(codes))


def _activity_minutes(df, flag, days, minutes):
    """Minutes per week for one NHANES activity domain (0 if the person said no)."""
    d = _codes_to_nan(df[days], [77, 99])
    m = _codes_to_nan(df[minutes], [7777, 9999])
    out = d * m
    out[df[flag] == 2] = 0.0
    out[~df[flag].isin([1, 2])] = np.nan
    return out


def _drinks_per_week(df):
    """Average alcoholic drinks per week over the past year.

    2013-2016 asks frequency as a number per week/month/year (ALQ120Q/U);
    2017-2018 asks a frequency category (ALQ121). Both are multiplied by the
    usual drinks per drinking day (ALQ130).
    """
    per_day = _codes_to_nan(df["ALQ130"], [777, 999])

    # 2013-2016
    q = _codes_to_nan(df["ALQ120Q"], [777, 999])
    unit = df["ALQ120U"].map({1: 1.0, 2: 12 / 52, 3: 1 / 52})
    freq_old = q * unit
    freq_old[q == 0] = 0.0
    never_old = (df["ALQ101"] == 2) & (df["ALQ110"] == 2)
    freq_old[never_old] = 0.0

    # 2017-2018: days per week for each answer category
    cat = {0: 0, 1: 7, 2: 5.5, 3: 3.5, 4: 2, 5: 1, 6: 2.5 * 12 / 52,
           7: 12 / 52, 8: 9 / 52, 9: 4.5 / 52, 10: 1.5 / 52}
    freq_new = df["ALQ121"].map(cat)
    freq_new[df["ALQ111"] == 2] = 0.0

    freq = freq_old.where(df["cycle"] != "2017-2018", freq_new)
    drinks = freq * per_day
    drinks[freq == 0] = 0.0
    return drinks


def nhanes_to_inputs(df: pd.DataFrame) -> pd.DataFrame:
    """Translate merged NHANES columns into the plain-language input table."""
    out = pd.DataFrame(index=df.index)
    out["age"] = df["RIDAGEYR"]
    out["sex"] = df["RIAGENDR"].map({1: "male", 2: "female"})
    out["height_cm"] = df["BMXHT"]
    out["weight_kg"] = df["BMXWT"]
    out["bmi"] = df["BMXBMI"]
    out["waist_cm"] = df["BMXWAIST"]
    out["systolic_bp"] = df[[f"BPXSY{i}" for i in range(1, 5)]].mean(axis=1)
    out["diastolic_bp"] = df[[f"BPXDI{i}" for i in range(1, 5)]].mean(axis=1)
    out["resting_hr"] = df["BPXPLS"]

    smq040 = df["SMQ040"]
    smoking = pd.Series(np.nan, index=df.index, dtype=object)
    smoking[df["SMQ020"] == 2] = "never"
    smoking[(df["SMQ020"] == 1) & smq040.isin([1, 2])] = "current"
    smoking[(df["SMQ020"] == 1) & (smq040 == 3)] = "former"
    out["smoking_status"] = smoking

    out["drinks_per_week"] = _drinks_per_week(df)

    vig = [_activity_minutes(df, "PAQ605", "PAQ610", "PAD615"),
           _activity_minutes(df, "PAQ650", "PAQ655", "PAD660")]
    mod = [_activity_minutes(df, "PAQ620", "PAQ625", "PAD630"),
           _activity_minutes(df, "PAQ635", "PAQ640", "PAD645"),
           _activity_minutes(df, "PAQ665", "PAQ670", "PAD675")]
    # A domain total is only known if every component is known.
    out["vigorous_min_week"] = pd.concat(vig, axis=1).sum(axis=1, min_count=2)
    out["moderate_min_week"] = pd.concat(mod, axis=1).sum(axis=1, min_count=3)

    sed = _codes_to_nan(df["PAD680"], [7777, 9999])
    out["sedentary_hours"] = sed / 60.0

    # Medication flags: 1 if taking, 0 if not taking or never told they had the condition.
    bp_meds = _yes_no(df["BPQ050A"])
    bp_meds[(df["BPQ020"] == 2) | (df["BPQ040A"] == 2)] = 0.0
    out["on_bp_meds"] = bp_meds

    chol_meds = _yes_no(df["BPQ100D"])
    chol_meds[(df["BPQ060"] == 2) | (df["BPQ080"] == 2) | (df["BPQ090D"] == 2)] = 0.0
    out["on_cholesterol_meds"] = chol_meds

    insulin, pills = _yes_no(df["DIQ050"]), _yes_no(df["DIQ070"])
    diab_meds = pd.Series(np.nan, index=df.index)
    diab_meds[(insulin == 0) & (pills.isna() | (pills == 0))] = 0.0
    diab_meds[(insulin == 1) | (pills == 1)] = 1.0
    out["on_diabetes_meds"] = diab_meds

    out["told_hypertension"] = _yes_no(df["BPQ020"])
    high_chol = _yes_no(df["BPQ080"])
    high_chol[df["BPQ060"] == 2] = 0.0
    out["told_high_cholesterol"] = high_chol
    # DIQ010: 1 yes, 2 no, 3 borderline (counted as no)
    out["told_diabetes"] = df["DIQ010"].map({1: 1.0, 2: 0.0, 3: 0.0})

    out["fasting_glucose"] = df["LBXGLU"]
    out["hba1c"] = df["LBXGH"]
    out["hdl"] = df["LBDHDD"]
    out["ldl"] = df["LBDLDL"]
    out["total_cholesterol"] = df["LBXTC"]
    out["triglycerides"] = df["LBXTR"]
    out["alt"] = df["LBXSATSI"]
    out["ast"] = df["LBXSASSI"]
    out["ggt"] = df["LBXSGTSI"]
    out["creatinine"] = df["LBXSCR"]
    return clip_to_ranges(out)[0]


# ---------------------------------------------------------------- inputs -> features

def clip_to_ranges(inputs: pd.DataFrame):
    """Set out-of-range numeric inputs to NaN. Returns (clean_df, list_of_problems)."""
    out = inputs.copy()
    problems = []
    for name, (unit, rng) in INPUTS.items():
        if name not in out or rng is None:
            continue
        col = pd.to_numeric(out[name], errors="coerce")
        bad = col.notna() & ((col < rng[0]) | (col > rng[1]))
        if bad.any():
            problems.append(f"{name} outside plausible range {rng[0]}-{rng[1]} {unit}")
        out[name] = col.where(~bad)
    return out, problems


def egfr_ckd_epi_2021(creatinine, age, female):
    """Race-free CKD-EPI 2021 eGFR (mL/min/1.73m2)."""
    female = pd.Series(female, dtype=float)
    kappa = np.where(female == 1, 0.7, 0.9)
    alpha = np.where(female == 1, -0.241, -0.302)
    ratio = np.asarray(creatinine, dtype=float) / kappa
    egfr = (142 * np.minimum(ratio, 1) ** alpha * np.maximum(ratio, 1) ** -1.200
            * 0.9938 ** np.asarray(age, dtype=float) * np.where(female == 1, 1.012, 1.0))
    return np.where(female.isna(), np.nan, egfr)


def inputs_to_features(inp: pd.DataFrame) -> pd.DataFrame:
    """Derive model features from the plain input table. Missing stays missing."""
    inp = inp.copy()
    for col in INPUTS:
        if col not in inp:
            inp[col] = np.nan
    num = lambda c: pd.to_numeric(inp[c], errors="coerce")

    f = pd.DataFrame(index=inp.index)
    f["age"] = num("age")
    f["female"] = inp["sex"].map({"female": 1.0, "male": 0.0})
    bmi = num("bmi")
    bmi = bmi.fillna(num("weight_kg") / (num("height_cm") / 100) ** 2)
    f["bmi"] = bmi
    f["waist_to_height"] = num("waist_cm") / num("height_cm")
    f["sbp"] = num("systolic_bp")
    f["dbp"] = num("diastolic_bp")
    f["resting_hr"] = num("resting_hr")
    smoking = inp["smoking_status"]
    known = smoking.isin(["never", "former", "current"])
    f["smoking_former"] = (smoking == "former").astype(float).where(known)
    f["smoking_current"] = (smoking == "current").astype(float).where(known)
    f["log_drinks_week"] = np.log1p(num("drinks_per_week"))
    met = 8 * num("vigorous_min_week") + 4 * num("moderate_min_week")
    f["log_met_min_week"] = np.log1p(met)
    f["sedentary_hours"] = num("sedentary_hours")
    for src, dst in [("on_bp_meds", "bp_meds"), ("on_cholesterol_meds", "chol_meds"),
                     ("on_diabetes_meds", "diab_meds"), ("told_hypertension", "htn_dx"),
                     ("told_high_cholesterol", "high_chol_dx"), ("told_diabetes", "diabetes_dx")]:
        f[dst] = inp[src].map(
            lambda v: np.nan if v is None or (isinstance(v, float) and np.isnan(v)) else float(bool(v)))
    f["fasting_glucose"] = num("fasting_glucose")
    f["hba1c"] = num("hba1c")
    f["hdl"] = num("hdl")
    f["ldl"] = num("ldl")
    f["log_triglycerides"] = np.log(num("triglycerides"))
    f["log_alt"] = np.log(num("alt"))
    f["log_ast"] = np.log(num("ast"))
    f["log_ggt"] = np.log(num("ggt"))
    f["egfr"] = egfr_ckd_epi_2021(num("creatinine"), f["age"], f["female"])
    return f
