"""Task 2 summary: per differing tile, agreement of teacher and res_32 under common seeds
(results/coastal_diag/seed_reruns.csv, run_coastal_diag.m), witness transfer
(witness_cross.csv) and the probability that 200 MC runs see no outage at the
5,000-run frequency (mc5000.csv). Writes results/coastal_diag/summary.csv."""
import csv, os, collections
D = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "results", "coastal_diag")
S = list(csv.DictReader(open(os.path.join(D, "seed_reruns.csv"))))
W = list(csv.DictReader(open(os.path.join(D, "witness_cross.csv"))))
M = list(csv.DictReader(open(os.path.join(D, "mc5000.csv"))))
cat = lambda r: "MC-outage" if float(r["mc_outage_rate"]) > 0 else ("EVV-falsified" if r["verdict"] == "Falsified" else "EVV-not-falsified")
by = collections.defaultdict(dict)
for r in S:
    by[(r["d0_m"], r["phi0_deg"], r["seed_kind"])][r["controller"]] = r
rows = []
for tile in sorted({(k[0], k[1]) for k in by}, key=lambda t: (float(t[0]), float(t[1]))):
    ks = [k for k in by if (k[0], k[1]) == tile]
    same = sum(cat(by[k]["teacher"]) == cat(by[k]["res_32"]) for k in ks)
    nE = {c: sum(cat(by[k][c]) != "MC-outage" for k in ks) for c in ("teacher", "res_32")}
    nF = {c: sum(cat(by[k][c]) == "EVV-falsified" for k in ks) for c in ("teacher", "res_32")}
    m5 = {r["controller"]: r for r in M if (r["d0_m"], r["phi0_deg"]) == tile}
    p = float(m5["teacher"]["outage_rate"])
    ws = [w for w in W if (w["d0_m"], w["phi0_deg"]) == tile]
    rows.append({"d0_m": tile[0], "phi0_deg": tile[1], "n_seeds": len(ks), "same_category_both": same,
                 "seeds_in_EVV_teacher": nE["teacher"], "seeds_in_EVV_res32": nE["res_32"],
                 "seeds_EVV_falsified_teacher": nF["teacher"], "seeds_EVV_falsified_res32": nF["res_32"],
                 "mc5000_outages_teacher": m5["teacher"]["n_outage"], "mc5000_outages_res32": m5["res_32"]["n_outage"],
                 "P_zero_in_200_at_p5000": round((1 - p) ** 200, 3),
                 "n_witnesses": len(ws), "witnesses_transfer": sum(float(w["rho_other"]) < -0.01 for w in ws),
                 "max_abs_rho_diff": round(max(abs(float(w["rho_own"]) - float(w["rho_other"])) for w in ws), 4),
                 "max_du_c": round(max(float(w["du_c_max"]) for w in ws), 4),
                 "max_dr_c": f'{max(float(w["dr_c_max"]) for w in ws):.1e}',
                 "min_falsifier_rho_any_seed": round(min(float(r["fals_min_rho"]) for k in ks for r in by[k].values() if r["fals_min_rho"] != "NaN"), 4)})
with open(os.path.join(D, "summary.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
for r in rows: print(r)
