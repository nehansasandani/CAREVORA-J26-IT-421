# Generated copy of ML/carevora_risk/portable.py; edit the original and run ML/scripts/deploy_to_ai_service.py
"""
Portable model format: a trained pipeline exported as plain JSON and scored with numpy/scipy.

No scikit-learn and no pickles at prediction time, so the packaged models load in any
environment (e.g. the AI service, which pins an older scikit-learn) and cannot execute code.

    spec = export_spec(bundle)          # training side (needs the fitted sklearn pipeline)
    model = PortableModel(spec)         # prediction side (numpy, pandas, scipy only)
    model.predict_proba(df); model.contributions(df)
"""
import numpy as np
import pandas as pd
from scipy.interpolate import BSpline
from scipy.special import expit, logit

SPLINE_TAG = "__spl"


def export_spec(bundle: dict) -> dict:
    """Serialize a fitted bundle from train_baseline.py into a JSON-safe dict."""
    pre = bundle["pipeline"].named_steps["preprocessor"]
    lr = bundle["pipeline"].named_steps["model"]
    splines = {}
    for feat, st in pre.splines_.items():
        spl = st.bsplines_[0]
        splines[feat] = {"knots": [float(v) for v in spl.t], "degree": int(spl.k),
                         "include_bias": bool(st.include_bias), "extrapolation": st.extrapolation}
    return {
        "outcome": bundle["outcome"], "tier": bundle["tier"], "features": list(bundle["features"]),
        "continuous": list(pre.cont_), "medians": {k: float(v) for k, v in pre.medians_.items()},
        "means": {k: float(v) for k, v in pre.means_.items()}, "sds": {k: float(v) for k, v in pre.sds_.items()},
        "impute": bool(pre.impute), "indicator_cols": list(pre.indicator_cols_), "splines": splines,
        "columns": list(pre.feature_names_out_), "coef": [float(v) for v in lr.coef_[0]],
        "intercept": float(lr.intercept_[0]),
        "transformed_means": {k: float(v) for k, v in bundle["transformed_means"].items()},
        "calibrator": bundle.get("calibrator"),
    }


def _spline_basis(x: np.ndarray, spec: dict) -> np.ndarray:
    """Cubic B-spline basis with linear extrapolation, matching sklearn's SplineTransformer."""
    t, k = np.asarray(spec["knots"]), spec["degree"]
    n = len(t) - k - 1
    spl = BSpline(t, np.eye(n), k, extrapolate=False)
    out = np.zeros((len(x), n))
    xmin, xmax = t[k], t[-k - 1]
    inside = (x >= xmin) & (x <= xmax)
    out[inside] = spl(x[inside])
    f_min, f_max = spl(xmin), spl(xmax)
    fp_min, fp_max = spl(xmin, nu=1), spl(xmax, nu=1)
    below, above = x < xmin, x > xmax
    for j in range(max(k, 2)):
        out[below, j] = f_min[j] + (x[below] - xmin) * fp_min[j]
        kk = n - 1 - j
        out[above, kk] = f_max[kk] + (x[above] - xmax) * fp_max[kk]
    return out if spec["include_bias"] else out[:, :-1]


def _base_feature(name: str) -> str:
    if SPLINE_TAG in name:
        return name.split(SPLINE_TAG)[0]
    return name[: -len("_missing")] if name.endswith("_missing") else name


class PortableModel:
    def __init__(self, spec: dict):
        self.spec = spec
        self.features = spec["features"]
        self.medians = spec["medians"]
        self.coef = np.asarray(spec["coef"])

    def transform(self, X: pd.DataFrame) -> pd.DataFrame:
        s = self.spec
        X = X[self.features].astype(float)
        ind = X[s["indicator_cols"]].isna().astype(float)
        ind.columns = [f"{c}_missing" for c in s["indicator_cols"]]
        out = X.fillna(pd.Series(s["medians"])) if s["impute"] else X.copy()
        for c in s["continuous"]:
            out[c] = (out[c] - s["means"][c]) / s["sds"][c]
        parts = []
        for c in self.features:
            if c in s["splines"]:
                basis = _spline_basis(out[c].to_numpy(), s["splines"][c])
                parts.append(pd.DataFrame(basis, index=out.index,
                                          columns=[f"{c}{SPLINE_TAG}{k}" for k in range(basis.shape[1])]))
            else:
                parts.append(out[[c]])
        Z = pd.concat(parts + [ind], axis=1)
        return Z[s["columns"]]

    def predict_proba(self, X: pd.DataFrame) -> np.ndarray:
        z = self.transform(X).to_numpy() @ self.coef + self.spec["intercept"]
        p = expit(z)
        cal = self.spec.get("calibrator")
        if cal:
            p = expit(cal["intercept"] + cal["slope"] * logit(np.clip(p, 1e-6, 1 - 1e-6)))
        return p

    def contributions(self, X: pd.DataFrame) -> pd.DataFrame:
        """Log-odds contribution of each feature relative to the average training person."""
        Z = self.transform(X)
        centred = Z - pd.Series(self.spec["transformed_means"])[Z.columns]
        contrib = centred * self.coef
        if self.spec.get("calibrator"):
            contrib = contrib * self.spec["calibrator"]["slope"]
        return contrib.T.groupby(_base_feature).sum().T[self.features]
