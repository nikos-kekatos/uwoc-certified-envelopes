"""Task 2 (coastal teacher vs res_32), steps 1-2: per-tile join of the planar CCV
results at loc 0.1 m, |w| <= 0.025 m/s, for the classical teacher
(ccv/ccv_2d_loc01_empirical_teacher.csv) and res_32 (ccv/ccv_2d_res_32.csv, rows with
loc_m = 0.1). Writes results/coastal_diag/join_{water}.csv and differing_tiles.csv, and
prints the EVV / falsified-EVV decomposition recomputed from the tiles."""
import csv, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CCV = os.path.join(ROOT, "results", "ccv")
OUT = os.path.join(ROOT, "results", "coastal_diag")
os.makedirs(OUT, exist_ok=True)

def rd(p):
    return list(csv.DictReader(open(p)))

te = rd(os.path.join(CCV, "ccv_2d_loc01_empirical_teacher.csv"))
rs = [r for r in rd(os.path.join(CCV, "ccv_2d_res_32.csv")) if abs(float(r["loc_m"]) - 0.1) < 1e-9 and r["water"] != "turbid"]  # the teacher run has no turbid tiles
key = lambda r: (r["water"], float(r["d0_m"]), float(r["phi0_deg"]))
T = {key(r): r for r in te}
R = {key(r): r for r in rs}
assert set(T) == set(R), "tilings differ"
F = ["mc_outage_rate", "mc_min_rho", "fals_found", "fals_min_rho", "verdict_maint", "provenance", "reach_status"]

def cat(r):
    mc0 = float(r["mc_outage_rate"]) == 0
    v = r["verdict_maint"]
    if not mc0:
        return "MC-outage"
    return {"Certified": "EVV-certified", "Falsified": "EVV-falsified"}.get(v, "EVV-unfalsified")

diff = []
for w in ["clear", "coastal"]:
    rows = []
    agg = {"teacher": {}, "res_32": {}}
    for k in sorted(k for k in T if k[0] == w):
        t, r = T[k], R[k]
        ct, cr = cat(t), cat(r)
        a = float(t["measure"])
        for nm, c in (("teacher", ct), ("res_32", cr)):
            agg[nm][c] = agg[nm].get(c, 0) + a
        row = {"water": w, "d0_m": k[1], "phi0_deg": k[2], "area_m2": a, "cat_teacher": ct, "cat_res32": cr}
        for f in F:
            row["t_" + f] = t[f]; row["r_" + f] = r[f]
        rows.append(row)
        # differ in the EVV decomposition (teacher has no CCV: res_32 Certified and
        # teacher EVV-unfalsified are the same empirical category)
        et = ct.replace("EVV-unfalsified", "EVV-notfals").replace("EVV-certified", "EVV-notfals")
        er = cr.replace("EVV-unfalsified", "EVV-notfals").replace("EVV-certified", "EVV-notfals")
        if et != er:
            diff.append(row)
    with open(os.path.join(OUT, f"join_{w}.csv"), "w", newline="") as f:
        wr = csv.DictWriter(f, fieldnames=list(rows[0].keys())); wr.writeheader(); wr.writerows(rows)
    print(w, {nm: {c: round(v, 3) for c, v in d.items()} for nm, d in agg.items()})
with open(os.path.join(OUT, "differing_tiles.csv"), "w", newline="") as f:
    wr = csv.DictWriter(f, fieldnames=list(diff[0].keys())); wr.writeheader(); wr.writerows(diff)
print("differing tiles:", len(diff))
for r in diff:
    print(r["water"], r["d0_m"], r["phi0_deg"], round(r["area_m2"], 3), r["cat_teacher"], "|", r["cat_res32"],
          "| t mc", r["t_mc_outage_rate"], "minrho", r["t_mc_min_rho"][:6], "fals", r["t_fals_found"], r["t_fals_min_rho"][:6], r["t_provenance"],
          "| r mc", r["r_mc_outage_rate"], "minrho", r["r_mc_min_rho"][:6], "fals", r["r_fals_found"], r["r_fals_min_rho"][:6], r["r_provenance"], r["r_verdict_maint"])
