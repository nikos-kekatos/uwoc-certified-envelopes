"""Candidate figures (PDF) from saved results. Run from the repository root: python code/make_figures.py
Every number drawn here is read from results/*.csv|.mat produced by the MATLAB scripts."""
import os, sys, csv, json
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Patch
from matplotlib.lines import Line2D
import scipy.io as sio

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "results")
FIG = os.path.join(ROOT, "figures"); os.makedirs(FIG, exist_ok=True)

INK, INK2, MUTED, GRID = "#0b0b0b", "#52514e", "#898781", "#e1e0d9"
C_CERT, C_FALS, C_INC = "#2a78d6", "#eb6834", "#c3c2b7"
C_ROB, C_OP, C_OUT = "#256abf", "#9ec5f4", "#f0efec"
plt.rcParams.update({"font.size": 7, "axes.edgecolor": MUTED, "axes.labelcolor": INK2,
                     "xtick.color": MUTED, "ytick.color": MUTED, "axes.titlesize": 8,
                     "axes.titlecolor": INK, "font.family": "sans-serif"})
WATERS = ["clear", "coastal", "turbid"]


def read_csv(path):
    with open(path) as f:
        return list(csv.DictReader(f))


def fig_ace():
    f = os.path.join(RES, "phase1", "ace_plotdata.mat")
    if not os.path.exists(f):
        return
    D = sio.loadmat(f, squeeze_me=True)
    dg, eg, cls, Mplus = D["dg"], D["eg"], D["cls"], D["Mplus"]
    fig, axs = plt.subplots(1, 3, figsize=(7.1, 2.6), sharey=True, constrained_layout=True)
    from matplotlib.colors import ListedColormap
    cmap = ListedColormap([C_ROB, C_OP, C_OUT])
    for wi, ax in enumerate(axs):
        ax.imshow(cls[wi], origin="lower", extent=[dg[0], dg[-1], eg[0], eg[-1]], aspect="auto",
                  cmap=cmap, vmin=0.5, vmax=3.5, interpolation="nearest")
        ax.contour(dg, eg, Mplus[wi], levels=[0], colors=INK2, linestyles="--", linewidths=0.7)
        B = np.atleast_2d(D["tube"][wi])
        cert = int(np.atleast_1d(D["maint"])[wi])
        if not cert:   # show the tube only while it stays inside ACE_O (b[8] = margin lower bound)
            bad = np.where(B[:, 8] < 0)[0]
            if len(bad): B = B[:bad[0]]
        mask = np.zeros((len(eg), len(dg)), bool)
        for b in B:
            elo, ehi = b[4], b[7]
            emn = elo if elo > 0 else (-ehi if ehi < 0 else 0.0)
            emx = max(abs(elo), abs(ehi))
            mask |= (dg[None, :] >= b[2]) & (dg[None, :] <= b[5]) & \
                    (eg[:, None] >= np.degrees(emn)) & (eg[:, None] <= np.degrees(emx))
        ax.contourf(dg, eg, mask.astype(float), levels=[0.5, 1.5], colors=[(0.1, 0.1, 0.1, 0.28)])
        ax.contour(dg, eg, mask.astype(float), levels=[0.5], colors=INK, linewidths=0.6)
        tcut = B[-1, 1] if len(B) else 0
        X = D["mcX"][wi]
        for k in range(X.shape[1]):
            ax.plot(X[0, k, :], np.degrees(np.abs(X[2, k, :])), color=C_FALS, lw=0.5, alpha=0.6)
        ax.axhline(15, color=INK2, ls=":", lw=0.7)
        ax.set_xlim(dg[0], [11, 7.5, 3][wi]); ax.set_ylim(0, 20)
        st = "certified" if cert else f"not certified; tube to {tcut:.1f} s"
        ax.set_title(f"{WATERS[wi]}, d0 = {np.atleast_1d(D['d0s'])[wi]:g} m\nreach: {st}")
        ax.set_xlabel("separation d (m)")
    axs[0].set_ylabel("pointing error |e| (deg)")
    h = [Patch(color=C_ROB, label="robust (M ≥ 6 dB)"), Patch(color=C_OP, label="operational (0 ≤ M < 6 dB)"),
         Patch(facecolor=C_OUT, edgecolor=MUTED, label="outage"),
         Line2D([], [], color=INK2, ls="--", label="M = 0 at c + 10 %"),
         Line2D([], [], color=INK2, ls=":", label="Tx cone 15°"),
         Patch(color=(0.1, 0.1, 0.1, 0.3), label="CORA reachable tube"),
         Line2D([], [], color=C_FALS, label="sampled trajectories")]
    fig.legend(handles=h, loc="outside lower center", ncol=4, frameon=False, fontsize=6.5)
    fig.savefig(os.path.join(FIG, "fig2_ace_regions.pdf"))
    plt.close(fig)


def fig_map(tag, e0=5.0):
    f = os.path.join(RES, "phase4", f"grid_{tag}.csv")
    if not os.path.exists(f):
        return
    R = read_csv(f)
    locs = sorted({float(r["loc_m"]) for r in R}); curs = sorted({float(r["w_mps"]) for r in R})
    d0s = sorted({float(r["d0_m"]) for r in R})
    col = {"Certified": C_CERT, "Falsified": C_FALS, "Inconclusive": C_INC}
    let = {"Certified": "C", "Falsified": "F", "Inconclusive": "I"}
    fig, axs = plt.subplots(3, len(d0s), figsize=(7.1, 5.0), constrained_layout=True, sharex=True, sharey=True)
    for wi, wname in enumerate(WATERS):
        for di, d0 in enumerate(d0s):
            ax = axs[wi, di]
            for r in R:
                if r["water"] != wname or float(r["d0_m"]) != d0 or abs(float(r["e0_deg"]) - e0) > 1e-6:
                    continue
                i = locs.index(float(r["loc_m"])); j = curs.index(float(r["w_mps"]))
                v = r["verdict_maint"]
                ax.add_patch(Rectangle((i, j), 0.94, 0.94, facecolor=col[v], edgecolor="white", lw=1.5))
                tc = "white" if v != "Inconclusive" else INK
                mc = float(r["mc_outage_rate"]) * 100
                prov = r["provenance"] if v != "Certified" else ""
                ax.text(i + 0.47, j + 0.70, let[v], ha="center", va="center", color=tc, fontsize=7.5, weight="bold")
                ax.text(i + 0.47, j + 0.42, f"MC {mc:.0f}%", ha="center", va="center", color=tc, fontsize=4.8)
                if prov:
                    ax.text(i + 0.47, j + 0.18, prov, ha="center", va="center", color=tc, fontsize=4.8)
            ax.set_xlim(0, len(locs)); ax.set_ylim(0, len(curs))
            ax.set_xticks(np.arange(len(locs)) + 0.47, [f"{l:g}" for l in locs])
            ax.set_yticks(np.arange(len(curs)) + 0.47, [f"{c:g}" for c in curs])
            ax.tick_params(length=0)
            for s in ax.spines.values():
                s.set_visible(False)
            if wi == 0:
                ax.set_title(f"d0 = {d0:g} m")
            if di == 0:
                ax.set_ylabel(f"{wname}\ncurrent bound (m/s)")
            if wi == 2:
                ax.set_xlabel("localisation error (m)")
    h = [Patch(color=C_CERT, label="C: Certified (CORA, G[0,20 s] ACE_O)"),
         Patch(color=C_FALS, label="F: Falsified (concrete trajectory)"),
         Patch(color=C_INC, label="I: Inconclusive")]
    fig.legend(handles=h, loc="outside lower center", ncol=3, frameon=False, fontsize=6.5)
    fig.suptitle(f"Operating map, actor {tag}, |e0| ≤ {e0:g}°; cell text: Monte Carlo outage rate and provenance",
                 fontsize=7.5, color=INK2)
    fig.savefig(os.path.join(FIG, f"fig4_operating_map_{tag}_e0_{e0:g}.pdf"))
    plt.close(fig)


def fig_opmap(tag="res_32"):
    """Hero figure: water x localisation error x current; verdicts, Monte Carlo
    apparent-success region (0 sampled outages) outlined, dominant ACE term."""
    f = os.path.join(RES, "opmap", f"opmap_{tag}.csv")
    if not os.path.exists(f):
        return
    R = read_csv(f)
    locs = sorted({float(r["loc_m"]) for r in R}); curs = sorted({float(r["w_mps"]) for r in R})
    col = {"Certified": C_CERT, "Falsified": C_FALS, "Inconclusive": C_INC}
    fig, axs = plt.subplots(2, 3, figsize=(7.1, 5.2), constrained_layout=True, sharex=True, sharey=True)
    for wi, w in enumerate(WATERS):
        for k in (1, 2):
            ax = axs[k - 1, wi]
            rr = [r for r in R if r["water"] == w and int(float(r["range_class"])) == k]
            if not rr:
                ax.set_visible(False); continue
            app = np.zeros((len(curs), len(locs)))
            for r in rr:
                i = locs.index(float(r["loc_m"])); j = curs.index(float(r["w_mps"]))
                v = r["verdict_maint"]
                ax.add_patch(Rectangle((i - 0.5, j - 0.5), 1, 1, facecolor=col[v], edgecolor="white", lw=1.2))
                app[j, i] = 1.0 if float(r["mc_outage_rate"]) == 0 else 0.0
                pv = r["provenance"] if v != "Certified" else ""
                pv = {"P": "Pw", "Tx": "Tx", "Rx": "Rx"}.get(pv, pv.replace("+", "/") if pv else "")
                pv = {"Tx/Rx/P": "all", "Tx/P": "T/P", "Rx/P": "R/P", "Tx/Rx": "T/R"}.get(pv, pv)
                ax.text(i, j, pv, ha="center", va="center", fontsize=6.2, fontweight="bold",
                        color="white" if v == "Falsified" else INK)
            if app.any() and not app.all():
                ax.contour(np.arange(len(locs)), np.arange(len(curs)), app, levels=[0.5],
                           colors=INK, linewidths=1.6)
            ax.set_xlim(-0.5, len(locs) - 0.5); ax.set_ylim(-0.5, len(curs) - 0.5)
            ax.set_xticks(range(len(locs)), [f"{l:g}" for l in locs], rotation=45)
            ax.set_yticks(range(len(curs)), [f"{c:g}" for c in curs]); ax.tick_params(length=0)
            for sp in ax.spines.values():
                sp.set_visible(False)
            ax.set_title(f"{w}, d0 = {float(rr[0]['d0_m']):g} m ({'near' if k == 1 else 'far'})")
            if k == 2: ax.set_xlabel("localisation error bound (m)")
            if wi == 0: ax.set_ylabel("current bound (m/s)")
    h = [Patch(color=C_CERT, label="Certified"), Patch(color=C_FALS, label="Falsified"),
         Patch(color=C_INC, label="Inconclusive"),
         Line2D([], [], color=INK, lw=1.6, label="Monte Carlo apparent-success boundary (0 outages / N)")]
    fig.legend(handles=h, loc="outside lower center", ncol=4, frameon=False, fontsize=6.3)
    fig.savefig(os.path.join(FIG, f"fig_hero_opmap_{tag}.pdf"))
    plt.close(fig)


def fig_ccv(tag="2d_res_32", suffix="", wlab="0.025"):
    """CCV (certified) vs EVV (Monte Carlo apparent success) vs localisation error."""
    f = os.path.join(RES, "ccv", f"ccv_summary_{tag}.csv")
    if not os.path.exists(f):
        return
    R = read_csv(f)
    # A3 adds the intermediate localisation bounds (0.15 / 0.2 / 0.25 m, box model) to the
    # main planar curve; rows already present in the main summary are not duplicated.
    fa3 = os.path.join(RES, "ccv", "ccv_summary_a3_box_res_32.csv")
    if tag == "2d_res_32" and os.path.exists(fa3):
        have = {(r["water"], float(r["loc_m"])) for r in R}
        R += [r for r in read_csv(fa3) if (r["water"], float(r["loc_m"])) not in have]
    fig, axs = plt.subplots(1, 3, figsize=(7.1, 2.3), constrained_layout=True, sharey=False)
    for wi, w in enumerate(WATERS):
        ax = axs[wi]
        rr = sorted([r for r in R if r["water"] == w], key=lambda r: float(r["loc_m"]))
        x = [float(r["loc_m"]) for r in rr]
        ax.plot(x, [float(r["EVV"]) for r in rr], marker="o", color=C_FALS, lw=2, ms=5, label="MC apparent success (EVV)")
        ax.plot(x, [float(r["CCV"]) for r in rr], marker="s", color=C_CERT, lw=2, ms=5, label="certified (CCV)")
        ax.plot(x, [float(r["EVV_falsified"]) for r in rr], marker="^", color=INK2, lw=1.2, ms=4, ls="--",
                label="EVV part falsified")
        ax.set_title(w); ax.set_xlabel("localisation error bound (m)"); ax.grid(color=GRID, lw=0.5)
        ax.set_ylim(bottom=0)
        if wi == 0:
            ax.set_ylabel("start area (m²)")
    axs[0].legend(frameon=False, fontsize=6)
    fig.savefig(os.path.join(FIG, f"fig_ccv_vs_loc{suffix}.pdf"))
    plt.close(fig)


def fig_ladder(tag="res_32"):
    """False assurance across the model ladder (Wilson 95 % CI) and volume per rung."""
    f = os.path.join(RES, "summary_v1.json")
    if not os.path.exists(f):
        return
    S = json.load(open(f)).get("ladder_ccv")
    if not S:
        return
    fig, axs = plt.subplots(1, 2, figsize=(7.1, 2.5), constrained_layout=True)
    scopes = [s for s in ["clear", "coastal", "turbid", "all"] if s in S]
    keys = [("P_2Dcert_and_6DOFfalsified", "2D certified, 6-DOF falsified", C_FALS),
            ("P_3Dcert_and_6DOFfalsified", "3D certified, 6-DOF falsified", C_CERT),
            ("P_2Dcert_and_3Dfalsified", "2D certified, 3D falsified", INK2)]
    xb = np.arange(len(scopes)); wbar = 0.26
    for ki, (k, lab, c) in enumerate(keys):
        vals = [S[s][k] for s in scopes]
        p = [v[0] if v[0] is not None else 0 for v in vals]
        lo = [p[i] - (v[1] if v[1] is not None else 0) for i, v in enumerate(vals)]
        hi = [(v[2] if v[2] is not None else 0) - p[i] for i, v in enumerate(vals)]
        axs[0].bar(xb + (ki - 1) * wbar, [100 * q for q in p], wbar * 0.9, color=c, label=lab,
                   yerr=[[100 * q for q in lo], [100 * q for q in hi]], error_kw=dict(ecolor=INK, lw=0.7, capsize=2))
    axs[0].set_xticks(xb, [f"{s}\n(n2={S[s]['n_2d_certified_tiles']}, n3={S[s]['n_3d_certified_tiles']})" for s in scopes], fontsize=6)
    axs[0].set_ylabel("false-assurance rate (%)"); axs[0].set_ylim(0, 105); axs[0].grid(axis="y", color=GRID, lw=0.5)
    axs[0].legend(frameon=False, fontsize=5.8)
    vk = [("CCV_2D_projected_m3", "2D certified", C_FALS), ("CCV_3D_m3", "3D certified", C_CERT),
          ("CCV_3D_not_6DOF_falsified_m3", "3D cert., no 6-DOF witness", "#1baf7a"), ("EVV_6DOF_m3", "6-DOF MC viable", INK2)]
    ws = [s for s in ["clear", "coastal", "turbid"] if s in S]
    xb = np.arange(len(ws)); wbar = 0.2
    for ki, (k, lab, c) in enumerate(vk):
        axs[1].bar(xb + (ki - 1.5) * wbar, [S[s][k] for s in ws], wbar * 0.9, color=c, label=lab)
    axs[1].set_xticks(xb, ws); axs[1].set_ylabel("start volume (m³)"); axs[1].grid(axis="y", color=GRID, lw=0.5)
    axs[1].legend(frameon=False, fontsize=5.8)
    fig.savefig(os.path.join(FIG, f"fig_ladder_{tag}.pdf"))
    plt.close(fig)


def fig_shield():
    """S5 ablation: outage rate (Wilson 95 % CI) per test row and controller, and
    decision time per check."""
    f = os.path.join(RES, "shield", "s5_ablation.csv")
    if not os.path.exists(f):
        return
    R = read_csv(f)
    rows = list(dict.fromkeys(r["row"] for r in R)); ctr = list(dict.fromkeys(r["controller"] for r in R))
    pal = {"classical": "#898781", "NN": INK, "NN+clip": "#eda100", "NN+M(sway)": "#1baf7a",
           "L(old)": "#e87ba4", "L(sway)": C_CERT, "L(sway)+M": "#4a3aa7", "O(old)": C_FALS, "O(sway)": "#008300"}
    fig, axs = plt.subplots(1, 2, figsize=(7.1, 2.9), constrained_layout=True, gridspec_kw={"width_ratios": [3.2, 1]})
    ax = axs[0]; w = 0.8 / len(ctr)
    for ci, c in enumerate(ctr):
        xs, ps, lo, hi = [], [], [], []
        for ri, rw in enumerate(rows):
            r = [q for q in R if q["row"] == rw and q["controller"] == c][0]
            p = float(r["outage_rate"]); xs.append(ri - 0.4 + (ci + 0.5) * w); ps.append(100 * p)
            lo.append(100 * (p - float(r["ci_lo"]))); hi.append(100 * (float(r["ci_hi"]) - p))
        ax.errorbar(xs, ps, yerr=[lo, hi], fmt="o", ms=3.2, color=pal.get(c, INK2), ecolor=pal.get(c, INK2),
                    elinewidth=0.8, capsize=1.5, label=c)
    ax.set_xticks(range(len(rows)), [r.replace("_", " ") for r in rows])
    ax.set_ylabel("outage rate (%)  [Wilson 95 % CI]"); ax.grid(axis="y", color=GRID, lw=0.5); ax.set_ylim(bottom=-2)
    hs, ls = ax.get_legend_handles_labels()
    fig.legend(hs, ls, frameon=False, fontsize=6, ncol=9, loc="outside lower center")
    ax2 = axs[1]
    dt = [(c, float(next(q for q in R if q["controller"] == c and q["decision_mean_s"] not in ("", "NaN"))["decision_mean_s"]))
          for c in ctr if any(q["controller"] == c and q["decision_mean_s"] not in ("", "NaN") for q in R)]
    ax2.barh([d[0] for d in dt], [1000 * d[1] for d in dt], color=[pal.get(d[0], INK2) for d in dt])
    ax2.axvline(500, color=INK2, ls="--", lw=0.8); ax2.text(500, -0.6, " 0.5 s period", fontsize=5.5, color=INK2)
    ax2.set_xscale("log"); ax2.set_xlabel("decision time per check (ms)"); ax2.tick_params(axis="y", labelsize=6)
    fig.savefig(os.path.join(FIG, "fig_shield_ablation.pdf"))
    plt.close(fig)


def fig_tornado():
    """B1: one-at-a-time hardware knobs -> % change in certified (CCV) and empirically
    viable (EVV) start area vs the baseline, per water type (near + far slices summed)."""
    f = os.path.join(RES, "b1", "b1_slices.csv")
    if not os.path.exists(f):
        return
    R = read_csv(f)
    knobs = [("Rx FOV", "FOV20", "FOV45", "20°", "45°"), ("Tx half-angle Φ½", "Phi10", "Phi30", "10°", "30°"),
             ("sensitivity P_min", "Pmin_m3", "Pmin_p3", "−3 dB", "+3 dB")]
    def tot(var, w, key):
        return sum(float(r[key]) for r in R if r["variant"] == var and r["water"] == w)
    fig, axs = plt.subplots(1, 2, figsize=(7.1, 2.3), constrained_layout=True, sharey=True)
    for ax, w in zip(axs, ["clear", "coastal"]):
        b = tot("base", w, "CCV_m2"); be = tot("base", w, "EVV_m2")
        for k, (lab, lo, hi, llo, lhi) in enumerate(knobs):
            for var, txt, col in [(lo, llo, C_FALS), (hi, lhi, C_CERT)]:
                v = 100 * (tot(var, w, "CCV_m2") - b) / max(b, 1e-9)
                ve = 100 * (tot(var, w, "EVV_m2") - be) / max(be, 1e-9)
                ax.barh(k, v, height=0.55, color=col, alpha=0.9)
                ax.plot([ve], [k], marker="|", ms=11, mew=1.6, color=INK)
                ax.text(v + (3 if v >= 0 else -3), k + (0.2 if var == lo else -0.2), txt, fontsize=6,
                        ha="left" if v >= 0 else "right", va="center", color=INK2)
        ax.axvline(0, color=INK2, lw=0.8)
        lo_x, hi_x = ax.get_xlim(); ax.set_xlim(lo_x - 0.12 * (hi_x - lo_x), hi_x + 0.12 * (hi_x - lo_x))
        ax.set_yticks(range(len(knobs)), [k[0] for k in knobs]); ax.set_title(f"{w}: base CCV {b:.1f} m², EVV {be:.1f} m²")
        ax.set_xlabel("change vs baseline (%)"); ax.grid(axis="x", color=GRID, lw=0.5)
    h = [Patch(color=C_FALS, label="lower setting (CCV)"), Patch(color=C_CERT, label="higher setting (CCV)"),
         Line2D([], [], marker="|", ls="", color=INK, ms=10, label="EVV change")]
    fig.legend(handles=h, loc="outside lower center", ncol=3, frameon=False, fontsize=6.3)
    fig.savefig(os.path.join(FIG, "fig_b1_tornado.pdf"))
    plt.close(fig)


def fig_area(tags, prefix="area_", suffix=""):
    """Certified start tiles around the receiver (planar analogue of V_cert)."""
    files = [(t, os.path.join(RES, "cert_area", f"{prefix}{t}.csv")) for t in tags]
    files = [(t, f) for t, f in files if os.path.exists(f)]
    if not files:
        return
    col = {"Certified": C_CERT, "Falsified": C_FALS, "Inconclusive": C_INC}
    fig, axs = plt.subplots(len(files), 3, figsize=(7.1, 2.0 * len(files) + 0.4), squeeze=False,
                            constrained_layout=True)
    for ti, (tag, f) in enumerate(files):
        R = read_csv(f)
        for wi, w in enumerate(WATERS):
            ax = axs[ti, wi]
            tot = {"Certified": 0.0, "Falsified": 0.0, "Inconclusive": 0.0}
            for r in R:
                if r["water"] != w:
                    continue
                d0 = float(r["d0_m"]); ph = np.radians(float(r["phi0_deg"]))
                hd, hp = 0.25, np.radians(5)
                th = np.linspace(ph - hp, ph + hp, 8)
                xs = np.r_[(d0 - hd) * np.cos(th), (d0 + hd) * np.cos(th[::-1])]
                ys = np.r_[(d0 - hd) * np.sin(th), (d0 + hd) * np.sin(th[::-1])]
                ax.fill(xs, ys, color=col[r["verdict_maint"]], lw=0.3, ec="white")
                tot[r["verdict_maint"]] += float(r["area_m2"])
            ax.plot([0], [0], marker="s", color=INK, ms=4)
            ax.set_aspect("equal"); ax.set_xlim(-0.5, 16.5); ax.set_ylim(-9, 9)
            ax.set_title(f"{tag}, {w}: A_cert = {tot['Certified']:.1f} m²", fontsize=7)
            if ti == len(files) - 1:
                ax.set_xlabel("x (m), receiver at origin facing +x")
    h = [Patch(color=C_CERT, label="Certified"), Patch(color=C_FALS, label="Falsified"),
         Patch(color=C_INC, label="Inconclusive")]
    fig.legend(handles=h, loc="outside lower center", ncol=3, frameon=False, fontsize=6.5)
    fig.savefig(os.path.join(FIG, f"fig_cert_area{suffix}.pdf"))
    plt.close(fig)


def fig_size():
    f = os.path.join(RES, "cert_area", "size_study_summary.csv")
    if not os.path.exists(f):
        return
    R = read_csv(f)
    fig, axs = plt.subplots(1, 3, figsize=(7.1, 2.2), constrained_layout=True)
    for arch, c, mk in [("mlp", C_FALS, "o"), ("res", C_CERT, "s")]:
        rr = sorted([r for r in R if r["arch"] == arch], key=lambda r: float(r["width"]))
        x = [float(r["width"]) for r in rr]
        axs[0].plot(x, [float(r["A_cert_clear_m2"]) + float(r["A_cert_coastal_m2"]) + float(r["A_cert_turbid_m2"]) for r in rr],
                    marker=mk, color=c, lw=2, ms=5, label="MLP" if arch == "mlp" else "residual MLP")
        axs[1].plot(x, [float(r["reach_time_total_s"]) / 60 for r in rr], marker=mk, color=c, lw=2, ms=5)
        axs[2].plot(x, [100 * float(r["inconclusive_rate_live"]) for r in rr], marker=mk, color=c, lw=2, ms=5)
    for ax, yl in zip(axs, ["certified start area A_cert (m²)", "total reach time (CPU min)", "inconclusive (% of reach runs)"]):
        ax.set_xscale("log", base=2); ax.set_xticks([16, 32, 64, 256], ["16", "32", "64", "256"])
        ax.set_xlabel("hidden width (2 layers)"); ax.set_ylabel(yl); ax.grid(color=GRID, lw=0.5)
        ax.set_ylim(bottom=0)
    axs[0].legend(frameon=False, fontsize=6.5)
    fig.savefig(os.path.join(FIG, "fig_size_study.pdf"))
    plt.close(fig)


def fig_retrain():
    f = os.path.join(RES, "retrain", "retrain_summary.csv")
    if not os.path.exists(f):
        return
    R = read_csv(f)
    actors = list(dict.fromkeys(r["actor"] for r in R))
    fig, ax = plt.subplots(figsize=(3.5, 2.2), constrained_layout=True)
    x = np.arange(len(actors))
    a = [sum(float(r["A_cert_m2"]) for r in R if r["actor"] == t) for t in actors]
    cols = [INK2 if "r0" in t else (C_CERT if "vg" in t else C_FALS) for t in actors]
    ax.bar(x, a, color=cols, width=0.6)
    for xi, v in zip(x, a):
        ax.text(xi, v, f"{v:.1f}", ha="center", va="bottom", fontsize=6, color=INK2)
    ax.set_xticks(x, [t.split("_")[-1] for t in actors]); ax.set_ylabel("A_cert, clear + coastal (m²)")
    ax.set_title("verification-guided (vg) vs ordinary (ord) retraining", fontsize=7)
    ax.grid(axis="y", color=GRID, lw=0.5)
    fig.savefig(os.path.join(FIG, "fig_retrain.pdf"))
    plt.close(fig)


def table_ood(tag="res_32"):
    f = os.path.join(RES, "phase6", f"ood_shield_{tag}.csv")
    if not os.path.exists(f):
        return
    R = read_csv(f)
    lines = [f"% generated by make_figures.py from results/phase6/ood_shield_{tag}.csv",
             "\\begin{tabular}{@{}llcccc@{}}", "\\toprule",
             "Controller & $w$ & Outage & Robust time & Interventions & Effort \\\\", "\\midrule"]
    for r in R:
        iv = "n/a" if r["controller"] in ("classical", "NN") else f"{100*float(r['intervention_rate']):.1f}\\%"
        lines.append(f"{r['controller']} & {float(r['w_factor']):.2f}$w$ & {100*float(r['outage_rate']):.1f}\\% & "
                     f"{100*float(r['robust_time_frac']):.1f}\\% & {iv} & {float(r['effort']):.2f} \\\\")
    lines += ["\\bottomrule", "\\end{tabular}"]
    open(os.path.join(FIG, f"table2_ood_{tag}.tex"), "w").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    fig_ace()
    tags = sys.argv[1:] or ["res_32"]
    for t in tags:
        for e0 in [2, 5, 10, 15]:
            fig_map(t, e0)
    fig_area(["res_32", "mlp_32"])
    fig_area(["res_32", "mlp_32"], prefix="area_mild_", suffix="_mild")
    fig_size(); fig_retrain(); table_ood(); fig_opmap()
    fig_ccv("2d_res_32"); fig_ccv("2d_w005_res_32", "_w005", "0.05"); fig_ladder(); fig_shield(); fig_tornado()
    print("figures in", FIG)
