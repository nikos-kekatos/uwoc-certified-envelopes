"""Summarise campaign E (slowly varying current) into results/slowcur/summary.txt.
Run after code/run_slowcur.m: python code/slowcur_summary.py [dir]
Reads slowcur_R0.csv, slowcur_R1.csv, ccv_slowcur_R{0,1}_res_32.csv and their summaries, the
reference CCV (results/ccv/ccv_*_2d_res_32.csv) and campaign C (results/curdisk/) if present."""
import csv, os, sys
from collections import Counter

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'results')
D = sys.argv[1] if len(sys.argv) > 1 else os.path.join(R, 'slowcur')
out = []
def p(*a): out.append(' '.join(str(x) for x in a))
def rd(f):
    if not os.path.exists(f): return None
    with open(f) as fh: return list(csv.DictReader(fh))
def B(x): return str(x).strip().lower() in ('1', 'true')
def F(x):
    try: return float(x)
    except Exception: return float('nan')
def cnt(rows, k): return dict(Counter(r[k] for r in rows))
def fmin(v):
    v = [x for x in v if x == x]
    return min(v) if v else float('nan')

for reg in ['R0', 'R1']:
    T = rd(os.path.join(D, f'slowcur_{reg}.csv'))
    if T is None:
        p(f'{reg}: no results'); continue
    p(f'===== {reg} ({len(T)} jobs) =====')
    for s in ['unresolved67', 'certified_hero', 'certified_a2', 'falsified3']:
        G = [r for r in T if r['set'] == s]
        if not G: continue
        p(f'-- {s}: n={len(G)}, w0=0 carried over {sum(B(r["carried_w0"]) for r in G)}, reach run {sum(B(r["ran"]) for r in G)}')
        p('   verdicts:', cnt(G, 'verdict'))
        I = [r for r in G if r['verdict'] == 'Inconclusive' and not B(r['carried_w0'])]
        if I: p('   inconclusive reasons (w0 > 0):', cnt(I, 'reason'))
        C = [r for r in G if r['verdict'] == 'Certified' and not B(r['carried_w0'])]
        if C: p('   certified by pass (w0 > 0):', cnt(C, 'cert_by'))
        if s == 'unresolved67':
            N = [r for r in G if B(r['near_edge'])]
            p(f'   near-edge ({len(N)}): verdicts {cnt(N, "verdict")}, reasons {cnt([r for r in N if r["verdict"] == "Inconclusive"], "reason")}')
            for r in C:
                p(f'   NEW CERTIFICATE cell {r["cell"]} {r["water"]} d0={r["d0_m"]} loc={r["loc_m"]} w={r["w_mps"]} by {r["cert_by"]} '
                  f'Mlow={F(r["Mlow"]):.2f} MC min rho {F(r["mc_rho"]):.3f} CE found {r["ce_found"]} rho {F(r["ce_rho"]):.3f} '
                  f'sideways found {r["sw_found"]} rho {F(r["sw_rho"]):.3f}')
            for r in [r for r in G if r['verdict'] == 'Falsified']:
                p(f'   NEW WITNESS cell {r["cell"]} {r["water"]} d0={r["d0_m"]} loc={r["loc_m"]} w={r["w_mps"]}: '
                  f'MC {F(r["mc_rho"]):.3f} CE {F(r["ce_rho"]):.3f} sideways {F(r["sw_rho"]):.3f} t {r["sw_tOut"]}')
        if s.startswith('certified'):
            for r in [r for r in G if r['verdict'] != 'Certified']:
                p(f'   LOST under {reg}: cell {r["cell"]} {r["water"]} d0={r["d0_m"]} loc={r["loc_m"]} w={r["w_mps"]} '
                  f'p1 {r["p1_status"]} p2 {r["p2_status"]} p3 {r["p3_status"]} reason {r["reason"]}')
        if s == 'falsified3':
            for r in G:
                p(f'   cell {r["cell"]}: sideways found {r["sw_found"]} rho {F(r["sw_rho"]):.3f} t {r["sw_tOut"]}; CE found {r["ce_found"]} rho {F(r["ce_rho"]):.3f}; MC min rho {F(r["mc_rho"]):.3f}')
    RC = [r for r in T if r['verdict'] == 'Certified' and not B(r['carried_w0'])]
    p(f'   soundness violations: {sum(B(r["soundness_violation"]) for r in T)}; on the {len(RC)} regime-certified w0 > 0 cells, '
      f'min rho: CE {fmin([F(r["ce_rho"]) for r in RC]):.3f}, sideways {fmin([F(r["sw_rho"]) for r in RC]):.3f}, MC {fmin([F(r["mc_rho"]) for r in RC]):.3f}')
    p(f'   reach CPU {sum(F(r["reach_s"]) for r in T):.0f} s, falsifier CPU {sum(F(r["fals_s"]) for r in T):.0f} s')
    if reg == 'R0':
        K = [r for r in T if B(r['ran']) and r['p3_status'] not in ('', None)]
        p(f'   pass 3 (keep dependence on the initial current) run on {len(K)} cells, certified {sum(B(r["p3_cert"]) for r in K)}; '
          f'statuses {dict(Counter(r["p3_status"] for r in K))}')

rows = []
S = rd(os.path.join(R, 'ccv', 'ccv_summary_2d_res_32.csv'))
if S:
    rows += [('reference (box)', r) for r in S if F(r['loc_m']) == 0.1 and r['water'] in ('clear', 'coastal')]
S = rd(os.path.join(R, 'curdisk', 'ccv_summary_curdisk_res_32.csv'))
if S:
    rows += [('campaign C (disk)', r) for r in S if F(r['loc_m']) == 0.1]
for reg in ['R0', 'R1']:
    S = rd(os.path.join(D, f'ccv_summary_slowcur_{reg}_res_32.csv'))
    if S: rows += [(reg, r) for r in S]
p('===== CCV, loc 0.1 m, |w| <= 0.025 m/s =====')
for n, r in rows:
    p(f'{n:20s} {r["water"]:8s} CCV {F(r["CCV"]):6.2f}  EVV {F(r["EVV"]):6.2f}  EVV falsified {F(r["EVV_falsified"]):5.2f}  EVV inconclusive {F(r["EVV_inconclusive"]):5.2f}')
A = rd(os.path.join(R, 'ccv', 'ccv_2d_res_32.csv'))
for reg in ['R0', 'R1']:
    Bt = rd(os.path.join(D, f'ccv_slowcur_{reg}_res_32.csv'))
    if not (A and Bt): continue
    key = lambda r: (r['water'], round(F(r['d0_m']), 3), round(F(r['phi0_deg']), 3))
    ref = {key(r): r for r in A if F(r['loc_m']) == 0.1 and r['water'] in ('clear', 'coastal')}
    tr = Counter(); sv = 0; ch = []
    for r in Bt:
        k = key(r)
        if k not in ref: continue
        tr[(ref[k]['verdict_maint'], r['verdict_maint'])] += 1
        sv += B(r['soundness_violation'])
        if ref[k]['verdict_maint'] != r['verdict_maint']:
            ch.append(f'{k} {ref[k]["verdict_maint"]} -> {r["verdict_maint"]} (ref status {ref[k]["reach_status"]}, {reg} status {r["reach_status"]}, MC outage {r["mc_outage_rate"]})')
    p(f'-- CCV tile transitions reference -> {reg} ({sum(tr.values())} tiles): {dict(tr)}; soundness violations {sv}')
    for c in ch: p('   ' + c)

txt = '\n'.join(out)
with open(os.path.join(D, 'summary.txt'), 'w') as fh: fh.write(txt + '\n')
print(txt)
