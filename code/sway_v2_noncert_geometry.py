"""12f: geometry of fallback steps that lie inside the tiled range but in an uncertified
v2 tile, vs certified steps (results/shield/sway_v2_fblog_v2.csv).
Writes results/shield/sway_v2_noncert_geometry.csv."""
import csv, math, os
D = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "results", "shield")
R = list(csv.DictReader(open(os.path.join(D, "sway_v2_fblog_v2.csv"))))
names = {"4": "NN+M(sway)", "6": "L(sway)", "7": "L(sway)+M"}
out = []
for c, nm in names.items():
    # inside the tiled phi/e range including the estimate margins (approximately |phi|<29, |e|<8 deg)
    unc = [r for r in R if r["ctrl_idx"] == c and r["cert_v2"] == "0" and abs(float(r["phih"])) < math.radians(29) and abs(float(r["eh"])) < math.radians(8)]
    cer = [r for r in R if r["ctrl_idx"] == c and r["cert_v2"] == "1"]
    for lab, L in (("uncertified_in_range", unc), ("certified", cer)):
        n = max(len(L), 1)
        out.append({"controller": nm, "set": lab, "n": len(L),
                    "share_abs_phih_ge_20deg": round(sum(abs(float(r["phih"])) >= math.radians(20) for r in L) / n, 3),
                    "share_abs_eh_ge_5deg": round(sum(abs(float(r["eh"])) >= math.radians(5) for r in L) / n, 3),
                    "share_coastal": round(sum(r["wi"] == "2" for r in L) / n, 3)})
with open(os.path.join(D, "sway_v2_noncert_geometry.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
for r in out: print(r)
