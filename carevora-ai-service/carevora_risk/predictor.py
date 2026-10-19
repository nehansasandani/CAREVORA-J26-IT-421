# Generated copy of ML/carevora_risk/predictor.py; edit the original and run ML/scripts/deploy_to_ai_service.py
"""
predict_risk(features: dict) -> dict

Checks which inputs are available, picks the highest model tier (home < clinic < extended)
whose inputs are all present, runs that model for each outcome and returns the risk tier,
probability, top reasons and non-diagnostic suggestions.

    from carevora_risk.predictor import predict_risk
    predict_risk({"age": 67, "sex": "female", "waist_cm": 98, "height_cm": 160, ...})
"""
import json
import math
import os
from functools import lru_cache
from pathlib import Path

import numpy as np
import pandas as pd

from .features import BOOL_INPUTS, FEATURE_INPUTS, INPUTS, WEARABLE_ALIASES, clip_to_ranges, inputs_to_features
from .portable import PortableModel

DEFAULT_MODEL_DIR = Path(os.environ.get(
    "CAREVORA_METABOLIC_MODEL_DIR",
    Path(__file__).resolve().parents[1] / "outputs" / "models" / "carevora_risk_v1"))
MAX_ESTIMATED_HOME_INPUTS = 3      # home tier may fill in at most this many missing features


class RiskPredictor:
    def __init__(self, model_dir=DEFAULT_MODEL_DIR):
        model_dir = Path(model_dir)
        self.manifest = json.loads((model_dir / "manifest.json").read_text())
        self.text = json.loads((model_dir / "explanations.json").read_text())
        self.models = {(o, t): PortableModel(json.loads((model_dir / spec["file"]).read_text()))
                       for o, ospec in self.manifest["outcomes"].items()
                       for t, spec in ospec["tiers"].items()}

    # ------------------------------------------------------------ input handling
    def _clean_inputs(self, raw: dict):
        warnings, not_used, inp = [], [], {}
        for key, value in raw.items():
            if key in WEARABLE_ALIASES and key not in INPUTS:
                target = WEARABLE_ALIASES[key]
                if target is None:
                    not_used.append(key)
                    continue
                key = target
            if key not in INPUTS:
                not_used.append(key)
                continue
            if isinstance(value, (list, tuple)):          # e.g. several blood pressure readings
                vals = [v for v in value if v is not None]
                value = float(np.mean(vals)) if vals else None
            inp[key] = value
        if "sex" in inp and inp["sex"] not in (None, "male", "female"):
            warnings.append("sex must be 'male' or 'female'; ignored")
            inp["sex"] = None
        if "smoking_status" in inp and inp["smoking_status"] not in (None, "never", "former", "current"):
            warnings.append("smoking_status must be 'never', 'former' or 'current'; ignored")
            inp["smoking_status"] = None
        for b in BOOL_INPUTS:
            if b in inp and inp[b] is not None and not (
                    isinstance(inp[b], (bool, int, float, np.bool_, np.integer, np.floating)) and inp[b] in (0, 1)):
                warnings.append(f"{b} must be true/false; ignored")
                inp[b] = None
        frame = pd.DataFrame([{k: inp.get(k) for k in INPUTS}])
        for c in frame.columns:
            if c not in ("sex", "smoking_status"):
                frame[c] = pd.to_numeric(frame[c], errors="coerce")
        frame, range_problems = clip_to_ranges(frame)
        warnings += [f"{p}; ignored" for p in range_problems]
        if frame.loc[0, ["systolic_bp", "diastolic_bp"]].notna().all() and \
                frame.loc[0, "systolic_bp"] <= frame.loc[0, "diastolic_bp"]:
            warnings.append("systolic blood pressure must be higher than diastolic; both ignored")
            frame.loc[0, ["systolic_bp", "diastolic_bp"]] = np.nan
        return frame, warnings, not_used

    @staticmethod
    def _missing_inputs(frame, features_row, model_features):
        """(raw inputs the user still needs to give, model features that cannot be computed)."""
        miss = [f for f in model_features if pd.isna(features_row[f])]
        need = {i for f in miss for i in FEATURE_INPUTS[f] if pd.isna(frame.loc[0, i])}
        return sorted(need), miss

    # ------------------------------------------------------------ output wording
    def _risk_phrase(self, p, outcome):
        pct = p * 100
        condition = self.text["conditions"][outcome]
        if pct < 5:
            return f"fewer than 5 in 100 people with similar measurements have {condition}"
        lo = int(math.floor(pct / 5) * 5)
        return self.text["risk_phrase"].format(lo=lo, hi=min(lo + 5, 100), condition=condition)

    def _reasons(self, model, feats_row, estimated):
        contrib = model.contributions(feats_row).iloc[0]
        medians = model.medians
        reasons = []
        for f, c in contrib.sort_values(ascending=False).items():
            if c <= 0 or f in estimated:
                continue
            t = self.text["features"][f]
            v = feats_row[f].iloc[0]
            key = ("yes" if v >= 0.5 else "no") if "yes" in t else ("high" if v > medians[f] else "low")
            reasons.append({"feature": f, "reason": t[key], "suggestion": t["suggestion"],
                            "log_odds_contribution": round(float(c), 3)})
            if len(reasons) == 3:
                break
        return reasons

    # ------------------------------------------------------------ main entry point
    def predict_risk(self, features: dict) -> dict:
        frame, warnings, not_used = self._clean_inputs(features)
        feats = inputs_to_features(frame)
        out = {"model_version": self.manifest["version"], "disclaimer": self.text["disclaimer"].strip(),
               "input_warnings": warnings, "inputs_not_used": not_used, "results": {}}

        for outcome, ospec in self.manifest["outcomes"].items():
            # A tier whose feature list equals the previous tier's adds nothing (e.g. fatty liver
            # extended: every extended feature defines the label), so it is skipped.
            tier_names = [t for k, t in enumerate(ospec["tiers"]) if k == 0 or
                          self.models[(outcome, t)].features !=
                          self.models[(outcome, list(ospec["tiers"])[k - 1])].features]
            # The diabetes model screens for current diabetes; it does not apply to people already diagnosed.
            if outcome == "diabetes" and frame.loc[0, "told_diabetes"] == 1:
                out["results"][outcome] = {"status": "not_applicable",
                                           "message": self.text["already_diagnosed"][outcome]}
                continue
            complete = [t for t in tier_names
                        if not self._missing_inputs(frame, feats.iloc[0], self.models[(outcome, t)].features)[1]]
            if complete:
                tier, estimated = complete[-1], []
            else:
                tier = tier_names[0]
                need, estimated = self._missing_inputs(frame, feats.iloc[0], self.models[(outcome, tier)].features)
                if {"age", "sex"} & set(need) or len(estimated) > MAX_ESTIMATED_HOME_INPUTS:
                    out["results"][outcome] = {
                        "status": "insufficient_information",
                        "message": "Not enough information for an estimate. Please add: " + ", ".join(need) + ".",
                        "missing_inputs": need}
                    continue
            model = self.models[(outcome, tier)]
            p = float(model.predict_proba(feats)[0])
            th = ospec["tiers"][tier]["thresholds"]
            risk_tier = "low" if p < th["low_to_watch"] else (
                "high" if th["watch_to_high"] is not None and p >= th["watch_to_high"] else "watch")
            reasons = self._reasons(model, feats, set(estimated))
            nxt = tier_names.index(tier) + 1
            to_improve = (self._missing_inputs(frame, feats.iloc[0], self.models[(outcome, tier_names[nxt])].features)[0]
                          if nxt < len(tier_names) else [])
            res = {
                "status": "ok", "title": ospec["title"], "model_tier": tier, "risk_tier": risk_tier,
                "tier_text": self.text["tier_text"][risk_tier], "probability": round(p, 3),
                "risk_range": self._risk_phrase(p, outcome),
                "top_reasons": reasons,
                "suggestions": list(dict.fromkeys(r["suggestion"] for r in reasons)),
                "inputs_to_improve_estimate": to_improve,
            }
            if estimated:
                res["estimated_inputs"] = sorted({i for f in estimated for i in FEATURE_INPUTS[f]
                                                  if pd.isna(frame.loc[0, i])})
                res["note"] = ("Some inputs were missing and were filled in with typical values, "
                               "so this estimate is less certain.")
            out["results"][outcome] = res
        return out


@lru_cache(maxsize=4)
def _default(model_dir=str(DEFAULT_MODEL_DIR)):
    return RiskPredictor(model_dir)


def predict_risk(features: dict, model_dir=None) -> dict:
    return _default(str(model_dir or DEFAULT_MODEL_DIR)).predict_risk(features)
