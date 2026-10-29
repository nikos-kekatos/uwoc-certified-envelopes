# Certified operating envelopes for AI-controlled mobile underwater optical links

Code, trained controllers and raw results for the paper

> N. Kekatos, A. Lekidis, S. Petridou, P. Katsaros, S. Basagiannis.
> *Verified Operating Envelopes for Reliable AI-Controlled Underwater Optical Links.*
> Under review.

**Question.** Where, across water type, current, separation and navigation error, is an
AI-controlled mobile underwater wireless optical communication (UWOC) link *guaranteed*
to hold? Two AUVs are considered, one steering a narrow optical beam at the other with a
neural beam-alignment controller (`res_32`, residual MLP 2x32 ReLU, surge-speed and
yaw-rate commands). The link is required to stay in the Assured Communication Envelope
ACE = Tx cone ∩ Rx field of view ∩ received power ≥ P_min (P_min = −31.49 dBm for
OOK-NRZ at 10 Mb/s, BER 1e-6).

For each operating cell the pipeline combines

- **closed-loop reachability** with CORA (polynomial zonotopes, neural network in the loop)
  on a planar and a reduced 3-D model of a BlueROV2-class vehicle,
- **falsification** (Monte Carlo and cross-entropy / structured adversaries) on the same
  models and on a 6-DOF Fossen model, and
- a **runtime shield** (precomputed lookup with a certified fallback) as a secondary result.

## Verdict semantics

| Verdict | Meaning |
|---|---|
| **Certified** | CORA's sound over-approximation of every closed-loop trajectory stays in the ACE over [0, 20 s]. Conditional on the model in `code/MODEL.md` and on the declared bounds. |
| **Falsified** | A concrete simulated trajectory inside the same declared bounds leaves the ACE (demonstrated false assurance). |
| **Inconclusive** | Neither (unresolved). Not evidence of failure; typical causes are set explosion, the over-approximation touching the ACE boundary, or leaving the asserted damping-model envelope (`model-range`). |

Monte Carlo rates are sampled frequencies, never assurance ("apparent success" = 0
outages in N runs). The 2-D and 3-D rungs are verified with CORA; **the 6-DOF rung is
falsification only**. In every run no Certified cell has a concrete witness
(`soundness_violation` = 0).

Headline (all conditional on the model and bounds; `results/RESULTS.md` §3, §12a, §12j, §12n):
of 294 operating cells, 130 show no outage in 500 Monte Carlo runs; of these, after
refinement and structured falsification (sideways and constant-current adversaries),
32 are Certified, 32 Falsified and 66 remain unresolved.

## Requirements

**MATLAB** R2025a with
- Deep Learning Toolbox (actor training, `trainnet`),
- Parallel Computing Toolbox (`parfor`, process pool of 10 workers),
- Symbolic Math Toolbox and Optimization Toolbox (required by CORA),
- Statistics and Machine Learning Toolbox.

The Robust Control Toolbox and the MATLAB ONNX converter are not needed.

**CORA** v2026.1.0, git `904a4442e68b1dc149a34e917dd63a7d3fb49a3a`
(<https://github.com/TUMcps/CORA>). Tell the code where it is with the environment
variable `CORA_PATH`; if unset, `<userpath>/CORA` is used (`~/Documents/MATLAB/CORA` on
macOS). See `code/uwoc_params.m` and `code/setup_paths.m`.

```bash
git clone https://github.com/TUMcps/CORA.git ~/Documents/MATLAB/CORA
git -C ~/Documents/MATLAB/CORA checkout 904a4442e68b1dc149a34e917dd63a7d3fb49a3a
export CORA_PATH=~/Documents/MATLAB/CORA      # optional if this default location is used
```

**Python** 3.14 (3.10+ should work) for summaries, figures and the ONNX export:

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt               # matplotlib, numpy, scipy, onnx
```

The reference results were produced on a 12-core Apple Silicon machine with 10 MATLAB
workers.

## Quick start

All commands run from the repository root.

```bash
# figures and summaries from the distributed raw results (seconds, no MATLAB needed)
python code/analyze_v1.py          # -> results/summary_v1.json
python code/make_figures.py        # -> figures/*.pdf

# main MATLAB pipeline (about 4 h on 10 workers)
matlab -batch "addpath('code'); run_all"

# ONNX export of the deployed actor and numerical check against MATLAB
python code/export_onnx.py res_32  # -> models/actor_res_32.onnx, models/onnx_check_res_32.json
```

`run_all` starts with `run_phase2_train`, which regenerates the teacher data and
re-trains all actors into `results/phase2/`. To reuse the distributed actors instead,
run the later steps of `run_all.m` individually, e.g.
`matlab -batch "addpath('code'); actorTag='res_32'; run_operating_map"`.
Workspace variables such as `actorTag`, `ccvModel`, `ccvTag` and `ccvLocs` select the
variant; the defaults are documented at the top of each script. Run logs go to
`results/logs/`.

## What reproduces what

Section numbers refer to `results/RESULTS.md`. Wall times are from the reference run
(10 workers unless stated).

| RESULTS.md | Result | Script(s) (in `code/`) | Output (in `results/` unless stated) | Paper figure | Wall time |
|---|---|---|---|---|---|
| §1 | calibration, link budget, P_min | `uwoc_params.m`, `run_phase1_ace.m` | `phase1/link_budget.csv`, `phase1/ace_ranges.csv` | | minutes |
| §2–3 | operating envelope map (3 waters × 2 separations × 7 localisation × 7 current = 294 cells) | `run_operating_map.m` | `opmap/opmap_res_32.csv/.mat` | `figures/fig_hero_opmap_res_32.pdf` | 560 s |
| §4 | ACE regions with reachable tubes | `run_phase1_ace.m`, `make_figures.py` | `phase1/ace_plotdata.mat`, `phase1/ace_tubes.mat` | `figures/fig2_ace_regions.pdf` | minutes |
| §5 | certified communication volume (CCV) vs empirical viable volume, 2-D and 3-D | `run_ccv.m` (`ccvModel='2d'` / `'3d'`) | `ccv/ccv_2d_res_32.*`, `ccv/ccv_3d_res_32.*`, `ccv/ccv_summary_*.csv` | `figures/fig_ccv_vs_loc.pdf`, `figures/fig_ccv_vs_loc_w005.pdf` | 3,121 s (2-D), 5,657 s (3-D) |
| §6 | abstraction ladder 2D → 3D → 6-DOF, false-assurance rates and mechanisms | `run_ladder_ccv.m`, `run_ladder.m`, `run_consistency_check.m` | `ladder/*.csv/.mat`, `summary_v1.json` | `figures/fig_ladder_res_32.pdf` | 616 s (levels) |
| §7 | runtime shield S1–S5 | `run_phase6_shield.m`, `run_shield_tables.m`, `run_shield_v2.m` (driver `run_chain_shield.m`) | `phase6/`, `shield/table_*.csv/.mat`, `shield/s5_ablation.csv`, `shield/s5_raw.mat` | `figures/fig_shield_ablation.pdf` | 12,820 s (tables), 2,875 s (ablation) |
| §8 | deployed network, ONNX, actor width | `export_actor_json.m`, `export_onnx.py`, `run_phase2_train.m`, `run_width_obs.m` | `models/`, `phase2/*.csv`, `ccv/ccv_2d_loc01_*.csv` | | 6.5–10.6 k CPU s per actor |
| §12a | A2: refining the Inconclusive cells | `run_a2_inconclusive.m` (driver `run_chain_next.m`) | `a2/a2_inconclusive.csv/.mat` | | 3,673 s |
| §12b | A1: Monte Carlo budget (5,000 / 50,000 runs) | `run_a1_mc_budget.m` | `a1/a1_mc_budget.csv` | | |
| §12c | classical pointing-and-tracking baseline | `run_baseline_pat.m`; teacher EVV via `run_ccv.m` (`actorTag='teacher'`) | `baseline/baseline_pat.csv`, `ccv/ccv_2d_loc01_empirical_teacher.*` | | |
| §12d | B1: hardware sweep | `run_b1_slices.m`, `link_variant.m` (driver `run_chain_next2.m`) | `b1/b1_slices.csv` | `figures/fig_b1_tornado.pdf` | 1,463 s |
| §12e | A3: localisation cliff, box vs disk | `run_ccv.m` with `ccvTag='a3_box'` / `'a3_disk'` (driver `run_chain_next2.m`) | `ccv/ccv_summary_a3_*.csv` | | 2,653 s + 1,990 s |
| §12f | sway fallback re-certified | `run_shield_table_sway_v2.m`, `run_shield_sway_v2_eval('v1log')`, `run_shield_sway_v2_eval('v2')`, `sway_v2_noncert_geometry.py` | `shield/table_sway_v2*.csv/.mat`, `shield/sway_v2_*` | | 8,755 s (table) |
| §12g | coastal teacher vs `res_32` | `run_coastal_diag.m`, `coastal_join.py`, `coastal_summary.py` | `coastal_diag/`, `coastal_diagnosis.md` | | |
| §12h | chained short-window certification | `run_chain_certify.m`, `chain_cell.m`, `diag_chain_growth.m` | `chain/` (see `chain/METHOD.md`) | | 1,159 s |
| §12i | disk-shaped current set | `run_curdisk.m`, `curdisk_summary.py` | `curdisk/` | | 3,981 s + 2,573 s |
| §12j | why unresolved cells stay unresolved: sideways falsifier, drift budget, certified duration | `falsify_sideways.m`, `replay_sideways_witness.m`, `drift_budget.py`, `tcert_analysis.py` | `diag70/` | `figures/fig_tcert.pdf` | 2,745 s (serial) |
| §12k | Rx FOV vs localisation trade-off | `run_fov_loc.m`, `fov_loc_summary.m` | `fov_loc/fov_loc_table.csv`, `ccv/ccv_summary_fov*_res_32.csv` | `figures/fig_fov_loc.pdf` | 8,520 s |
| §12l | B3: sway-capable AI controller `res_32_sway` | `run_b3_train.m`, `run_b3_eval.m`, `b3_summary.py` | `b3/`, `ccv/ccv_*_res_32_sway.*` | | 49 s (training), 2,473 s (evaluation) |
| §12m | assurance co-design table | `run_codesign.m` | `codesign/codesign_table.csv` | `figures/fig_codesign.pdf` | 1,184 s |
| §12n | slowly varying current | `run_slowcur.m`, `test_slowcur.m`, `verify_ccv_witness_slowcur.m`, `replay_slowcur_witness.m`, `slowcur_summary.py` | `slowcur/` (see `slowcur/METHOD.md`) | | ≈ 8,600 s total |

The main pipeline (`run_all.m`) covers §1–§8; the follow-up studies of §12 are run with
the scripts listed. Every constant, with its source and status (verified in the cited
source or assumed scenario/design choice), is in `code/MODEL.md`. The role of each code
file is listed in `code/README.md`.

## Layout

```
code/       MATLAB pipeline and Python analysis/figure scripts; MODEL.md (model and constants)
models/     trained actors (MATLAB .mat: res/mlp 16, 32, 64, 256; res_32_sway),
            deployed res_32 as JSON and ONNX (opset 13) with its numerical check
results/    raw outputs (CSV, MAT, TXT) per study and RESULTS.md (result log)
figures/    paper figures (PDF), regenerated by make_figures.py and the MATLAB summary scripts
DATA.md     data not in the repository (large teacher datasets) and how to regenerate them
```

The `.mat` actors in `models/` are byte-identical copies of `results/phase2/actor_*.mat`,
from which the MATLAB scripts load them.

## Limitations

- **Model scope.** Certificates hold for the planar and reduced 3-D models under the
  declared bounds only; the 6-DOF results are falsification only. Control periods, gains,
  data rate, BER, operating depth, link reserve and all uncertainty bounds are assumed
  scenario/design choices (`code/MODEL.md`).
- **Synthetic link.** The transceiver constants combine three published sources (N'Doye
  et al. 2021, Celik et al. 2020, Jamali et al. 2017) into one coherent but synthetic
  link, not one measured modem. Turbulence, forward-scattering gain, blockage and
  ambient-light direction are not modelled; BlueROV2 added-mass uncertainty is not
  modelled as uncertain.
- **Over-approximation.** Inconclusive regions are large at localisation errors ≥ 0.3 m
  and under vertical uncertainty, caused by set explosion and by the polynomial damping
  surrogate, which is sound only inside its asserted envelope.
- **Search.** Monte Carlo uses 500 (operating map) or 200 (CCV) runs per cell and the
  falsifiers are heuristic: the absence of a witness is not evidence of safety.
- **Verified network.** CORA verified the float64 MATLAB network; the float32 ONNX graph
  matches it to 1.1e-7 but was not itself verified. No second-tool cross-check was run.
- **Shield.** The runtime shield is a secondary result; its certificates cover 4 s
  windows and do not apply when the declared current bound is exceeded.

See `results/RESULTS.md` §10 and §12 for the full discussion.

## Licence

Code: MIT (`LICENSE`). Data (contents of `results/`, `models/` and `figures/`): CC BY 4.0
(`LICENSE-DATA`). If you use this code or data, please cite the paper (`CITATION.cff`).
