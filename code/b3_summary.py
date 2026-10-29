"""B3 summary from results/b3/hero_rx_compare.csv (+ hero_rx_cells.csv): verdict and
provenance transitions res_32 -> res_32_sway, reach statuses, MC outage.
Writes results/b3/hero_rx_summary.csv."""
import csv, os, collections
R = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "results", "b3")
C = list(csv.DictReader(open(os.path.join(R, "hero_rx_compare.csv"))))
out = []
def add(k, v, n): out.append({"metric": k, "value": v, "n": n})
for a, b in sorted(collections.Counter((r["res32_verdict"], r["sway_verdict"]) for r in C).items()):
    add("verdict res_32 -> sway", f"{a[0]} -> {a[1]}", b)
for nm, vk, pk in (("res_32", "res32_verdict", "res32_prov"), ("sway", "sway_verdict", "sway_prov")):
    for p, n in sorted(collections.Counter(r[pk] or "-" for r in C if r[vk] == "Falsified").items()):
        add(f"{nm} falsified provenance", p, n)
    add(f"{nm} cells with MC outage > 0", "", sum(float(r[nm == 'res_32' and 'res32_mc' or 'sway_mc']) > 0 for r in C))
    add(f"{nm} mean MC outage rate", "%.4f" % (sum(float(r[nm == 'res_32' and 'res32_mc' or 'sway_mc']) for r in C) / len(C)), len(C))
def cls(s):
    if "xplosion" in s: return "set explosion"
    if "model-range" in s: return "damping envelope"
    if "violated" in s: return "possible violation"
    if "skipped" in s: return "skipped (MC witness)"
    return s
for p, n in sorted(collections.Counter(cls(r["sway_status"]) for r in C if r["sway_verdict"] == "Inconclusive").items()):
    add("sway inconclusive reach status", p, n)
for p, n in sorted(collections.Counter(cls(r["res32_status"]) for r in C if r["res32_verdict"] == "Inconclusive").items()):
    add("res_32 inconclusive reach status", p, n)
for w in ["clear", "coastal", "turbid"]:
    for nm, vk in (("res_32", "res32_verdict"), ("sway", "sway_verdict")):
        c = collections.Counter(r[vk] for r in C if r["water"] == w)
        add(f"{nm} verdicts {w}", f"C {c['Certified']} / F {c['Falsified']} / I {c['Inconclusive']}", sum(c.values()))
with open(os.path.join(R, "hero_rx_summary.csv"), "w", newline="") as f:
    wr = csv.DictWriter(f, fieldnames=["metric", "value", "n"]); wr.writeheader(); wr.writerows(out)
for r in out: print(r)

# ---- planar CCV statuses (results/ccv/ccv_b3w{025,050}_res_32_sway.csv vs res_32) ----
CC = os.path.join(os.path.dirname(R), "ccv")
rows = []
for tag, ref, loc in (("b3w025", "ccv_2d_res_32.csv", 0.1), ("b3w050", "ccv_2d_w005_res_32.csv", 0.1)):
    S = list(csv.DictReader(open(os.path.join(CC, f"ccv_{tag}_res_32_sway.csv"))))
    B = [r for r in csv.DictReader(open(os.path.join(CC, ref))) if abs(float(r["loc_m"]) - loc) < 1e-9 and r["water"] != "turbid"]
    for nm, T in (("res_32_sway", S), ("res_32", B)):
        for w in ("clear", "coastal"):
            X = [r for r in T if r["water"] == w]
            ev = [r for r in X if float(r["mc_outage_rate"]) == 0]
            st = collections.Counter(cls(r["reach_status"]) for r in ev if r["verdict_maint"] == "Inconclusive")
            fp = collections.Counter(r["provenance"] for r in X if r["verdict_maint"] == "Falsified")
            rows.append({"run": tag, "controller": nm, "water": w, "n_tiles": len(X), "n_EVV": len(ev),
                         "n_cert": sum(r["verdict_maint"] == "Certified" for r in X),
                         "EVV_inconclusive_status": "; ".join(f"{k} {v}" for k, v in sorted(st.items())),
                         "falsified_prov_all_tiles": "; ".join(f"{k} {v}" for k, v in sorted(fp.items()))})
with open(os.path.join(R, "ccv_status_summary.csv"), "w", newline="") as f:
    wr = csv.DictWriter(f, fieldnames=list(rows[0].keys())); wr.writeheader(); wr.writerows(rows)
for r in rows: print(r)
