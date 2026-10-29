"""Summaries for the calibrated (v1) results -> results/summary_v1.json.
Every number is computed from the CSVs written by the MATLAB scripts.
Wilson 95 % intervals for proportions (z = 1.96)."""
import csv, json, os, math, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "results")
W = ["clear", "coastal", "turbid"]


def rd(p):
    return list(csv.DictReader(open(p))) if os.path.exists(p) else None


def wilson(k, n, z=1.96):
    if n == 0:
        return [None, None, None]
    p = k / n
    den = 1 + z * z / n
    c = (p + z * z / (2 * n)) / den
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den
    return [round(p, 4), round(max(0, c - h), 4), round(min(1, c + h), 4)]


f = float
out = {}

# ---------------- hero operating map ----------------
R = rd(os.path.join(RES, "opmap", "opmap_res_32.csv"))
if R:
    o = {"n_cells": len(R), "verdicts": collections.Counter(r["verdict_maint"] for r in R)}
    o["by_water"] = {w: dict(collections.Counter(r["verdict_maint"] for r in R if r["water"] == w)) for w in W}
    mc0 = [r for r in R if f(r["mc_outage_rate"]) == 0]
    o["mc_zero_cells"] = len(mc0)
    o["mc_zero_verdicts"] = dict(collections.Counter(r["verdict_maint"] for r in mc0))
    o["mc_zero_falsified_prov"] = dict(collections.Counter(r["provenance"] for r in mc0 if r["verdict_maint"] == "Falsified"))
    o["certified_share_of_mc_zero"] = wilson(sum(r["verdict_maint"] == "Certified" for r in mc0), len(mc0))
    o["falsified_share_of_mc_zero"] = wilson(sum(r["verdict_maint"] == "Falsified" for r in mc0), len(mc0))
    o["falsified_prov_all"] = dict(collections.Counter(r["provenance"] for r in R if r["verdict_maint"] == "Falsified"))
    o["falsified_prov_by_w"] = {w: dict(collections.Counter(r["provenance"] for r in R if r["verdict_maint"] == "Falsified" and r["w_mps"] == w))
                                for w in sorted({r["w_mps"] for r in R}, key=float)}
    o["falsified_prov_by_loc"] = {l: dict(collections.Counter(r["provenance"] for r in R if r["verdict_maint"] == "Falsified" and r["loc_m"] == l))
                                  for l in sorted({r["loc_m"] for r in R}, key=float)}
    o["reach_status"] = dict(collections.Counter(r["reach_status"] for r in R))
    o["soundness_violations"] = sum(r["soundness_violation"] in ("1", "true", "True") for r in R)
    cert = [r for r in R if r["verdict_maint"] == "Certified"]
    o["certified_Mlow_range_dB"] = [min(f(r["reach_Mlow_dB"]) for r in cert), max(f(r["reach_Mlow_dB"]) for r in cert)] if cert else None
    rt = sorted(f(r["reach_time_s"]) for r in R if not r["reach_status"].startswith("skipped"))
    o["reach_time_s"] = {"median": rt[len(rt) // 2], "max": rt[-1], "total": sum(rt)} if rt else None
    o["certified_cells"] = [{k: r[k] for k in ("water", "d0_m", "loc_m", "w_mps", "reach_Mlow_dB", "mc_min_rho")} for r in cert]
    out["operating_map"] = o

# ---------------- CCV ----------------
for tag in ("2d", "3d"):
    S = rd(os.path.join(RES, "ccv", f"ccv_summary_{tag}_res_32.csv"))
    if S:
        out[f"ccv_{tag}"] = [{k: (round(f(v), 4) if k not in ("model", "water") else v) for k, v in r.items()} for r in S]

# ---------------- ladder on the CCV tiling ----------------
R = rd(os.path.join(RES, "ladder", "ladder_ccv_res_32.csv"))
if R:
    T = lambda r: r["falsified_6dof"] in ("1", "true", "True")
    l = {}
    for scope, rows in [("all", R)] + [(w, [r for r in R if r["water"] == w]) for w in W]:
        s2 = [r for r in rows if r["verdict_2d"] == "Certified"]
        s3 = [r for r in rows if r["verdict_3d"] == "Certified"]
        d = {
            "n_2d_certified_tiles": len(s2), "n_3d_certified_tiles": len(s3),
            "P_2Dcert_and_3Dfalsified": wilson(sum(r["verdict_3d"] == "Falsified" for r in s2), len(s2)),
            "P_2Dcert_and_3Dnotcertified": wilson(sum(r["verdict_3d"] != "Certified" for r in s2), len(s2)),
            "P_2Dcert_and_6DOFfalsified": wilson(sum(T(r) for r in s2), len(s2)),
            "P_3Dcert_and_6DOFfalsified": wilson(sum(T(r) for r in s3), len(s3)),
            "CCV_2D_projected_m3": round(sum(f(r["volume_m3"]) for r in s2), 3),
            "CCV_3D_m3": round(sum(f(r["volume_m3"]) for r in s3), 3),
            "CCV_3D_not_6DOF_falsified_m3": round(sum(f(r["volume_m3"]) for r in s3 if not T(r)), 3),
            "EVV_2D_projected_m3": round(sum(f(r["volume_m3"]) for r in rows if r["mc2d_outage"] not in ("", "NaN") and f(r["mc2d_outage"]) == 0), 3),
            "EVV_3D_m3": round(sum(f(r["volume_m3"]) for r in rows if r["mc3d_outage"] not in ("", "NaN") and f(r["mc3d_outage"]) == 0), 3),
            "EVV_6DOF_m3": round(sum(f(r["volume_m3"]) for r in rows if r["mc6dof_outage"] not in ("", "NaN") and f(r["mc6dof_outage"]) == 0), 3),
            "tiled_m3": round(sum(f(r["volume_m3"]) for r in rows), 3),
        }
        fw = [r for r in rows if T(r) and (r["verdict_2d"] == "Certified" or r["verdict_3d"] == "Certified")]
        d["mechanisms_6dof"] = dict(collections.Counter(r["mechanism_6dof"] for r in fw))
        d["prov_6dof"] = dict(collections.Counter(r["prov_6dof"] for r in fw))
        l[scope] = d
    out["ladder_ccv"] = l

# ---------------- ladder levels (operating-map certified cells) ----------------
R = rd(os.path.join(RES, "ladder", "ladder_res_32.csv"))
if R:
    lv = {}
    for name in sorted({r["level"] for r in R}):
        rows = [r for r in R if r["level"] == name]
        lv[name] = {"n_2d_certified": len(rows),
                    "P_2Dcert_and_3Dfalsified": wilson(sum(r["verdict_3d"] == "Falsified" for r in rows), len(rows)),
                    "P_2Dcert_and_3Dnotcertified": wilson(sum(r["verdict_3d"] != "Certified" for r in rows), len(rows)),
                    "P_2Dcert_and_6DOFfalsified": wilson(sum(r["falsified_6dof"] in ("1", "true", "True") for r in rows), len(rows)),
                    "P_3Dcert_and_6DOFfalsified": wilson(sum(r["falsified_6dof"] in ("1", "true", "True") for r in rows if r["verdict_3d"] == "Certified"),
                                                         sum(r["verdict_3d"] == "Certified" for r in rows)),
                    "mechanisms": dict(collections.Counter(r["mechanism_6dof"] for r in rows if r["falsified_6dof"] in ("1", "true", "True"))),
                    "prov_6dof": dict(collections.Counter(r["prov_6dof"] for r in rows if r["falsified_6dof"] in ("1", "true", "True")))}
    out["ladder_levels"] = lv

json.dump(out, open(os.path.join(RES, "summary_v1.json"), "w"), indent=1, default=dict)
print(json.dumps(out, indent=1, default=dict)[:6000])
