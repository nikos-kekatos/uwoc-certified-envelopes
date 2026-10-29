"""Check 2: Rx-FOV drift budget for the 70 unresolved and 32 Certified hero-map cells.
Run after code/falsify_sideways.m: python code/drift_budget.py

(a) margin at t = 0: FOV_R - max |phi0| over the cell box. In the planar rung the Rx
    incidence is |phi| (ace_eval.m, reach_cell.m), so this is 30 - 3 = 27 deg for every cell.
(b) drift over T = 20 s:
    - kinematic: w0 T / d_min, d_min = d0 - 0.25 m (lateral displacement w0 T seen from the
      closest range of the cell). Not a rigorous bound: it ignores the vehicle's own
      tangential motion and any range loss during the run; it is a scale.
    - tight (noise-free worst case): max |phi(t)| - 3 deg over the noise-free adversarial
      scenarios of falsify_sideways.m (constant, LOS-tracking and once-switching currents of
      magnitude w0, directions within 30 deg of perpendicular, x0 corners). It is a lower
      bound on the true worst-case drift.
    - adversarial with noise: the same quantity over all Check 1 scenarios (estimation
      biases at their bounds); also a lower bound.
Class (on the tight noise-free ratio r = drift / margin): physically at risk r >= 1;
borderline 0.5 <= r < 1; tool-limited r < 0.5.
"""
import os, csv, math
from collections import Counter, defaultdict
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "results"); OUT = os.path.join(RES, "diag70")
FOV = math.radians(30); PHI0 = math.radians(3); T = 20.0; DHALF = 0.25
MARGIN = FOV - PHI0


def rd(p):
    with open(p) as f:
        return list(csv.DictReader(f))


def tb(x):
    return x in ("1", "true", "True")


S = rd(os.path.join(OUT, "sideways_cells.csv"))
rows = []
for s in S:
    d0, loc, w = float(s["d0_m"]), float(s["loc_m"]), float(s["w_mps"])
    kin = w * T / (d0 - DHALF)
    nf = max(float(s["nf_phimax_rad"]) - PHI0, 0.0)
    adv = max(float(s["adv_phimax_rad"]) - PHI0, 0.0)
    r_nf, r_kin, r_adv = nf / MARGIN, kin / MARGIN, adv / MARGIN
    cls = "at risk" if r_nf >= 1 else ("borderline" if r_nf >= 0.5 else "tool-limited")
    cls_kin = "at risk" if r_kin >= 1 else ("borderline" if r_kin >= 0.5 else "tool-limited")
    cls_adv = "at risk" if r_adv >= 1 else ("borderline" if r_adv >= 0.5 else "tool-limited")
    if s["group"] == "certified32":
        verdict = "Certified"
    else:
        verdict = "Falsified(sideways)" if tb(s["found_any"]) else "Unresolved"
    rows.append(dict(cell=s["cell"], group=s["group"], water=s["water"], d0_m=d0, loc_m=loc, w_mps=w,
                     margin0_rad=round(MARGIN, 4), drift_kin_rad=round(kin, 4), drift_nf_rad=round(nf, 4),
                     drift_adv_rad=round(adv, 4), ratio_kin=round(r_kin, 3), ratio_nf=round(r_nf, 3),
                     ratio_adv=round(r_adv, 3), class_nf=cls, class_kin=cls_kin, class_adv=cls_adv, verdict=verdict,
                     nf_rx_margin_min_deg=round(float(s["nf_rxmin_deg"]), 2),
                     adv_min_rho=round(float(s["min_rho"]), 3)))
with open(os.path.join(OUT, "drift_budget.csv"), "w", newline="") as f:
    wr = csv.DictWriter(f, fieldnames=list(rows[0].keys())); wr.writeheader(); wr.writerows(rows)

L = []; P = L.append
P(f"Rx-FOV margin at t = 0: {math.degrees(MARGIN):.1f} deg = {MARGIN:.4f} rad for every cell (planar incidence = |phi|).")
CL = ["at risk", "borderline", "tool-limited"]
for key, name in [("class_nf", "tight (noise-free worst-case simulation)"),
                  ("class_adv", "adversarial with estimation biases at their bounds (Check 1 scenarios)"),
                  ("class_kin", "kinematic w0 T / d_min")]:
    P(f"\nClassification by {name}:")
    P("| verdict | " + " | ".join(CL) + " | total |")
    P("|---|" + "---|" * (len(CL) + 1))
    for v in ["Certified", "Falsified(sideways)", "Unresolved"]:
        c = Counter(r[key] for r in rows if r["verdict"] == v)
        n = sum(c.values())
        if n:
            P(f"| {v} | " + " | ".join(str(c[k]) for k in CL) + f" | {n} |")
for key in ["class_nf", "class_adv"]:
    P(f"\nThe 70 (unresolved + sideways-falsified), {key}, by localisation band:")
    P("| loc band | " + " | ".join(CL) + " | total |")
    P("|---|" + "---|" * (len(CL) + 1))
    for band, test in [("loc < 0.3 m", lambda x: x < 0.3), ("loc >= 0.3 m", lambda x: x >= 0.3)]:
        c = Counter(r[key] for r in rows if r["group"] == "inconclusive70" and test(r["loc_m"]))
        P(f"| {band} | " + " | ".join(str(c[k]) for k in CL) + f" | {sum(c.values())} |")
    P("\nThe 70 by current bound and " + key + ":")
    for w in sorted({r["w_mps"] for r in rows if r["group"] == "inconclusive70"}):
        c = Counter(r[key] for r in rows if r["group"] == "inconclusive70" and r["w_mps"] == w)
        P(f"  w = {w:g}: " + ", ".join(f"{k} {c[k]}" for k in CL))
P("\nUnresolved cells (tight class) by water:")
for wn in ["clear", "coastal", "turbid"]:
    c = Counter(r["class_nf"] for r in rows if r["verdict"] == "Unresolved" and r["water"] == wn)
    P(f"  {wn}: " + ", ".join(f"{k} {c[k]}" for k in CL))
P("\nUnresolved cells by current bound (tight ratio: median, max; adversarial-with-noise ratio max):")
for w in sorted({r["w_mps"] for r in rows if r["verdict"] == "Unresolved"}):
    g = [r for r in rows if r["verdict"] == "Unresolved" and r["w_mps"] == w]
    P(f"  w = {w:g}: n={len(g)}, ratio_nf median {np.median([r['ratio_nf'] for r in g]):.2f}, "
      f"max {max(r['ratio_nf'] for r in g):.2f}; ratio_adv max {max(r['ratio_adv'] for r in g):.2f}; "
      f"ratio_kin median {np.median([r['ratio_kin'] for r in g]):.2f}")
cer = [r for r in rows if r["verdict"] == "Certified"]
P(f"\nCertified 32: ratio_nf max {max(r['ratio_nf'] for r in cer):.2f}, ratio_adv max {max(r['ratio_adv'] for r in cer):.2f}")
un = [r for r in rows if r["verdict"] == "Unresolved"]
P(f"Unresolved: ratio_nf max {max(r['ratio_nf'] for r in un):.2f}; ratio_adv max {max(r['ratio_adv'] for r in un):.2f}; "
  f"cells with ratio_adv >= 0.5: {sum(r['ratio_adv'] >= 0.5 for r in un)}")
P("\nHighest tight ratios among unresolved cells:")
for r in sorted(un, key=lambda r: -r["ratio_nf"])[:10]:
    P(f"  cell {r['cell']} {r['water']} d0={r['d0_m']:g} loc={r['loc_m']:g} w={r['w_mps']:g}: "
      f"nf {r['ratio_nf']:.2f}, adv {r['ratio_adv']:.2f}, kin {r['ratio_kin']:.2f}, min adv rho {r['adv_min_rho']}")
txt = "\n".join(L); print(txt)
open(os.path.join(OUT, "drift_budget_summary.txt"), "w").write(txt + "\n")
