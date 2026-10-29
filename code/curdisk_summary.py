"""Campaign C summary: status transitions of the 70 unresolved cells (A2 pass 2 -> disk),
margin change on the 32 certified cells (results/curdisk/curdisk_cells.csv vs opmap).
Writes results/curdisk/curdisk_summary.csv."""
import csv, os, collections
R = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "results")
T = list(csv.DictReader(open(os.path.join(R, "curdisk", "curdisk_cells.csv"))))
O = {(r["water"], r["d0_m"], r["loc_m"], r["w_mps"]): r for r in csv.DictReader(open(os.path.join(R, "opmap", "opmap_res_32.csv")))}
def cls(s):
    s = s or ""
    if "Explosion" in s or "explosion" in s: return "set explosion"
    if "model-range" in s: return "damping envelope"
    if "violated" in s: return "possible violation"
    if s.strip() in ("ok",): return "ok"
    return s
out = []
un = [r for r in T if r["set"] == "unresolved"]
tr = collections.Counter((cls(r["a2_pass2_status"]), cls(r["disk_status"]), r["disk_certified"]) for r in un)
for (a, b, c), n in sorted(tr.items()):
    out.append({"set": "unresolved", "a2_pass2_reason": a, "disk_reason": b, "disk_certified": c, "n": n})
ce = [r for r in T if r["set"] != "unresolved"]
d = []
for r in ce:
    o = O[(r["water"], r["d0_m"], r["loc_m"], r["w_mps"])]
    try: d.append(float(r["disk_Mlow_dB"]) - float(o["reach_Mlow_dB"]))
    except ValueError: pass
out.append({"set": "certified", "a2_pass2_reason": "", "disk_reason": "still certified", "disk_certified": "", "n": sum(r["disk_certified"] in ("1", "true", "True") for r in ce)})
out.append({"set": "certified", "a2_pass2_reason": "Mlow change (dB) vs opmap, min/median/max", "disk_reason": "%.3f/%.3f/%.3f" % (min(d), sorted(d)[len(d)//2], max(d)), "disk_certified": "", "n": len(d)})
with open(os.path.join(R, "curdisk", "curdisk_summary.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
for r in out: print(r)
