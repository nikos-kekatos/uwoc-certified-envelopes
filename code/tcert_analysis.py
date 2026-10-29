"""Check 3: certified link duration T_cert for the 130 empirically viable hero-map cells.
Run: python code/tcert_analysis.py

T_cert is the longest sound certified prefix [0, T_cert] of the ACE_O property (Tx cone,
Rx FOV, M >= 0) under the declared bounds, over every reach run we have for the cell:
  - Certified cells (hero map or A2 pass 2): 20 s (the property horizon; the chain often
    certified further windows, up to 25 s, which we do not count);
  - chain jobs (results/chain/chain_jobs.csv, H in {4,5} s x {box, par}):
      * window-granular: tCert_s = (windows OK) x H;
      * fine: tFail_s, the start of the first failing CORA time step / control period;
        every time-interval set before it was checked inside ACE_O and the damping
        envelope (chain_cell.m), so [0, tFail] is certified;
  - A2 pass 3 (T = 10 s certified): 10 s.
Falsified cells were never chained. Their T_cert is not computed (reported as 0, a lower
bound, and shown separately).
Raw opportunity: T_cert x 10 Mb/s (nominal raw transmitted-data opportunity under the link
model; not throughput, no protocol overhead, no BER loss).
"""
import os, csv
from collections import defaultdict
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import BoundaryNorm, ListedColormap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "results")
OUT = os.path.join(RES, "diag70"); os.makedirs(OUT, exist_ok=True)
FIG = os.path.join(ROOT, "figures"); os.makedirs(FIG, exist_ok=True)
RB = 10.0  # Mb/s
WATERS = ["clear", "coastal", "turbid"]
INK, INK2, MUTED, GRID = "#0b0b0b", "#52514e", "#898781", "#e1e0d9"
C_FALS = "#eb6834"


def rd(p):
    with open(p) as f:
        return list(csv.DictReader(f))


op = rd(os.path.join(RES, "opmap", "opmap_res_32.csv"))
for i, r in enumerate(op, 1):
    r["cell"] = i
a2 = rd(os.path.join(RES, "a2", "a2_inconclusive.csv"))
inc_cells = [r["cell"] for r in op if r["verdict_maint"] == "Inconclusive"]
assert len(inc_cells) == len(a2) == 74
a2c = {c: a for c, a in zip(inc_cells, a2)}
for c, a in a2c.items():
    assert float(op[c - 1]["d0_m"]) == float(a["d0_m"]) and float(op[c - 1]["loc_m"]) == float(a["loc_m"])
jobs = rd(os.path.join(RES, "chain", "chain_jobs.csv"))
jb = defaultdict(list)
for j in jobs:
    jb[int(j["cell"])].append(j)

rows = []
for r in op:
    if float(r["mc_outage_rate"]) != 0:
        continue
    c = r["cell"]; v = r["verdict_maint"]
    if v == "Inconclusive":
        f = a2c[c]["final_T20"]
        v = {"Certified(pass2)": "Certified", "Falsified(strong falsifier)": "Falsified"}.get(f, "Inconclusive")
    src = []
    tw = tf = 0.0
    for j in jb.get(c, []):
        if j["cert20"] in ("1", "true", "True"):
            tw_j = tf_j = 20.0
        else:
            tw_j = float(j["tCert_s"])
            tf_j = float(j["tFail_s"]) if j["tFail_s"] not in ("", "NaN", "nan") else tw_j
        tw = max(tw, min(tw_j, 20.0)); tf = max(tf, min(tf_j, 20.0))
    if jb.get(c):
        src.append("chain")
    if c in a2c and a2c[c]["pass3_T10_certified"] in ("1", "true", "True"):
        tw = max(tw, 10.0); tf = max(tf, 10.0); src.append("A2pass3")
    if v == "Certified":
        tw = tf = 20.0; src.append("certified")
    rows.append(dict(cell=c, water=r["water"], d0_m=float(r["d0_m"]), loc_m=float(r["loc_m"]),
                     w_mps=float(r["w_mps"]), verdict=v, tcert_win_s=tw, tcert_s=tf,
                     computed=int(v != "Falsified"), raw_Mb=tf * RB, raw_MB=tf * RB / 8,
                     sources="+".join(src)))

# verdict after Check 1 (if available)
sw = os.path.join(OUT, "sideways_cells.csv")
if os.path.exists(sw):
    fs = {int(r["cell"]): r for r in rd(sw)}
    for r in rows:
        s = fs.get(r["cell"])
        r["verdict_check1"] = r["verdict"]
        if s and r["verdict"] == "Inconclusive" and s["found_any"] in ("1", "true", "True"):
            r["verdict_check1"] = "Falsified(sideways)"

keys = list(rows[0].keys())
with open(os.path.join(OUT, "tcert_cells.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=keys); w.writeheader(); w.writerows(rows)

# ---------------- summaries ----------------
lines = []
P = lines.append
P(f"T_cert over the 130 empirically viable cells (verdicts: " +
  ", ".join(f"{k} {sum(r['verdict']==k for r in rows)}" for k in ["Certified", "Falsified", "Inconclusive"]) + ")")
comp = [r for r in rows if r["computed"]]
inc = [r for r in rows if r["verdict"] == "Inconclusive"]


def desc(vals):
    v = np.array(vals, float)
    if len(v) == 0:
        return "n=0"
    return (f"n={len(v)} median {np.median(v):.2f} s, mean {v.mean():.2f} s, "
            f"min {v.min():.2f}, max {v.max():.2f}; =0: {np.sum(v==0)}, >=10: {np.sum(v>=10)}, >=20: {np.sum(v>=20)}")


P("\nFine T_cert (tFail-based), cells with a computed value (Certified + Inconclusive):")
P("  all: " + desc([r["tcert_s"] for r in comp]))
P("  Inconclusive 70: " + desc([r["tcert_s"] for r in inc]))
P("  Inconclusive 70, window-granular: " + desc([r["tcert_win_s"] for r in inc]))
P("\nBy water (Inconclusive 70, fine):")
for wn in WATERS:
    P(f"  {wn}: " + desc([r["tcert_s"] for r in inc if r["water"] == wn]))
P("\nBy localisation error (Inconclusive 70, fine):")
for lv in sorted({r["loc_m"] for r in inc}):
    P(f"  loc {lv:g} m: " + desc([r["tcert_s"] for r in inc if r["loc_m"] == lv]))
P("\nBy water and loc band (Inconclusive 70; median fine T_cert [s], n):")
for wn in WATERS:
    s = []
    for band, test in [("loc<0.3", lambda x: x < 0.3), ("loc>=0.3", lambda x: x >= 0.3)]:
        v = [r["tcert_s"] for r in inc if r["water"] == wn and test(r["loc_m"])]
        s.append(f"{band}: " + (f"median {np.median(v):.1f} (n={len(v)})" if v else "n=0"))
    P(f"  {wn}: " + "; ".join(s))
P("\nHistogram of fine T_cert, Inconclusive 70 (bins [0,1),[1,4),[4,8),[8,12),[12,16),[16,20)):")
edges = [0, 1, 4, 8, 12, 16, 20.01]
h = np.histogram([r["tcert_s"] for r in inc], bins=edges)[0]
P("  " + " ".join(str(x) for x in h))
P("\nRaw opportunity at 10 Mb/s (fine T_cert x 10 Mb/s):")
P(f"  Certified: 200 Mb (25 MB) each")
v = np.array([r["raw_Mb"] for r in inc])
P(f"  Inconclusive 70: median {np.median(v):.0f} Mb, max {v.max():.0f} Mb, sum {v.sum():.0f} Mb; "
  f"cells with >= 40 Mb (>= 4 s): {np.sum(v>=40)}; >= 100 Mb (>= 10 s): {np.sum(v>=100)}")
if "verdict_check1" in rows[0]:
    P("\nCells falsified by the sideways adversary (T_cert must lie below the witness time):")
    for r in rows:
        if r["verdict_check1"] == "Falsified(sideways)":
            P(f"  cell {r['cell']} {r['water']} d0={r['d0_m']:g} loc={r['loc_m']:g} w={r['w_mps']:g}: T_cert {r['tcert_s']:.2f} s")
    P("\nWindow-granular T_cert (Inconclusive 70) by water: " + "; ".join(
        f"{wn} median {np.median([r['tcert_win_s'] for r in inc if r['water']==wn]):.0f} s" for wn in WATERS))
txt = "\n".join(lines)
print(txt)
open(os.path.join(OUT, "tcert_summary.txt"), "w").write(txt + "\n")

# ---------------- figure: map coloured by T_cert ----------------
locs = sorted({float(r["loc_m"]) for r in op}); ws = sorted({float(r["w_mps"]) for r in op})
d0s = {wn: sorted({float(r["d0_m"]) for r in op if r["water"] == wn}) for wn in WATERS}
bounds = [0, 1, 4, 8, 12, 16, 19.99, 20.01]
blues = ["#eef4fb", "#d3e3f6", "#a9c9ee", "#7aaae2", "#4f8bd3", "#2f6cbc", "#16418a"]
cmap = ListedColormap(blues); norm = BoundaryNorm(bounds, cmap.N)
byc = {(r["water"], r["d0_m"], r["loc_m"], r["w_mps"]): r for r in rows}
fig, axs = plt.subplots(2, 3, figsize=(7.0, 4.6), constrained_layout=True)
plt.rcParams.update({"font.size": 7})
for wi, wn in enumerate(WATERS):
    for si, d0 in enumerate(d0s[wn]):
        ax = axs[si, wi]
        for li, lv in enumerate(locs):
            for k, wv in enumerate(ws):
                r = byc.get((wn, d0, lv, wv))
                if r is None:      # not empirically viable
                    ax.add_patch(plt.Rectangle((li, k), 1, 1, fc="white", ec=GRID, lw=0.4))
                    continue
                if r["verdict"] == "Falsified":
                    ax.add_patch(plt.Rectangle((li, k), 1, 1, fc="white", ec=C_FALS, lw=0.8, hatch="////"))
                    continue
                t = r["tcert_s"]
                ax.add_patch(plt.Rectangle((li, k), 1, 1, fc=cmap(norm(t)), ec="white", lw=0.8))
                lab = "20" if t >= 20 else f"{t:.0f}" if t >= 1 else f"{t:.1f}".rstrip("0").rstrip(".") if t > 0 else "0"
                if r.get("verdict_check1") == "Falsified(sideways)":
                    ax.add_patch(plt.Rectangle((li + 0.06, k + 0.06), 0.88, 0.88, fc="none", ec=C_FALS, lw=1.2))
                ax.text(li + 0.5, k + 0.5, lab, ha="center", va="center", fontsize=5.5,
                        color="white" if t >= 12 else INK)
        ax.set_xlim(0, len(locs)); ax.set_ylim(0, len(ws)); ax.set_aspect("equal")
        ax.set_xticks(np.arange(len(locs)) + 0.5); ax.set_xticklabels([f"{x:g}" for x in locs], fontsize=5.5)
        ax.set_yticks(np.arange(len(ws)) + 0.5); ax.set_yticklabels([f"{x:g}" for x in ws], fontsize=5.5)
        ax.tick_params(length=0)
        for s in ax.spines.values():
            s.set_visible(False)
        ax.set_title(f"{wn}, d0 = {d0:g} m", fontsize=7, color=INK)
        if si == 1: ax.set_xlabel("localisation error (m)", fontsize=6, color=INK2)
        if wi == 0: ax.set_ylabel("current bound |w| (m/s)", fontsize=6, color=INK2)
sm = plt.cm.ScalarMappable(cmap=cmap, norm=norm)
cb = fig.colorbar(sm, ax=axs, shrink=0.75, ticks=[0, 1, 4, 8, 12, 16, 20], pad=0.01)
cb.set_label("certified prefix T_cert (s); 20 = Certified", fontsize=6, color=INK2)
cb.ax.tick_params(labelsize=5.5, length=0); cb.outline.set_visible(False)
fig.text(0.01, -0.01, "Hatched: Falsified (T_cert not computed). Orange frame: falsified by the sideways adversary (12j), after T_cert. Blank: Monte Carlo outages (not empirically viable). "
         "T_cert x 10 Mb/s = nominal raw data opportunity.", fontsize=5.5, color=MUTED)
fig.savefig(os.path.join(FIG, "fig_tcert.pdf"), bbox_inches="tight")
fig.savefig(os.path.join(OUT, "fig_tcert.png"), dpi=200, bbox_inches="tight")
print("figure:", os.path.join(FIG, "fig_tcert.pdf"))
