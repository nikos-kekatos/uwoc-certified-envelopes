# RESULTS: UWOC formal-assurance experiments (calibrated model "v1")

Generated 2026-10-05, extended 2026-10-06. Every number was produced by a script in `../code/`, and its raw
output is under `results/`. Model and constants, each with its source: `code/MODEL.md`.
Earlier results with provisional (superseded) constants are not distributed.
Figure paths `figures/...` refer to the repository-level `figures/` folder.
This file is the authors' experiment log, lightly edited for publication; section numbers
are kept stable because the README refers to them. Run logs (`logs/...`) and results
marked "archived" are not distributed; logs are regenerated in `results/logs/` on a rerun.

## 0. Semantics (read first)

- **Certified**: CORA's sound over-approximation of every closed-loop trajectory stays
  in ACE_O (no Tx-cone, Rx-FOV or power violation) over [0, 20 s]. The guarantee is
  conditional on the model in MODEL.md and on the declared bounds.
- **Falsified**: a concrete simulated trajectory inside the same declared bounds leaves
  ACE_O (robustness < −0.01 deg/dB). It was found by Monte Carlo (500 runs per cell; 200
  in the CCV tilings) or by the cross-entropy falsifier.
- **Inconclusive**: neither. Not evidence of failure; typical causes are set explosion,
  the over-approximation touching the ACE boundary, or leaving the asserted
  damping-model envelope (`model-range`).
- Monte Carlo rates are sampled frequencies, never assurance. "Apparent success" means
  0 outages in N samples.
- **Rungs**: 2D (planar 3-DOF) and 3D (reduced: depth, heave, boresight pitch offset,
  receiver tilt) are verified with CORA. **6-DOF (BlueROV2 Fossen model) is falsified
  only**: no 6-DOF certificate is claimed.
- Soundness sanity check: in every run, no Certified cell has a concrete witness. The
  `soundness_violation` column is 0 everywhere; certified cells are additionally
  attacked by a shortened falsifier.
- Tooling: CORA v2026.1.0 (git 904a4442e68b1dc149a34e917dd63a7d3fb49a3a), MATLAB R2025a,
  10 workers on a 12-core Apple Silicon machine.
- Main actor: `res_32` (residual MLP, 2x32 ReLU, linear skip). It outputs surge-speed and
  yaw-rate commands (as in Weng et al. JFR 2024), tracked by the vehicle's low-level
  velocity loop.

## 1. Calibration

See `code/MODEL.md` for every constant and its source.
- **Water**: Mobley (1994) Table 3.11 (Petzold): c = 0.151 / 0.398 / 2.190 m⁻¹. The
  values 0.399/2.195 found in some papers are secondary-source values.
- **Transceiver**:
  - 532 nm, 0.1 W Lambertian source with Φ½ = 15° (N'Doye et al., IEEE Access 2021, Table 1);
  - Tx/Rx efficiencies 0.9 (Celik et al., TWC 2020);
  - 1 cm² detector, 30° concentrator FOV (n = 1.52);
  - Si PIN detector, η = 0.8, T = 290 K, R_L = 100 Ω (Jamali et al., PTL 2017).
- **P_min tied to BER**: OOK-NRZ, 10 Mb/s, BER 1e-6, with thermal, background (30 m depth)
  and dark noise: **P_min = −31.49 dBm** (`uwoc_params.m`, `aux_pmin`).
- **Aligned range at M = 0 / M = 6 dB** (`phase1/ace_ranges.csv`):
  - clear 9.30 / 5.99 m;
  - coastal 5.86 / 4.13 m;
  - turbid 2.03 / 1.61 m.
- **Vehicle**: BlueROV2 Heavy (von Benzon et al., JMSE 2022, Table A1).
- **Weng et al. actor size (VERIFIED against the sources)**: JOE 2022
  uses 2 hidden layers of 64; JFR 2024 (sea trials) uses 2 hidden layers of 256, with actions
  [u_c, r_c] of ±0.2 m/s and ±0.2 rad/s at a 0.2 s step. "2x64" is correct for
  the JOE 2022 reference only.

## 2. Gate: first sound CORA results on the calibrated planar model (passed)

Source: `opmap/opmap_res_32.csv`.
- 29 of 294 hero-map cells are Certified, for example:
  - coastal, d0 = 4 m, localisation 0.1 m, |w| ≤ 0.025 m/s: **Certified**, certified margin
    lower bound 4.44 dB. The smallest sampled robustness of the same cell is 4.83, so the
    over-approximation is tight there.
  - clear, d0 = 3 m, localisation 0.05 m, |w| ≤ 0.05 m/s: Certified, lower bound 6.71 dB.
- Certified margin lower bounds range from 1.59 to 9.11 dB. Reach CPU time per cell:
  median 3.4 s, maximum 199 s, total 3801 s. The operating-map run took 560 s wall time
  on 10 workers.
- **Getting there required three modelling decisions**, all documented in MODEL.md:
  1. **Controller interface**: the actor outputs velocity commands tracked by a fast
     low-level loop. With a force-level actor, the calibrated vehicle's near-zero low-speed
     damping (BlueROV2: no linear sway or yaw damping) made every reach set explode, even
     for a linear controller without noise.
  2. **Quadratic damping in CORA**: modelled as X²p(x/X), with the bounded fit error as an
     input and the envelope |x| ≤ X asserted. A smooth √(x²+ε²) form exploded through
     interval Hessians.
  3. **Integration settings**: time step 0.05 s with 8 Taylor terms, because the loop is
     stiff.

  The provisional-model diagnosis (archived) showed the same lesson earlier: saturating,
  gated teachers are not verifiable under measurement noise.

## 3. Hero figure: operating envelope map

Source: `opmap/opmap_res_32.csv|mat`; figure `figures/fig_hero_opmap_res_32.pdf`.
- Layout: three water types × two separations, near and far (0.3 and 0.7 of the aligned
  power range: clear 3 / 6.5 m, coastal 2 / 4 m, turbid 1 / 1.5 m).
- Each panel is a 7 × 7 grid: localisation error {0.05 … 1} m × current {0 … 0.2} m/s,
  with |e0| ≤ 5°, c ±10 %, heading 1°, T = 20 s.
- Each cell shows the verdict and the provenance (Tx / Rx / Pw). The black line is the
  Monte Carlo apparent-success boundary (0 outages in 500 runs).

| Water | Certified | Falsified | Inconclusive |
|---|---|---|---|
| clear | 15 | 41 | 42 |
| coastal | 11 | 63 | 24 |
| turbid | 3 | 87 | 8 |
| all | 29 | 191 | 74 |

- **Assurance gap.** 130 of 294 cells show apparent success, but only 29 of them are
  Certified: 22 % (Wilson 95 % CI 16-30 %). 27 are **Falsified** by the falsifier,
  21 % (15-29 %); these are concrete outage trajectories that 500 Monte Carlo runs did
  not find. Their first violated predicate: Tx 24, power 2, Rx 1. The remaining 74 are
  Inconclusive.
- **Provenance (tested, not assumed).**
  - Falsified cells overall: Rx 122, Tx 67, power 2.
  - Rx-FOV loss dominates once the current is ≥ 0.05 m/s (cells by current
    0.05 / 0.075 / 0.1 / 0.15 / 0.2 m/s: Rx 12 / 17 / 31 / 33 / 29). This is lateral
    drift of the bearing; the policy commands only surge and yaw.
  - The Tx cone dominates at zero or low current and at large localisation error
    (cells at 1 m localisation: Tx 24, Rx 14).
  - The power term binds where the separation approaches the range limit: turbid
    1.5 m, "Pw" in the figure.
- Reach status per cell: complete 28, set explosion 233 (Inconclusive unless a witness
  exists), damping-model envelope left 15, mixed after splitting 12, early stop 6.
  Adaptive splitting (depth 1) was used for non-falsified, non-certified cells.

## 4. Computed ACE regions with reachable tubes

Source: `phase1/ace_plotdata.mat`, `phase1/link_budget.csv`; figure
`figures/fig2_ace_regions.pdf`.
- φ = 0 slice of the ACE regions (robust / operational / outage) in (separation,
  |pointing error|) per water type, at nominal c. It shows the M = 0 contour at c + 10 %,
  the Tx-cone limit (Φ½ = 15°), a CORA tube (localisation 0.1 m, |w| ≤ 0.025 m/s,
  |e0| ≤ 5°) and 30 sampled trajectories.
- Tube results:
  - clear d0 = 4.5 m: Certified, Mlow 7.22 dB;
  - coastal d0 = 3 m: Certified, Mlow 5.86 dB;
  - turbid d0 = 1 m: not certified (set explosion; the tube is drawn up to 2.0 s).

## 5. Certified Communication Volume vs empirical viable volume

Sources:
- 2-D: `ccv/ccv_2d_res_32.csv|mat`, `ccv/ccv_summary_2d_res_32.csv`; figure
  `figures/fig_ccv_vs_loc.pdf`. Wall time 3121 s.
- 3-D: `ccv/ccv_3d_res_32.*`, `ccv/ccv_summary_3d_res_32.csv`. Wall time 5657 s.
- Also kept: the 2-D run at |w| ≤ 0.05 m/s (`ccv/*_2d_w005_*`, figure
  `figures/fig_ccv_vs_loc_w005.pdf`) and a 3-D run with the earlier depth-hold gain
  k_z = 40 (`ccv/*_3d_kz40_*`). In that run every live 3-D cell left the asserted heave
  envelope or exploded (CCV 0), so it is superseded.

**Four categories, used consistently.** Every tile (or cell) falls into one of four
categories:
1. **empirical viability**: 0 sampled outages (EVV);
2. **certified viability**: Certified (CCV), a subset of empirical viability;
3. **demonstrated false assurance**: empirically viable but Falsified;
4. **unresolved territory**: empirically viable but Inconclusive.

EVV = CCV + false-assurance area + unresolved area. Any "gap" is reported as this
decomposition, never as a single percentage.

**Definitions.**
- Tiling: start positions around the receiver, d0 ∈ [1, 12] m in 0.5 m tiles ×
  φ0 ∈ [−30°, 30°] in 10° tiles. In 3-D, add z0 ∈ [−1, 1] m in 0.5 m layers.
- Fixed bounds: |e0| ≤ 5°, |w| ≤ 0.025 m/s, c ± 10 %, heading 1°, T = 20 s. In 3-D also
  vertical current 0.02 m/s, depth-estimate error 0.05 m, boresight pitch offset ±2° and
  Rx tilt ±2°.
- **CCV** = the area (2-D, m²) or volume (3-D, m³) of the Certified tiles.
- **EVV** = the area or volume of the tiles with 0 outages in 200 Monte Carlo runs
  ("apparent success").
- Empirical-to-certified gap = 1 − CCV/EVV; false-assurance volume = the Falsified part of EVV (Sec. 11d).

**Planar certified area vs localisation error** (|w| ≤ 0.025 m/s):

| Water | loc (m) | CCV (m²) | EVV (m²) | False-assurance area (EVV falsified) | EVV inconclusive | Empirical-to-certified gap |
|---|---|---|---|---|---|---|
| clear | 0.05 | 19.5 | 24.9 | 0.52 | 4.8 | 22 % |
| clear | 0.1 | 16.1 | 24.9 | 0.52 | 8.2 | 35 % |
| clear | 0.3 | 0 | 24.9 | 0.92 | 24.0 | 100 % |
| clear | 0.5 | 0 | 24.8 | 1.18 | 23.6 | 100 % |
| coastal | 0.05 | 3.67 | 10.0 | 2.53 | 3.80 | 63 % |
| coastal | 0.1 | 3.27 | 10.2 | 2.99 | 3.95 | 68 % |
| coastal | 0.3 | 0 | 9.08 | 2.09 | 6.98 | 100 % |
| coastal | 0.5 | 0 | 10.1 | 3.49 | 6.61 | 100 % |
| turbid | any | 0 | 0.22 | 0.11-0.22 | | 100 % |

- Certified viability contracts sharply with localisation error and is 0 from 0.3 m on,
  while empirical viability stays flat (about 25 m² clear, about 10 m² coastal). The
  difference is demonstrated false assurance plus unresolved territory (columns above).
- Part of the apparent-success area is Falsified: concrete outage trajectories that the
  200-sample Monte Carlo missed, 0.5-1.2 m² in clear and 2.1-3.5 m² in coastal water.
- Most of the gap is Inconclusive, i.e. noise-driven over-approximation growth; this is
  conservatism, not proof of failure.
- At |w| ≤ 0.05 m/s the certified area is already much smaller: clear 5.2 / 2.5 m² at
  0.05 / 0.1 m, coastal 0, against an EVV of about 20 m² (`ccv_summary_2d_w005_res_32.csv`).

**3-D certified communication volume** (loc 0.1 m):

| Water | CCV (m³) | EVV (m³) | False-assurance volume | Empirical-to-certified gap |
|---|---|---|---|---|
| clear | 25.9 | 39.2 | 7.8 | 34 % |
| coastal | 3.27 | 7.97 | 1.43 | 59 % |
| turbid | 0 | 0 | 0 | |

3-D reach statuses: 180 complete, 288 early stop, 56 set explosion, 16 explosion or
model envelope; 1044 tiles start in outage.

## 6. Abstraction ladder 2D → 3D → 6-DOF: false assurance and mechanisms

Source: `ladder/ladder_ccv_res_32.csv|mat`; summary `summary_v1.json` (`ladder_ccv`);
figure `figures/fig_ladder_res_32.pdf`.

**Method.** The comparison runs on the 3-D tiling of Sec. 5 at loc 0.1 m.
- The 2-D verdict of a 3-D tile is the planar verdict of its (d, φ) tile.
- The 3-D verdict comes from CORA on the reduced 3-D model.
- The 6-DOF rung runs on the BlueROV2 Fossen model: 200 Monte Carlo runs plus
  cross-entropy falsification (8 × 100). It uses the same bounds, plus roll/pitch
  estimate errors of 1° and initial roll/pitch of 2°.
- All inner loops (surge/yaw velocity, sway hold, depth, roll and pitch hold) run in
  continuous time in every rung.
- Wilson 95 % intervals are given in brackets.

**Consistency check of the rungs.** With every 6-DOF-only effect switched off (attitude
noise, initial attitude, Coriolis/Munk coupling, net buoyancy), 0 of 124 3-D-certified
tiles are falsified on the 6-DOF simulator (`code/run_consistency_check.m` →
`ladder/consistency_check.csv`). With the effects on, that run finds witnesses in 27 of
124; the ladder run, with different seeds, finds 28. An earlier run with ZOH-sampled depth and attitude
loops in the 6-DOF simulator (`ladder/ladder_ccv_zoh_*`) gave higher rates
(P(3D cert ∧ 6-DOF fals) = 38.7 %). That was an implementation mismatch, so it is
superseded.

| Scope | n 2-D cert. | P(2D cert ∧ 3D falsified) | P(2D cert ∧ 6-DOF falsified) | n 3-D cert. | P(3D cert ∧ 6-DOF falsified) |
|---|---|---|---|---|---|
| clear | 144 | 25.0 % [18.6, 32.7] | 41.7 % [33.9, 49.8] | 104 | 23.1 % [16.0, 32.1] |
| coastal | 40 | 50.0 % [35.2, 64.8] | 60.0 % [44.6, 73.7] | 20 | 20.0 % [8.1, 41.6] |
| all | 184 | 30.4 % [24.2, 37.4] | 45.7 % [38.6, 52.9] | 124 | 22.6 % [16.1, 30.7] |

Turbid water has no certified tile on either rung.

**Certified volume per rung** (all water types, 3-D tiling, m³):

| Rung | Volume (m³) |
|---|---|
| 2-D certified (projected over the depth band) | 38.8 |
| 3-D certified | 29.2 |
| 3-D certified with no 6-DOF witness | 23.1 |

- The planar certificate therefore over-states the volume that survives 6-DOF
  falsification by 68 % (clear 32.3 → 20.3 m³; coastal 6.5 → 2.8 m³).
- Monte Carlo apparent success: 2-D 70.6 m³, 3-D 47.2 m³, 6-DOF 43.8 m³.

**Mechanisms of the 84 6-DOF witnesses on 2-D- or 3-D-certified tiles.** Attribution
switches one mechanism off and records which switch-offs remove the witness.
- **Depth offset or depth-estimate error is necessary in all 84.** In 34 it is the only
  necessary mechanism. In 46 it is necessary together with the pitch mechanisms
  (boresight pitch offset, initial pitch, pitch-estimate noise). In 4 the receiver tilt
  is also necessary.
- No witness depends on Coriolis/Munk coupling or net buoyancy alone. Effects can be
  redundant, so a single switch-off may not remove a witness.
- First violated predicate: Tx cone 76, power 8.

Mechanism (pitch → Tx misalignment): vertical offset plus pitch error tilt
the line of sight out of the 15° half-power cone. The planar model cannot see this,
and the reduced 3-D model sees it only with a static pitch offset.

**Sensitivity to the vertical uncertainty level** (`ladder/ladder_res_32.csv`,
`summary_v1.json` → `ladder_levels`; wall time 616 s). Inputs: the 29 hero-map cells
certified in 2-D, each lifted to 3-D at three ASSUMED vertical levels (scenario choices):
- L1: depth ±0.1 m, pitch offset 1°, w_v 0.02 m/s, depth error 0.05 m, Rx tilt 1°;
- L2: depth ±0.25 m, 3°, 0.05 m/s, 0.1 m, 3°;
- L3: depth ±0.5 m, 5°, 0.1 m/s, 0.25 m, 5°.

| Level | 3-D Certified / Falsified / Inconclusive | P(2D cert ∧ 3D falsified) | P(2D cert ∧ 6-DOF falsified) | P(3D cert ∧ 6-DOF falsified) |
|---|---|---|---|---|
| L1 | 27 / 0 / 2 | 0 % [0, 11.7] | 0 % [0, 11.7] | 0/27 [0, 12.5] |
| L2 | 0 / 3 / 26 | 10.3 % [3.6, 26.4] | 10.3 % [3.6, 26.4] | n/a (no 3-D certificate) |
| L3 | 0 / 26 / 3 | 89.7 % [73.6, 96.4] | 100 % [88.3, 100] | n/a |

- At L2 the 3-D rung cannot certify anything. The reason is the over-approximation, not
  evidence of failure: of the 29 cells, 24 reach-set explosions and 5 exits from the
  asserted damping-model envelope (`ladder/ladder_L2_reach_status.csv`).
- 6-DOF witnesses are Tx-cone violations.
- L3 mechanisms (single switch-off attribution): pitch + depth 9, pitch + vertical
  current + depth 6, pitch alone 2, combined/redundant 12.
- The planar certificate is reliable only under small vertical/attitude uncertainty (L1).
  Under L3 every planar certificate is contradicted by a concrete 6-DOF trajectory.

## 7. Runtime shield (secondary): S1-S5

### 7a. First run (v1a, negative)

A short-horizon online CORA shield with the old "slow down, turn to the receiver"
fallback did not reduce outage (`phase6/ood_shield_res_32.csv`, 40 runs per row). The
only outages, at 2x the declared current, were Rx-FOV drift.

### 7b. S1-S5 (v1b)

Sources:
- tables: `shield/table_{nn,sway,old}.csv|mat` (`code/run_shield_tables.m`);
- ablation: `shield/s5_ablation.csv`, `shield/s5_raw.mat`, scenario rows in
  `shield/s4_rows.mat` (`code/run_shield_v2.m`);
- figure: `figures/fig_shield_ablation.pdf`.

Wall time: tables 12,820 s; ablation 2,875 s. Declared bounds of the shielded system:
|w| ≤ 0.05 m/s, localisation 0.10 m.

**S1, sway-capable fallback.**
- Design: an exact PWL network u_c = sat(0.1(d̂ − d_ref)), r_c = sat(−0.5 ê),
  v_c = sat(0.5 φ̂), with |v_c| ≤ 0.3 m/s.
- 20 s certificates were not obtainable: the CORA linearisation fixpoint diverges, or the
  set leaves the damping envelope, after 1-7.5 s. The certificates are therefore over
  H = 4 s, on runtime tiles (d 0.5 m × φ 10° × e three bins × u two bins × r three bins,
  |v| ≤ 0.05 m/s).
- Sway fallback: Certified in 1,068 of 2,916 tiles (clear 748, coastal 320, turbid 0;
  Falsified 1,286, Inconclusive 562).
- For comparison, the NN is Certified in 2,733 of 5,832 tiles over H = 4 s (finer u bins).
- **Limitation:** at runtime the fallback was almost never invoked from inside a
  certified sway tile (column `fallback_from_certified_tile` = 0). The tiles assume
  |v| ≤ 0.05 m/s, and the fallback itself raises the sway speed. The fallback's success
  below is empirical; its certificate covers only invocations from near-zero sway.

**S2, lookup shield.**
- Check: the one-step prediction with margins must lie in Certified NN tiles.
- The first table, with operational velocity ranges u, r ∈ ±0.2, had **0** Certified
  tiles (set explosion). The fix was velocity bins: u in 0.1 m/s bins, r in 3 bins.
- Decision time is < 1 ms per check (mean 0.03-0.09 ms; monitor-only 0.003-0.008 ms), against 1.25-3.99 s for the
  online CORA check, which exceeds the 0.5 s period.
- Agreement with online CORA, on its 20-trajectory subsamples: the lookup never accepted
  an action that online CORA rejected (0 cases). Online CORA accepted some actions that
  the lookup rejected (173-398 steps per row), so the lookup is more conservative.

**S3, current monitor.**
- Over-bound currents in rows B1.5-B3.0: 100 % detected, median delay 1.9-2.9 s after
  the step.
- False alarms are about 90 % (B1.0: 92 %; C: 90 %) when the true current sits exactly
  at the declared bound, because the threshold equals the bound and the measurement
  error is ±0.03 m/s. This needs a guard band.

**S4/S5, ablation** (outage rate, Wilson 95 % CI; 200 trajectories per row, online
variants on the first 20). The rows are:
- A: replay of the 27 falsifier witnesses plus neighbours;
- B×f: starts near the envelope boundary with a current step at 3-8 s to f × the declared
  bound;
- C: B1.0 plus localisation spikes.

| Row | Classical | NN | NN+clip | NN+monitor→sway | Lookup+old fb | Lookup+sway fb | Lookup+sway+monitor | Online+old (n=20) | Online+sway (n=20) |
|---|---|---|---|---|---|---|---|---|---|
| A witness | 77.0 % | 77.0 % | 82.5 % | 78.0 % | 90.0 % | 83.0 % | 84.0 % | 90 % | 90 % |
| B 1.0× | 3.0 % | 3.0 % | 3.0 % | 1.5 % | 2.0 % | **0 %** [0, 1.9] | **0 %** | 0 % | 0 % |
| B 1.5× | 16.5 % | 16.5 % | 16.0 % | **0 %** | 12.0 % | **0 %** | **0 %** | 0 % | 0 % |
| B 2.0× | 28.5 % | 28.5 % | 26.5 % | **0 %** | 24.5 % | **0 %** | **0 %** | 15 % | 0 % |
| B 3.0× | 39.5 % | 39.5 % | 38.5 % | **0 %** | 44.0 % | **0 %** | **0 %** | 20 % | 5 % |
| C spikes | 7.0 % | 7.0 % | 7.0 % | 1.5 % | 5.0 % | **0 %** | **0 %** | 5 % | 0 % |

Further metrics (same source):
- **Availability.** For example, B3.0: NN 0.865, lookup+sway 1.000.
- **Intervention rate.**
  - Lookup+sway: 0.13-0.34 (B rows); with the monitor: 0.36-0.77.
  - Monitor only: 0.25-0.68.
  - Online CORA: 0.001-0.07.
- **Unnecessary-intervention share.** Measured by a counterfactual NN-only rollout from
  the true state to the end of the episode:
  - lookup+sway 0.58-0.98;
  - monitor only 0.81-0.99;
  - online+sway 0.03-1.0.
- **Outage provenance.** All B/C outages of the unshielded controllers are Rx-FOV, the
  sway drift. Row A outages are Tx-cone, under localisation errors above the shield's
  declared 0.1 m.

**Interpretation.**
- The shield result turns **positive** once the fallback has the control authority that
  the provenance analysis identified as missing (sway).
- The ingredient doing the work is the **sway-capable fallback**; it does not matter
  whether the lookup check or the monitor triggers it. The lookup check alone with the
  old fallback barely helps (B3.0: 44 % vs 39.5 % unshielded).
- The cost is a high share of unnecessary interventions, and the assurance argument is
  only partial: 4 s certificates, rarely covering the runtime invocation states.
- Row A shows the limit. Failures caused by violating the declared localisation bound
  are not prevented by any variant, and the current monitor cannot detect them.
- The shield is therefore reported as a secondary result. This result also
  motivates B3 (sway-capable actor, Sec. 12l).

## 8. Deployed network and ONNX

- `../models/actor_res_32.onnx` (opset 13) matches MATLAB to max |Δ| = 1.1e-7 over 200
  points (float32; `../models/onnx_check_res_32.json`). CORA verified the float64 MATLAB
  network, not the float32 ONNX graph.
- Imitation and closed-loop performance of all eight actors:
  `phase2/imitation_error.csv`, `phase2/closed_loop_summary.csv`. Mean sampled outage
  over 36 scenario groups × 300 runs ranges from 0.1660 to 0.1669 for every actor and for
  the teacher (0.1665).
- **Network width: a small observation, not an RQ.** Sources:
  `ccv/ccv_summary_2d_loc01_<actor>.csv` (`code/run_width_obs.m`) and, for res_32,
  `ccv/ccv_summary_2d_res_32.csv`. Planar certified start area at localisation 0.1 m,
  |w| ≤ 0.025 m/s (clear / coastal):

  | Width | MLP (m²) | Residual (m²) |
  |---|---|---|
  | 16 | 16.1 / 3.27 | 11.3 / 3.27 |
  | 32 | 18.8 / 3.27 | 16.1 / 3.27 |
  | 256 | 11.3 / 0 | 18.8 / 3.27 |

  The actors have indistinguishable sampled performance, but their certified areas
  differ by up to 40 %. There is no consistent trend with width or architecture under
  the command interface; only the 256-unit plain MLP loses the coastal certificate.
  This is much weaker than the provisional-model result, where the plain MLP fell to
  0 at 256 units. Reach CPU per actor run is 6.5-10.6 thousand seconds.

## 9. (Removed)

This section held internal notes mapping results to manuscript drafts; it is omitted
from the public version. The numbering of the other sections is unchanged.

## 10. Limitations and what remains

**Lessons supported by the numbers (all conditional on the calibrated model and its bounds)**
1. **Sampled success is not assurance.** 130 of 294 hero-map cells show apparent
   success, but only 22 % of them are certified and 21 % contain concrete outage
   trajectories (mostly Tx-cone excursions under adversarial but in-bound localisation
   errors).
2. **The certified envelope contracts much faster than the sampled one.** The planar
   certified start area falls from 19.5 m² (clear) and 3.7 m² (coastal) at 5 cm
   localisation error to 0 at 0.3 m. Monte Carlo apparent success stays at about 25 and
   10 m².
3. **Provenance changes with conditions.** Rx-FOV (lateral bearing drift) dominates once
   the current is ≥ 0.05 m/s. The Tx cone dominates under large localisation error and
   low current. Power binds near the range limit.
4. **Planar certificates over-state assurance on a 6-DOF vehicle.** 45.7 % of planar
   certified tiles and 22.6 % of 3-D certified tiles are falsified on the 6-DOF BlueROV2
   model. The planar certified volume over-states the 6-DOF-consistent volume by 68 %.
   The necessary mechanisms are vertical offset combined with pitch error, i.e. Tx-cone
   misalignment.
5. **Verifiability is a design property.** The force-level actor on the BlueROV2's
   weakly damped low-speed dynamics and the saturating, gated teacher (archived v0) were
   not verifiable. Command-level actors with a documented fast inner loop were.

**Limitations**
- **Model scope.**
  - Certificates are for the planar and reduced 3-D models under the declared bounds.
  - The 6-DOF results are falsification only.
  - The low-level loop gains, depth-hold gains, attitude-hold gains, 0.5 s control period,
    10 Mb/s rate, BER 1e-6, 30 m operating depth, 6 dB reserve, ±10 % c and all
    uncertainty bounds are ASSUMED scenario/design choices.
  - The transceiver constants combine three sources (N'Doye 2021, Celik 2020, Jamali 2017)
    into one coherent but synthetic link. They are not one measured modem.
  - BlueROV2 added mass carries 10-100 % uncertainty in the source; it is not modelled
    as uncertain.
  - Turbulence, forward-scattering gain, blockage and ambient-light direction are not
    modelled.
- **Over-approximation artefacts.**
  - Inconclusive regions are large under localisation errors ≥ 0.3 m and at vertical
    level L2. The causes are set explosion and the asserted damping-model envelope.
  - The CORA model uses a polynomial damping surrogate with a bounded error input. It is
    sound only within the asserted envelope, and cells that leave it are Inconclusive.
  - Current and localisation bounds are boxes around disks.
- **Statistics and search.**
  - Monte Carlo uses 500 runs (operating map) or 200 (CCV) per cell. The falsifiers are
    heuristic, so no witness is not evidence of safety.
  - Mechanism attribution by single switch-off finds necessary mechanisms only.
    Redundant combinations are labelled "combined".
- **Shield.** It does not help in this setting and is not real-time as implemented
  (Sec. 7).
- **Verified network.** CORA verified the float64 MATLAB network; the float32 ONNX graph
  matches it to 1.1e-7 but was not itself verified.
- **Not done.**
  - No second-tool cross-check (NNV/CROWN).
  - No 6-DOF reachability attempt: the optional item was not attempted for lack of time.
  - The planar certified margins by bisection (RQ3 in the old plan) were run only on
    the provisional model (archived).

**What remains**
1. Decide whether the synthetic link (N'Doye + Celik + Jamali) is acceptable, or
   calibrate to a single published modem with a stated BER sensitivity. Then rerun
   `run_all.m` (about 4 h on 10 workers).
2. Shrink the Inconclusive regions: tighter NN enclosures, disk/polytope noise sets,
   split budgets, and a wider damping envelope with a better surrogate.
3. Optional: CORA on the 6-DOF model for a few boundary tiles, and an NNV cross-check of
   selected certificates.
4. Shield: a sway-capable fallback and a precomputed (lookup) check to meet the 0.5 s
   period, or drop it to future work.

## 11. Audits (no new compute)

**(a) 29 Certified cells vs 28 'ok' statuses (hero map).**
- 28 cells were certified by a single reach run (status `ok`).
- The 29th is clear, d0 = 3 m, loc 0.1 m, |w| ≤ 0.05 m/s, with status `ok|violated` and
  `reach_leaves` = 3. Its parent box's reach run could not certify, because a time-interval
  set might touch ACE_F (`violated`). `reach_refine.m` therefore split the initial box
  along the widest normalised dimension. Both halves were then certified (`ok`).
- The halves cover the parent initial set exactly, with identical noise, current and
  channel bounds, so the cell is soundly Certified.
- possTx/possRx/possP = 0 and tFirstViol = Inf because only the final leaves contribute
  flags (`reach_refine.m`, lines 18-27).
- This corrects the reading that the flagged leaf lies outside [0, T] or is a robust-only
  issue. The cell is NotCertified only for the stronger *robust* property (Mlow 5.97 dB < 6 dB).
- No change of verdict is needed.

**(b) Falsified cells with status reachSetExplosion.** 176 Falsified hero-map cells show
`error:CORA:reachSetExplosion`, plus 1 with `…|model-range`. The verdict comes from a
concrete witness (Monte Carlo or the falsifier), not from reach. Once Monte Carlo has
found a witness, the cell is not refined (depth 0), and the single reach run is reported
as is. An explosion never produces Certified. Inconclusive cells with explosions: 57,
plus 9 `…|model-range`.

**(c) Denominators of the ladder rates.**
- Main ladder (Sec. 6, `ladder/ladder_ccv_res_32.csv`):
  - P(2D cert ∧ 3D fals) and P(2D cert ∧ 6-DOF fals) are over the 184 tiles of the 3-D
    tiling (loc 0.1 m, |w| ≤ 0.025 m/s, z0 ∈ [−1, 1] m) whose planar (d, φ) tile is
    Certified: clear 144, coastal 40.
  - P(3D cert ∧ 6-DOF fals) is over the 124 tiles Certified by 3-D reach: clear 104,
    coastal 20.
- Level sensitivity (`ladder/ladder_res_32.csv`): over the 29 2-D-Certified hero-map
  cells; the 3-D-conditional rate at L1 is over its 27 3-D-Certified cells.

**(d) Terminology for CCV vs EVV.**
- **Empirical-to-certified gap** = 1 − CCV/EVV. This is the "over-estimation" column of
  Sec. 5.
- **False-assurance volume (area)** = the Falsified part of EVV, i.e. the apparent-success
  region where a concrete outage trajectory exists (column "EVV falsified" in Sec. 5):
  - 2-D, |w| ≤ 0.025 m/s: clear 0.52 / 0.52 / 0.92 / 1.18 m² and coastal
    2.53 / 2.99 / 2.09 / 3.49 m² at loc 0.05 / 0.1 / 0.3 / 0.5 m; turbid 0.11-0.22 m²;
  - 3-D, loc 0.1 m: clear 7.78 m³, coastal 1.43 m³.
- The remainder of the gap is Inconclusive volume (conservatism or unresolved).

**(e) Provenance comes from different experiments.**
- Rx-FOV dominance (current ≥ 0.05 m/s) is a hero-map result: planar model, no vertical
  dynamics, current swept 0-0.2 m/s.
- Tx-cone dominance of the ladder witnesses is from the 3-D tiling at |w| ≤ 0.025 m/s
  with vertical offsets and pitch, on the 6-DOF falsifier.
- The two are not in conflict. At low horizontal current, planar Rx drift is small and
  vertical/pitch misalignment of the Tx cone becomes the binding term.

## 12. Follow-up experiments (2026-10-06)

### 12a. A2: resolving the 74 Inconclusive apparent-success cells

Source: `a2/a2_inconclusive.csv|mat` (`code/run_a2_inconclusive.m`), wall time 3673 s.
The staged passes:
- pass 1: splitting depth 2 (the hero map used 1);
- pass 2: zonotope order 200 (from 100), only for cells still unknown;
- strong falsifier: 200 × 25 iterations, on the remainder;
- pass 3 (separate, weaker property): T = 10 s, run because more than 30 cells remained.

| Stage | Result |
|---|---|
| Pass 1 (depth 2) | 0 newly Certified |
| Pass 2 (order 200) | 3 Certified |
| Strong falsifier | 1 Falsified (Tx cone, clear water) |
| **At T = 20 s** | **74 → 3 Certified + 1 Falsified + 70 Inconclusive** (64 set explosion, 6 possible violation) |
| Pass 3, T = 10 s (weaker property, reported separately) | 13 of the 70 certified for 10 s (clear 7, coastal 6); 57 still unknown (54 explosion, 3 possible violation) |

The unresolved territory is dominated by noise-driven growth of the over-approximation.
Neither more splitting nor a higher order removes it. A shorter horizon recovers part of
it, but for a weaker property.

### 12b. A1: Monte Carlo budget

Source: `a1/a1_mc_budget.csv` (`code/run_a1_mc_budget.m`). There are 27 cells that are
Falsified but showed 0 outages in 500 runs. Each was rerun at 5,000 runs, and those still
at 0 at 50,000 runs, with the same sampling model and independent seeds.
- **Plain sampling still misses 22 of 27 at 5,000 runs and 21 of 27 at 50,000 runs.**
- Where sampling finds them, the outage frequencies are tiny:
  - at 5,000 runs: 0.46 % (clear, 3 m, loc 0.5, w 0.1, Rx), 0.30 % and 0.22 % (coastal,
    2 m, loc 1.0, Tx), 0.02 % twice (turbid, 1.5 m, loc 0.5, Tx);
  - at 50,000 runs, one more: 1 outage (coastal, 2 m, loc 0.75, Tx).
- Sanity check: 10 Certified cells have 0 outages in 5,000 runs each (50,000 was not run for them; `outages_50k` = NaN), consistent with soundness.

### 12c. Classical PAT baseline (empirical comparator only)

Source: `baseline/baseline_pat.csv` (`code/run_baseline_pat.m`) and
`ccv/ccv_summary_2d_loc01_empirical_teacher.csv`.
- **Controllers.** The teacher law that res_32 imitates is the "empirically viable classical
  controller". It is evaluated by Monte Carlo (500 runs) plus targeted falsification only,
  with no CORA. res_32 keeps its formal verdict.
- **Cells.** 24 cells: 3 waters × near/far × localisation {0.05, 0.3} m × current {0, 0.1} m/s,
  with identical scenarios and seeds for both controllers.

| Metric (mean over 24 cells) | Teacher (classical) | res_32 (neural) |
|---|---|---|
| sampled outage rate | 0.1368 | 0.1373 |
| control effort | 3.230 | 3.229 |
| mean pointing error | 1.49° | 1.49° |
| time in robust region | 0.845 | 0.845 |
| verdicts | 11 Falsified, 13 not falsified (empirical) | 11 Falsified (same cells), 7 Certified, 6 Inconclusive |

- Teacher empirical viability at loc 0.1 m, |w| ≤ 0.025 m/s: clear 24.9 m² EVV, of which
  0.52 m² is demonstrated false assurance; coastal 9.2 m² EVV, of which 1.72 m² is
  demonstrated false assurance. A certified region is not computed for the teacher.
- **Reading.**
  - The neural actor matches the classical law in sampled performance (it imitates it).
  - The difference that can be claimed is assurance, not performance: 7 of the 13
    empirically viable cells carry a certificate for the neural controller.
  - The falsified cells are the same for both, so the false assurance is a property of the
    guidance law and the operating condition, not of the network.

### 12d. B1: hardware sweep, one parameter at a time (representative slices)

Source: `b1/b1_slices.csv` (raw: `b1/b1_slices_raw.csv`; `code/run_b1_slices.m`); figure
`figures/fig_b1_tornado.pdf`. Wall time 1463 s.

**Setup.**
- Slices: clear and coastal water at the hero-map near/far separations (clear 3 / 6.5 m,
  coastal 2 / 4 m). Each slice is a φ-strip of six 10° tiles at d0 ± 0.25 m.
- Bounds: loc 0.1 m, |w| ≤ 0.025 m/s, |e0| ≤ 5°.
- The actor res_32 is unchanged. Each variant recomputes the Lambertian order, concentrator
  gain, background-limited P_min and K (`code/link_variant.m`).

| Variant (K, dB) | Clear: certified / EVV / false-assurance / unresolved (m²) | CCV change | Coastal: certified / EVV / FA / unresolved (m²) | CCV change |
|---|---|---|---|---|
| base (25.47) | 2.79 / 3.32 / 0 / 0.52 | (base) | 0.70 / 2.09 / 0.35 / 1.05 | (base) |
| Φ½ = 10° (28.91) | 2.79 / 3.32 / 0 / 0.52 | 0 % | 0.70 / 2.09 / 0.35 / 1.05 | 0 % |
| Φ½ = 30° (19.90) | 0.52 / 1.05 / 0 / 0.52 | −81 % | 0 / 0.70 / 0.35 / 0.35 | −100 % |
| Rx FOV 20° (27.98) | 1.13 / 1.66 / 0 / 0.52 | −59 % | 0 / 1.05 / 0.35 / 0.70 | −100 % |
| Rx FOV 45° (22.93) | 4.97 / 4.97 / 0 / 0 | +78 % | 2.79 / 3.14 / 0 / 0.35 | +300 % |
| P_min −3 dB (28.47) | 2.79 / 3.32 / 0 / 0.52 | 0 % | 0.70 / 2.09 / 0.35 / 1.05 | 0 % |
| P_min +3 dB (22.47) | 2.79 / 3.32 / 0 / 0.52 | 0 % | 0.70 / 2.09 / 0.35 / 1.05 | 0 % |

(Areas are totals over the near and far slices. Per-slice percentages in the CSV are
undefined where the base CCV is 0, e.g. the coastal near slice.)

**Reading.**
- At these operating points (0.3 and 0.7 of the baseline power range, low current), the
  certified area is **geometry-limited**:
  - widening the Rx FOV buys the most certified area, at the cost of 2.5 dB of link budget;
  - narrowing it costs the most (−59 % clear, −100 % coastal);
  - ±3 dB of receiver sensitivity, or a narrower Tx beam, changes nothing at these slices.
- A wider Tx beam (30°) loses the far slices to power. Its 5.6 dB lower K shortens the range
  below the far separation.
- Empirical viability moves in the same direction but by less. At FOV 45°, all
  empirically viable area becomes certified in clear water; in coastal water 0.35 m² stays unresolved.
- Caveat: there are only 12 tiles per water and variant, so the changes are quantised
  (one tile is 0.17-0.57 m²). The slices do not probe the range limit, where sensitivity
  and Tx power matter.

### 12e. A3: localisation cliff, box vs disk (planar CCV, |w| ≤ 0.025 m/s)

Sources:
- `ccv/ccv_summary_a3_box_res_32.csv` and `ccv/ccv_summary_a3_disk_res_32.csv`;
- the 0.05 / 0.1 / 0.3 m points come from `ccv/ccv_summary_2d_res_32.csv` (Sec. 5);
- `code/run_chain_next2.m`.

Wall time: box 2,653 s, disk 1,990 s.

| loc (m) | Clear CCV / EVV (m²) | Clear gap | Coastal CCV / EVV (m²) | Coastal gap |
|---|---|---|---|---|
| 0.05 | 19.5 / 24.9 | 22 % | 3.67 / 10.0 | 63 % |
| 0.10 | 16.1 / 24.9 | 35 % | 3.27 / 10.2 | 68 % |
| 0.15 | 10.1 / 24.9 | 59 % | 2.79 / 9.99 | 72 % |
| 0.20 | 4.71 / 24.8 | 81 % | 0 / 9.64 | 100 % |
| 0.25 | 1.57 / 24.9 | 94 % | 0 / 9.49 | 100 % |
| 0.30 | 0 / 24.9 | 100 % | 0 / 9.08 | 100 % |

- **Shape of the decline.** It is not a cliff but a steady decline. In clear water the
  certified area roughly halves every 0.05–0.1 m and reaches 0 at 0.3 m. In coastal
  water it reaches 0 at 0.2 m. The empirical viable area stays flat at about 25 m² clear and
  about 10 m² coastal.
- **False-assurance area.** The falsified part of EVV stays about constant across loc:
  0.52–0.92 m² clear and 2.09–2.99 m² coastal over 0.05–0.3 m (0.8–0.9 and 2.4–2.5 m² over 0.15–0.25 m).
- **Box vs disk.** The certified area is identical at 0.15 and 0.2 m in both waters.
  - The disk model was applied: 312 of the 528 tiles differ in reach margin and 48 in reach status, but 0 in verdict.
  - It did not change any certified/uncertified tile.
  - So removing box conservatism in the localisation set does not move the envelope. What
    limits certification is over-approximation growth under noise, consistent with A2.
- **Positioning reading** (`positioning_map.md`): certificates exist up to 0.25 m (clear) or
  0.15 m (coastal) localisation error.
  - High-frequency LBL (sub-centimetre) and short-range optical ranging lie inside them.
  - Survey USBL at about 30 m slant range (bound about 0.07 m) is inside.
  - USBL at about 100 m (about 0.24 m) is at the edge in clear water and outside in coastal water.
  - Standard 12 kHz LBL is outside.

### 12f. Sway fallback re-certified over its operating range

Sources:
- invocation-state log and v1 scoring: `code/run_shield_sway_v2_eval.m` with tag `v1log` →
  `shield/sway_v2_eval_v1log.csv`, `shield/sway_v2_fblog_v1log.csv|mat`,
  `shield/sway_v2_invocation_pctl_v1log.csv`, `shield/sway_v2_noncert_reasons_v1log.csv`;
- v2 table: `code/run_shield_table_sway_v2.m` → `shield/table_sway_v2.csv|mat`,
  `shield/table_sway_v2_summary.csv` (log: `logs/table_sway_v2.log`);
- re-evaluation with the v2 table: the same script with tag `v2` → `shield/sway_v2_eval_v2.csv`,
  `shield/sway_v2_fblog_v2.csv|mat`, `shield/sway_v2_noncert_reasons_v2.csv`.

The table only scores the fallback steps; it does not change the control law. The rows,
seeds (rng(1000 r + 10 c)) and 200 trajectories per row are those of `run_shield_v2.m`.
The re-run therefore reproduces the S5 outage counts exactly: 3/200 for NN+M(sway) in
B1.0 and C, and 0/200 everywhere else.

**What the v1 column measured.** `fallback_from_certified_tile` in `s5_ablation.csv` is the
per-trajectory share of *all* fallback steps whose estimate box lies in certified v1
tiles, averaged over trajectories. It is empty for the L(sway) rows because some
trajectories had no intervention, which gives a NaN mean. Recomputed with `omitnan`, the
L(sway) values are 0.25-0.40 (`legacy_fbCert_v1_omitnan`). Two cases must be separated:
- an *invocation* (onset) is a fallback step whose previous step was not a fallback step;
- a *continuation* is a fallback step taken while the fallback is already active.

The shield re-checks every 0.5 s, so 42-96 % of fallback steps are continuations
(`share_steps_already_active`).

**Step 1: state distribution at fallback steps** (`sway_v2_invocation_pctl_v1log.csv`;
estimates, p1-p99):

| Set | û (m/s) | v̂ (m/s) | r̂ (rad/s) | ê (°) | φ̂ (°) |
|---|---|---|---|---|---|
| L(sway) onsets (n = 3578) | −0.05 … 0.16 | −0.03 … 0.03 | −0.04 … 0.04 | −10.5 … 9.8 | −24.4 … 24.3 |
| L(sway) all fallback steps (n = 8595) | −0.06 … 0.16 | −0.16 … 0.16 (max 0.21) | −0.07 … 0.07 | −9.5 … 9.0 | −23.8 … 23.7 |
| L(sway)+M all fallback steps (n = 23075) | −0.05 … 0.16 | −0.15 … 0.15 | −0.05 … 0.06 | −7.8 … 7.2 | −22.3 … 22.4 |

- Onsets start at near-zero sway: |v̂| ≤ 0.04 m/s, inside the v1 bound.
- During continuation the fallback drives |v| to 0.12-0.15 m/s (p75-p95).
- û and r̂ stay inside the v1 bins: u ∈ [−0.2, 0.2], r ∈ [−0.2, 0.2].
- So only the sway bins needed extending.

**Step 2: v2 table.**
- Bins: five sway bins of the v1 width, edges −0.25, −0.15, −0.05, 0.05, 0.15, 0.25 m/s.
- Everything else as in v1: d/φ/e/u/r bins, H = 4 s, |w| ≤ 0.05 m/s, loc 0.1 m, c ± 10 %.
- The |v| ≤ 0.05 bin is the v1 table itself.
- The two positive bins were computed: 5,832 tiles, wall 8,755 s on 10 workers.
- The two negative bins are mirror images under (φ, e, v, r, w_t) → −(·). The planar
  model, the fallback law, the ACE predicates and the bounds are invariant under this
  map, so the mirrored certificate is sound.
- Numerical check of the mirror on v1: 2,888 of 2,916 mirror pairs have the same verdict.
  All 1,068 pairs with a Certified member agree.
- One cost change: reachability is skipped for tiles that Monte Carlo already falsifies.
  This cannot change a verdict.

| v bin (m/s) | Clear cert. / fals. / inc. (of 1728) | Coastal (of 972) | Turbid (of 216) | Inconclusive because the reach set left the damping envelope (clear/coastal/turbid) |
|---|---|---|---|---|
| [−0.05, 0.05] (v1) | 748 / 718 / 262 | 320 / 407 / 245 | 0 / 161 / 55 | 0 / 10 / 0 |
| [0.05, 0.15] (and mirror) | 749 / 483 / 496 | 320 / 270 / 382 | 0 / 158 / 58 | 22 / 30 / 3 |
| [0.15, 0.25] (and mirror) | 750 / 488 / 490 | 319 / 274 / 379 | 0 / 158 / 58 | 22 / 36 / 5 |

Totals: 5,344 of 14,580 tiles Certified (clear 3,746, coastal 1,598, turbid 0).
- The certified count per bin does not fall with sway speed.
- No initial tile lies outside the fallback's damping-model envelope (|v| ≤ 0.35 m/s).
- The reach set left the envelope in 14-40 tiles per bin and water. Only 3-36 of these
  are Inconclusive *because* of it; the others are Falsified by a witness.
- So neither the envelope nor set explosion at speed limits the sway table in this range.
  The certified set is bounded by the same d/φ/e geometry as in v1.

**Step 3: re-evaluation** (`sway_v2_eval_v2.csv`; v1 → v2):
- "Onsets certified": the share of invocations whose estimate box lies in certified tiles.
- "Steps certified": the same for all fallback steps.
- "Time covered": the share of fallback time within 4 s of a certified start in the same
  continuous fallback episode.

| Row | Controller | Outage (Wilson 95 %) | Onsets certified | Steps certified | Time covered | Time covered, true current within the declared bound |
|---|---|---|---|---|---|---|
| B1.0 | L(sway) | 0/200 [0, 1.9 %] | 0.77 → 0.77 | 0.38 → 0.57 | 0.47 → 0.59 | 0.47 → 0.59 |
| B1.5 | L(sway) | 0/200 [0, 1.9 %] | 0.76 → 0.76 | 0.39 → 0.64 | 0.56 → 0.67 | 0.08 → 0.16 |
| B2.0 | L(sway) | 0/200 [0, 1.9 %] | 0.69 → 0.69 | 0.29 → 0.60 | 0.53 → 0.68 | 0.06 → 0.11 |
| B3.0 | L(sway) | 0/200 [0, 1.9 %] | 0.62 → 0.62 | 0.15 → 0.36 | 0.33 → 0.57 | 0.05 → 0.10 |
| C | L(sway) | 0/200 [0, 1.9 %] | 0.64 → 0.64 | 0.38 → 0.52 | 0.45 → 0.55 | 0.45 → 0.55 |
| B1.0 | L(sway)+M | 0/200 [0, 1.9 %] | 0.78 → 0.78 | 0.22 → 0.83 | 0.63 → 0.84 | 0.63 → 0.84 |
| B1.5 | L(sway)+M | 0/200 [0, 1.9 %] | 0.75 → 0.76 | 0.20 → 0.91 | 0.50 → 0.92 | 0.03 → 0.05 |
| B2.0 | L(sway)+M | 0/200 [0, 1.9 %] | 0.73 → 0.73 | 0.20 → 0.91 | 0.49 → 0.93 | 0.02 → 0.04 |
| B3.0 | L(sway)+M | 0/200 [0, 1.9 %] | 0.70 → 0.70 | 0.18 → 0.77 | 0.48 → 0.87 | 0.02 → 0.04 |
| C | L(sway)+M | 0/200 [0, 1.9 %] | 0.65 → 0.66 | 0.21 → 0.79 | 0.57 → 0.81 | 0.57 → 0.81 |
| B1.0 | NN+M(sway) | 3/200 [0.5, 4.3 %] | 0.69 → 0.69 | 0.13 → 0.84 | 0.52 → 0.85 | 0.52 → 0.85 |
| B1.5-3.0 | NN+M(sway) | 0/200 each | 0.56-0.61 (unchanged) | 0.15-0.17 → 0.70-0.87 | 0.35-0.40 → 0.77-0.89 | 0 → 0 |
| C | NN+M(sway) | 3/200 [0.5, 4.3 %] | 0.58 → 0.58 | 0.12 → 0.76 | 0.45 → 0.80 | 0.45 → 0.80 |

The following are unchanged, because the control law is unchanged:
- **Interventions**: L(sway) 0.13-0.34 and L(sway)+M 0.36-0.77 per step.
- **Unnecessary-intervention share**: L(sway) 0.58-0.98 and L(sway)+M 0.80-0.99.
- **Decision time**: the NN lookup or monitor check averages 0.4-39 µs, with a maximum of
  29 ms, which is pool scheduling jitter.

The added 6-D fallback lookup takes 19-93 µs on average, p95 ≤ 0.26 ms and maximum 22 ms.
All of these are far below the 0.5 s period.

**Why a fallback step is not certified (v2)** (`sway_v2_noncert_reasons_v2.csv`). The
reasons are given for all fallback steps / onsets.
- L(sway): 51 % / 69 % certified; outside the tiled φ/e range 5 % / 9 %; inside the range
  but in an uncertified tile 44 % / 22 %; outside the v range 0 %.
- L(sway)+M: 85 % / 72 % certified; outside the φ/e range 2 % / 11 %; uncertified tile
  13 % / 17 %.
- The remaining uncertified steps are in tiles that are Falsified or Inconclusive for the
  fallback itself (`sway_v2_noncert_geometry.csv`, `code/sway_v2_noncert_geometry.py`).
  41-61 % of the uncertified in-range steps have |φ̂| ≥ 20°, against 0 % of the certified
  steps. |ê| ≥ 5° accounts for only 1-15 %.
- So the limit is the bearing geometry that also limits the v1 table, not the sway speed.

**Reading.**
- **The premise of the caveat in Sec. 7b was partly wrong.** Fallback *invocations* already
  started inside certified v1 tiles 56-78 % of the time. What the v1 table did not cover
  was the *continuation* of the fallback, once it had raised the sway speed above
  0.05 m/s. In v1, 57-82 % of all fallback steps were outside the v range.
- With velocity bins, the share of fallback steps that start inside a certified tile rises:
  - L(sway)+M: 0.18-0.22 → 0.77-0.91;
  - NN+M(sway): 0.12-0.17 → 0.70-0.87;
  - lookup+sway: 0.15-0.39 → 0.36-0.64.
- The share of fallback time covered by a 4 s certificate rises:
  - L(sway)+M: 0.48-0.63 → 0.81-0.93;
  - L(sway): 0.33-0.56 → 0.55-0.68.
- The onset share does not change (0.56-0.78), because onsets were already at low sway.
- **Within the declared bounds (rows B1.0 and C), the claim can move to "mostly certified
  fallback" for the monitor-triggered variants.** 80-85 % of fallback time is covered by a
  4 s certificate. For lookup+sway alone, the honest wording is "about half to
  two-thirds".
- **Over the bound (rows B1.5-B3.0), the certificates do not apply.** They assume
  |w| ≤ 0.05 m/s, and in these rows the true current exceeds that for 57-100 % of
  fallback steps. Only 0-16 % of fallback time is covered with an in-bound current (0 % for NN+M(sway)). The
  recovery there remains empirical: 0/200 outages per row. A certificate for these rows
  would need tables computed under the over-bound current, e.g. |w| ≤ 0.15 m/s.
- The certificates remain 4 s bounded-horizon certificates re-checked every 0.5 s. They
  are not an infinite-horizon guarantee.

**Supersedes:** the "Limitation" bullet in Sec. 7b, which said that the column is 0 and
invocations rarely start inside a certified tile.

### 12g. Coastal teacher vs res_32 difference

Full write-up: `coastal_diagnosis.md`. Sources:
- `code/coastal_join.py` → `coastal_diag/join_{clear,coastal}.csv`, `coastal_diag/differing_tiles.csv`;
- `code/run_coastal_diag.m` → `coastal_diag/seed_reruns.csv`, `mc5000.csv`, `witness_cross.csv`;
- `code/coastal_summary.py` → `coastal_diag/summary.csv`.

No reachability was run.

- **Where the difference is.** At loc 0.1 m and |w| ≤ 0.025 m/s, the two coastal
  decompositions are:
  - teacher: EVV 9.18 m², falsified 1.72 m²;
  - res_32: EVV 10.21 m², falsified 2.99 m².

  They differ in exactly four of 132 coastal tiles, all at |φ0| = 15°:
  - (d0, φ0) = (1.25, −15) and (2.75, +15), both Rx;
  - (5.25, −15) and (5.25, +15), both power.

  Three of the tiles had 1 MC outage in 200 for the teacher, and 0 MC outages plus a
  falsifier witness for res_32 (1.03 m² of EVV). The fourth had a falsifier robustness
  of +0.11 (teacher) vs −0.04 (res_32), which accounts for 0.24 m² more false
  assurance. Clear water is identical tile by tile.
- **Cause: sampling variance.** The two runs drew different random numbers for the same
  tile, because the run_cells seed is 1000 + the tile's index in each run's own cell list.
  With the workers' Threefry generator, both original rows reproduce exactly.
  - Rerun with five seeds each, both controllers fall into the same category in 20 of 20
    tile-seed pairs. Swapping the seeds swaps the outcomes.
  - The tiles change category from seed to seed, for both controllers together: in EVV
    under 2-5 of 5 seeds.
  - 5,000-run MC gives identical outage counts for the two controllers: 10/10, 8/8, 10/10
    and 0/0.
  - At a frequency of 0.16-0.2 %, a 200-run MC sees no outage with probability 0.67-0.73.
- **Not a behavioural difference.** All 20 falsifier witnesses transfer to the other
  controller, with the robustness differing by ≤ 0.010. On the witness trajectories,
  |Δu_c| ≤ 0.004 m/s and |Δr_c| ≤ 9e-5 rad/s, and r_c never saturates.
- **Not a tiling artefact.** The tilings are identical, and the join is one to one.
- **Consequence.** The coastal EVV and false-assurance areas carry a seed uncertainty of
  about ±1 m² at 200 MC runs per tile. The empirical decomposition of the teacher and of
  res_32 is the same within sampling resolution. This strengthens the reading of 12c:
  false assurance is a property of the guidance law and the operating condition, not
  of the network.
- **Recommended sentence:** "In coastal water the classical law and its neural imitation
  differ by 1.0 m² of empirically viable area and 1.3 m² of false-assurance area. The
  difference comes entirely from four marginal tiles, with outage frequencies near 0.2 %
  or falsifier robustness within 0.05 of zero, that a 200-run Monte Carlo classifies
  differently under different random seeds. Under common seeds, the two controllers
  receive identical verdicts on these tiles."

### 12h. Chained short-window certification

Sources: `chain/chain_jobs.csv` (one row per cell × H × set type), `chain/chain_cells.csv`
(per cell), `chain/chain.mat`, `chain/diag_growth.txt`; code `code/chain_cell.m`,
`code/run_chain_certify.m`, `code/diag_chain_growth.m`. Method and soundness argument:
`chain/METHOD.md`. Wall time 1,159 s on 10 workers (reach 1,154 s, 8,443 CPU s, longest job
64 s; falsifier 5 s, 47 CPU s).

**Method.** At every 0.5 s sample, the closed loop has no memory beyond x = [d, φ, e, u, v, r].
All exogenous bounds are constant boxes, so the per-window problem is time-invariant.
- Window 0 is a CORA reach from the cell box X0 over [0, H].
- Each later window restarts from an outer enclosure of the previous end set: an interval
  hull (box) or an order-1 PCA parallelotope (par), inflated by 2 %.
- Every time-interval set is checked against ACE_Tx, ACE_Rx, ACE_Power and the damping
  envelope.
- Containment of window k's end set in window k+1's start set holds by construction. If
  every window up to 20 s is OK, the cell is Certified on [0, 20 s].
- A cell would be Certified for every horizon if some end set fell inside an earlier start
  set (closure).

Configurations: H ∈ {4, 5} s × {box, par}, with the reach settings of Sec. 2 (order 100, no
splitting).

**Transitions of the 70 still-Inconclusive cells** (a cell counts as chain-certified if
either set type certifies it; the reason is taken from the configuration that got furthest):

| | H = 4 s | H = 5 s |
|---|---|---|
| Certified by chaining | **0** | **0** |
| Still Inconclusive: set explosion inside a window | 53 | 50 |
| Still Inconclusive: ACE touched (Rx 20, Tx 14, power 12 over all four configurations) | 11 | 12 |
| Still Inconclusive: damping-model envelope left (`model-range`) | 6 | 8 |
| Still Inconclusive: containment failed | 0 | 0 |
| Failure already in window 0, from X0 | 38 | 44 |

- **70 → 0 certified by chaining + 70 Inconclusive, for both H.**
- 34 of the 38 window-0 failures (H = 4) have localisation error ≥ 0.3 m. In these cells the
  reach explodes within the first 4 s, before any chaining applies.
- The other cells get no further than the single long reach did:
  - furthest certified prefix per cell: 0 s (38 cells), 4-5 s (18), 8-10 s (10), 12 s (3), 16 s (1);
  - the 13 cells that A2 certified for T = 10 s reach 8-16 s, then fail by Rx (bearing) or
    by explosion at 8.5-11.5 s.
- Box and parallelotope restarts give the same outcome to within one cell per configuration.

**Consistency check on the 32 Certified cells.**
- **29 of 32 are certified by chaining for both H.** This includes one of the three A2
  pass-2 cells (coastal, 4 m, loc 0.2, w 0.025).
- The other three cells:
  - clear, 3 m, loc 0.1, w 0.05: Certified by the original reach; the chain touches ACE;
  - coastal, 4 m, loc 0.3, w 0 (A2 pass 2, order 200): `model-range` / explosion;
  - turbid, 1 m, loc 0.1, w 0 (A2 pass 2, order 200): ACE / `model-range`.
- These three are failures to re-prove under a looser enclosure, not contradictions. Chaining
  never produces a Falsified verdict, and no Certified cell received a witness.
- The parallelotope restart certifies all 29; the box restart certifies 27.

**Closure (any-horizon certificate).**
- 0 of 408 chains closed in the full state.
- This is structural, not a tuning issue. The bearing φ enters no right-hand side of the
  CORA model, no actor input and no noise bound: it is a neutral integrator.
- Over a window, φ(H) = φ(0) + Δ, where Δ depends only on [d, e, u, v, r] and the inputs. So the
  φ interval of the end set is the start interval widened by every attainable increment, and
  it can never fit back inside the start set (METHOD.md, Sec. 5).
- In the w = 0 Certified cell (clear, 3 m, loc 0.05), d, e, u, v and r all contract window by
  window. The φ width still grows by about 0.02 rad per window from noise alone.
- Closure of [d, e, u, v, r] alone (diagnostic only) occurred in 2 jobs, both on Certified
  cells, and in none of the 70.

**Why chaining does not help: the growth is mostly real.** `diag_chain_growth.m` simulates the
cell centre with no noise under a constant polar current of magnitude w (radial ±w,
tangential ±w). This gives a lower bound on the true reachable spread that any sound
enclosure must contain.
- Clear, 3 m, w 0.075 (cell 4):
  - true d spread ≥ 0.93 m and φ spread ≥ 0.34 rad at 8 s, before adding the 0.5 m and 0.10 rad
    initial cell;
  - chain enclosure at 8 s: 1.46 m and 0.67 rad;
  - the d enclosure is nearly tight; the φ enclosure is about 1.5 times the bound.
- For the five cells that the chain lost by Rx (clear 3 m and coastal 2/4 m, w 0.05-0.075),
  max |φ| from the centre alone reaches 0.28-0.41 rad at 20 s, against a FOV of 0.524 rad.
  This leaves 0.1-0.25 rad for the ±3° initial bearing, the measurement noise and the
  over-approximation.
- The CORA current box [−w, w]² also allows currents of magnitude up to √2 w, more than
  the declared disk. Under this input model, part of the remaining territory may not be
  certifiable even by the exact reachable set.
- Restarting from a simplified set removes dependency growth but cannot shrink the true
  set. The large-noise cells explode within the first window.

**Soundness checks.**
- All 29 chain-certified cells were attacked by the strong falsifier (cross-entropy,
  200 × 25, T = 20 s): **0 witnesses**, smallest robustness 1.96.
- `soundness_violation` = 0 in every row.
- No containment re-check failed (the `containment` status never occurred).

**Updated headline (130 empirically viable hero-map cells): unchanged.**
- **Certified 32**: 29 from the hero map + 3 from A2.
- **Falsified 28**: 27 + 1 from A2.
- **Unresolved 70.**

Chained short-window certification adds no certificates. It is a sound way to re-derive 20 s
certificates (29 of 32), but it cannot remove an obstruction that comes from genuine growth
of the reachable set under the declared current box, or from noise-driven explosion inside
the first window.

### 12i. Disk-shaped current set (campaign C)

Sources:
- `code/run_curdisk.m` → `curdisk/curdisk_cells.csv|mat`, `curdisk/ccv_curdisk_res_32.csv|mat`,
  `curdisk/ccv_summary_curdisk_res_32.csv` (log: `logs/curdisk.log`);
- `code/curdisk_summary.py` → `curdisk/curdisk_summary.csv`.

Wall time: cells 3,981 s; CCV 2,573 s.

**Change.**
- `reach_cell.m` now accepts the option `cellc.curModel = 'disk'`; the default stays
  'box', so all earlier results are reproducible.
- With the option, the current input (w_r, w_t) is enclosed by an octagonal zonotope with
  4 generators of length w0 tan(π/8), as in the localisation-disk branch. This regular
  octagon has inradius w0, so it contains the declared disk |w| ≤ w0, and the enclosure
  stays sound.
- The polar components are a rotation of the world-frame current, so the disk is
  preserved.
- Monte Carlo and the falsifier already sample inside the disk, and with the same seeds
  their draws are unchanged.

**Cells.**
- The 70 hero-map cells still Inconclusive after A2 were re-run with the settings of the
  A2 pass that certified most: zonotope order 200, splitting depth 2, T = 20 s.
- The 32 Certified cells (29 hero map + 3 A2) were re-run with the same settings as a
  consistency check.

| Set | A2 reason → disk reason | n | Certified with the disk |
|---|---|---|---|
| 70 unresolved | set explosion → set explosion | 64 | 0 |
| 70 unresolved | possible violation → possible violation | 6 | 0 |
| 32 certified | still certified | 32 | 32 |

- **70 → 0 certified, 0 falsified, 70 unresolved.**
  - The falsifier result cannot change, because its sampling model and seeds are the
    same as in A2.
  - No new certificate needed a falsifier attack.
- **Consistency check passed.** All 32 certified cells stay certified, and none becomes
  violated. Their certified margin lower bound changes by 0 to +0.9 dB (median +0.05 dB)
  against the operating map. That comparison also includes the higher order and
  splitting depth.
- **CCV** (Sec. 5 settings, loc 0.1 and 0.15 m, |w| ≤ 0.025 m/s):

  | loc (m) | Clear CCV, box → disk (m²) | Coastal CCV, box → disk (m²) |
  |---|---|---|
  | 0.10 | 16.14 → 16.14 | 3.27 → 3.27 |
  | 0.15 | 10.12 → 10.12 | 2.79 → 2.79 |

  The certified area is identical. The EVV and false-assurance columns of this run differ
  slightly from Sec. 5 (coastal EVV at 0.1 m: 9.99 vs 10.21 m²). That is the
  seed-to-tile assignment effect of 12g, not the current model.
- **Four-category headline (hero map): unchanged by the disk.** The current headline is
  the one in 12j:
  - 32 Certified;
  - 31 Falsified (28, plus 3 found by the sideways adversary of 12j);
  - 67 Inconclusive.

  The disk model certified none of the 70. That includes the 3 cells that 12j later
  falsified, which is consistent with soundness.

**Why the disk does not help.**
- The box and the octagon have the same extent along each axis (±w0 in w_r and in w_t).
  The octagon removes only the corners, where both components are large at once.
- The bearing rate φ' = (−u sin e − v cos e + w_t)/d depends on w_t alone, and the range
  rate d' on w_r alone.
- So the per-axis growth of the tube, which drives the explosion, is unchanged. A
  single-cell smoke test showed the same: the final φ width was 0.2934 rad for both, and
  the e width 0.2168 vs 0.2172.
- The √2 corner magnitude would matter only for a quantity that depends on both
  components together. None of the binding terms does.

### 12j. Why the unresolved cells stay unresolved: sideways falsifier, drift budget, certified duration

Sources: `diag70/sideways_cells.csv|.mat`, `diag70/witness_replay.txt`,
`diag70/drift_budget.csv`, `diag70/drift_budget_summary.txt`, `diag70/tcert_cells.csv`,
`diag70/tcert_summary.txt`, figure `figures/fig_tcert.pdf`. Code: `code/falsify_sideways.m`,
`code/replay_sideways_witness.m`, `code/drift_budget.py`, `code/tcert_analysis.py`. Simulation
and analysis only (no CORA). Wall time 2,745 s in one serial MATLAB session (2 threads).

**Check 1: structured sideways adversary.**
- Cells: the 70 unresolved cells, and the 32 Certified cells as a soundness check.
- Declared current model. The CORA model takes the current as a box [−w, w]² with any time
  variation. Monte Carlo samples a disk |w| ≤ w0 with a slowly varying component; the
  falsifier rotates the direction at up to 0.2 rad/s. The current is therefore not declared
  constant. The adversary uses magnitude exactly w0 (on the disk) in three modes:
  - `const`: constant in the world frame;
  - `track`: constant polar components, so the current stays perpendicular to the moving
    line of sight (rotation rate equal to the bearing rate, below 0.03 rad/s);
  - `switch`: constant in the world frame, reversed once at t_s. This is admissible for the
    CORA box but not for the slowly varying Monte Carlo family, so it is reported separately.
- Direction: perpendicular to the transmitter-receiver line, on both sides, ±30°.
- Other bounds at their worst corners:
  - x0 at the corners of the cell box (d, φ0 = ±3°, e0 ∈ {−e0, 0, +e0}, u0, v0 and r0);
  - localisation bias of magnitude up to loc, perpendicular to the line of sight ("bearing
    side"), so it biases the bearing estimate;
  - heading bias ±1°, DVL/gyro biases at ±(0.02, 0.02, 0.01);
  - true c = 1.1 c_nom. c enters only the power predicate, and M decreases in c.
- Search per cell: 74,800 scenarios (a grid of 64,800, 6,000 random draws in the same
  family, and 2 × 2,000 local refinements around the 20 lowest-robustness scenarios).
- Falsified if robustness < −0.01, as in Sec. 0.

| Group | Falsified | First violated predicate | Time of first violation |
|---|---|---|---|
| 70 unresolved | **3** | Rx 3 | 18.35-19.75 s |
| 32 Certified (soundness check) | **0** | none | smallest robustness 1.96 deg (turbid, 1.5 m, loc 0.1, w 0) |

The three witnesses:

| Cell | Water, d0, loc, w | Mode | Min robustness | First violation |
|---|---|---|---|---|
| 179 | coastal, 4 m, 0.5 m, 0.075 m/s | track (also const) | −0.37 deg | Rx at 19.75 s |
| 198 | turbid, 1 m, 0.05 m, 0.025 m/s | track (also const) | −0.33 deg | Rx at 19.70 s |
| 205 | turbid, 1 m, 0.1 m, 0.025 m/s | const (also track) | −1.87 deg | Rx at 18.35 s |

- All three are found with the constant world-frame current alone and with the tracking
  current alone. None needs the switching current, and the switching mode found nothing new.
- Each witness was replayed from its recorded parameters by `replay_sideways_witness.m`.
  The replay checks the bounds explicitly: |w| = w0, |dpos| ≤ loc, the other biases inside
  their bounds, x0 inside the box. It reproduces the robustness and the violation time.
- Every witness needs the estimation errors as well. With all estimation errors at zero, no
  cell is falsified: the closest is 1.76 deg inside the FOV (turbid, 1 m). In each witness,
  the current, a constant localisation bias toward the bearing side and the heading and
  velocity biases push the bearing the same way. A constant bias is admissible: the declared
  noise is any value in its bound at each step, and `falsify_cell` also contains constant
  biases (square-wave period up to 40 s).
- The violations occur only in the last 0.3-1.7 s of the 20 s horizon, and only 274-3,890 of
  the 74,800 scenarios violate. This explains why 500 Monte Carlo runs and the cross-entropy
  falsifier (200 × 25) missed them.
- Near misses among the remaining 67: cell 32 (clear, 3 m, loc 0.5, w 0.075) reaches 0.044 deg
  inside the FOV; cell 95 (clear, 6.5 m, loc 1, w 0.075) reaches 0.09 deg.
- **Soundness: no Certified cell has a witness.** `soundness_violation` = 0 in all 32 rows.

**Updated headline (130 empirically viable hero-map cells)**, four categories:
- **Certified 32**;
- **Falsified 31**: 28 + 3 by the sideways adversary, all three by Rx near the end of the horizon;
- **Unresolved, near the Rx edge, 39**: realised bearing drift is 50-100 % of the FOV margin;
- **Unresolved, tool-limited, 28**: realised drift is below 50 % of the margin; 23 of them
  have loc ≥ 0.3 m.

The split of the unresolved cells comes from Check 2 (adversarial class).

**Check 2: drift budget (Rx FOV).**
- (a) Margin at t = 0. In the planar rung the Rx incidence is |φ| (`ace_eval.m`,
  `reach_cell.m`), and |φ0| ≤ 3° in every cell. The margin is therefore 30° − 3° = 27°
  (0.471 rad) for every cell.
- (b) Drift over 20 s, measured three ways:
  - kinematic: w0·T / d_min, with d_min = d0 − 0.25 m. This is a scale, not a rigorous bound:
    it ignores the vehicle's own tangential motion and any range loss;
  - noise-free worst case (nf): max |φ(t)| − 3° over the 2,400 noise-free adversarial
    scenarios of Check 1;
  - adversarial (adv): the same quantity over all Check 1 scenarios, with the estimation
    biases at their bounds.

  The nf and adv measures are realised drifts. They are lower bounds on the true worst-case
  drift.
- Class on the ratio drift / margin: **at risk** ≥ 1; **borderline** (near the edge) 0.5-1;
  **tool-limited** < 0.5.

| Verdict | Measure | At risk | Borderline | Tool-limited | Total |
|---|---|---|---|---|---|
| Certified | nf / adv | 0 / 0 | 3 / 3 | 29 / 29 | 32 |
| Falsified by Check 1 | nf / adv | 0 / 3 | 3 / 0 | 0 / 0 | 3 |
| Still unresolved | nf / adv | 0 / 0 | 35 / 39 | 32 / 28 | 67 |
| Still unresolved | kinematic | 9 | 29 | 29 | 67 |

The 70 originally unresolved cells by localisation band (adv class):

| Localisation | At risk | Borderline | Tool-limited | Total |
|---|---|---|---|---|
| loc < 0.3 m | 2 | 21 | 5 | 28 |
| loc ≥ 0.3 m | 1 | 18 | 23 | 42 |

The same 70 cells by current bound (adv class; at risk / borderline / tool-limited):

| Current bound | At risk | Borderline | Tool-limited |
|---|---|---|---|
| w = 0 | 0 | 0 | 13 |
| w = 0.025 | 2 | 5 | 10 |
| w = 0.05 | 0 | 12 | 5 |
| w = 0.075 | 1 | 16 | 0 |
| w = 0.1 | 0 | 6 | 0 |

- No unresolved cell reaches the FOV in noise-free simulation. The largest nf ratio is 0.91
  (coastal 4 m, w 0.075). With the estimation biases, 20 of the 67 exceed 0.8 and 10 exceed
  0.9. These cells are certified for at most a few seconds less than they would need: the
  realised bearing comes within 5.2° of the FOV edge.
- All 23 cells with w ≥ 0.075 are near the edge or falsified. The noise-free bearing drift
  from the current uses 61-91 % of the margin, which leaves the reach no room for the
  over-approximation. These cells are physically limited, not only tool-limited.
- The 28 tool-limited cells are mostly noise-driven: 23 have loc ≥ 0.3 m, and 13 have w = 0.
  Their realised drift is small (the w = 0 cells reach at most 25 % of the margin). They stay
  unresolved because the reach explodes, typically in the first window (Sec. 12h). The Rx
  predicate is not the binding constraint there.
- The kinematic scale over-estimates the realised drift at short range (the closed loop
  partly compensates) and under-estimates it where the vehicle's own sway adds to it. It
  marks 9 unresolved cells at risk that simulation does not confirm.
- The 3 Certified cells in the borderline band (nf ratio 0.57-0.61) all have w = 0.05 and loc ≤ 0.1 m. So a
  realised drift of 50-60 % of the margin is still certifiable at low noise.

**Check 3: certified link duration T_cert.**
- Definition: T_cert is the longest certified prefix [0, T_cert] of ACE_O under the declared
  bounds.
- Certified cells: 20 s. This is the property horizon; the chain often certified windows to
  24-25 s, which are not counted.
- Unresolved cells: the maximum over every sound run of the cell:
  - chained reach over H ∈ {4, 5} s × {box, par}, using `tFail_s`, the start of the first
    failing CORA step or control period (every earlier time-interval set was checked inside
    ACE_O and the damping envelope);
  - A2 pass 3 (10 s).
- The window-granular value (windows OK × H) is also in `tcert_cells.csv`. The 28 Falsified
  cells were never chained, and their T_cert is not computed.

Unresolved 70 (fine T_cert):
- median 3.0 s, mean 4.5 s, range 0.5-18.5 s;
- 13 cells reach ≥ 10 s; none reaches 20 s;
- histogram over [0,1), [1,4), [4,8), [8,12), [12,16), [16,20) s: 16, 22, 18, 10, 3, 1.

The window-granular value is 0 for 38 cells (median 0 s, max 16 s).

| Group | n | Median T_cert | Max | ≥ 10 s |
|---|---|---|---|---|
| clear | 41 | 3.0 s | 13.1 s | 7 |
| coastal | 22 | 4.3 s | 18.5 s | 6 |
| turbid | 7 | 2.4 s | 5.1 s | 0 |
| loc 0.05 / 0.1 m | 7 / 9 | 10.0 / 10.0 s | 13.6 / 18.5 s | 4 / 5 |
| loc 0.2 / 0.3 m | 12 / 15 | 5.5 / 4.0 s | 11.5 / 10.0 s | 3 / 1 |
| loc 0.5 / 0.75 / 1 m | 15 / 8 / 4 | 2.0 / 0.5 / 0.5 s | 3.0 / 0.95 / 0.5 s | 0 |

- By water and localisation band (median): clear 7.0 s (loc < 0.3, n = 13) vs 1.5 s
  (loc ≥ 0.3, n = 28); coastal 10.0 s (n = 9) vs 2.0 s (n = 13); turbid 2.7 s (n = 6) vs 0.9 s
  (n = 1).
- The three cells falsified by Check 1 have T_cert 1.5, 5.0 and 1.95 s. Each is below its
  witness time (18.35-19.75 s), as soundness requires.
- Nominal raw transmitted-data opportunity under the link model, T_cert × 10 Mb/s (OOK at
  BER ≤ 1e-6, no protocol overhead; not throughput):
  - each Certified cell: 200 Mb (25 MB) over 20 s;
  - the unresolved cells: median 30 Mb, maximum 185 Mb;
  - 32 of them guarantee ≥ 40 Mb (≥ 4 s) and 13 guarantee ≥ 100 Mb (≥ 10 s).
- Figure `figures/fig_tcert.pdf`: the hero-map layout coloured by T_cert. Hatched cells are
  Falsified; a frame marks the three cells falsified by Check 1.

**Reading.**
- The unresolved territory has two parts:
  - At w ≥ 0.05 m/s and low noise, the current alone drives the bearing to roughly 50-90 % of the FOV
    margin within 20 s. Three of these cells are now falsified, and the rest lie within a few
    degrees of the edge. They are limited by the physics of a surge-and-yaw controller with no
    bearing restoring term, not by the tool.
  - At loc ≥ 0.3 m or w = 0, the drift is small, and the obstruction is noise-driven set
    growth inside the reach.
- The graded metric T_cert separates the two parts. It shows that low-noise cells still carry
  roughly 10 s of guaranteed link time, and high-noise cells only 0.5-3 s.

### 12k. Rx FOV vs localisation trade-off (campaign A)

Sources:
- `code/run_fov_loc.m` → `ccv/ccv_fov45_res_32.csv|mat`, `ccv/ccv_fov20_res_32.csv|mat`,
  `ccv/ccv_summary_fov{45,20}_res_32.csv` (log: `logs/fov_loc.log`);
- `code/fov_loc_summary.m` → `fov_loc/fov_loc_table.csv` and `figures/fig_fov_loc.pdf`.

The 30° points are reused from `ccv_summary_2d_res_32.csv` (0.05, 0.1 and 0.3 m) and
`ccv_summary_a3_box_res_32.csv` (0.15, 0.2 and 0.25 m).

Setup:
- planar CCV of res_32 on the full Sec. 5 tiling (d0 1-12 m × φ0 ±30°), clear and coastal
  water, |w| ≤ 0.025 m/s;
- FOV variants built with `link_variant` exactly as in B1 (concentrator gain,
  background-limited P_min and K recomputed; K = 27.98 / 25.47 / 22.93 dB for
  20 / 30 / 45°);
- new runs at loc 0.05-0.3 m for 20° and 45°;
- wall time 8,520 s.

Certified area (CCV) / empirical viable area (EVV), m²:

| loc (m) | Clear 20° | Clear 30° | Clear 45° | Coastal 20° | Coastal 30° | Coastal 45° |
|---|---|---|---|---|---|---|
| 0.05 | 12.3 / 17.2 | 19.5 / 24.9 | 24.0 / 25.1 | 0 / 6.0 | 3.67 / 10.0 | 8.94 / 10.1 |
| 0.10 | 10.3 / 17.3 | 16.1 / 24.9 | 22.3 / 25.8 | 0 / 6.0 | 3.27 / 10.2 | 7.94 / 10.1 |
| 0.15 | 7.16 / 18.2 | 10.1 / 24.9 | 19.2 / 25.1 | 0 / 6.0 | 2.79 / 9.99 | 5.63 / 10.1 |
| 0.20 | 1.70 / 17.2 | 4.71 / 24.8 | 14.5 / 25.1 | 0 / 6.1 | 0 / 9.64 | 0 / 10.1 |
| 0.25 | 1.70 / 18.2 | 1.57 / 24.9 | 4.71 / 25.1 | 0 / 5.7 | 0 / 9.49 | 0 / 10.1 |
| 0.30 | 1.70 / 17.3 | 0 / 24.9 | 0 / 25.1 | 0 / 6.0 | 0 / 9.08 | 0 / 10.1 |

**Reading.**
- **A wider FOV enlarges the certified area at every localisation level where anything
  is certified.**
  - In clear water, 45° vs 30° gives 24.0 vs 19.5 m² at 0.05 m, 14.5 vs 4.7 m² at 0.2 m,
    and 4.7 vs 1.6 m² at 0.25 m.
  - In coastal water, 45° vs 30° gives 8.9 vs 3.7 m² at 0.05 m and 5.6 vs 2.8 m² at
    0.15 m.
  - At 45° the certified area nearly fills the EVV at small loc: the gap is 5 % (clear)
    and 11 % (coastal) at 0.05 m. The demonstrated false-assurance area is 0-0.63 m² at
    every level.
- **The localisation limit barely moves.** With 45°, clear water still has no certified
  tile at 0.3 m (0 m²), and coastal water still has none from 0.2 m (as at 30°). The
  wider FOV raises the curve but leaves the cut-off where it was. In clear water at
  0.25-0.3 m, 20-25 m² stays Inconclusive at every FOV. This matches A2/A3: what limits
  certification at large loc is noise-driven growth of the over-approximation, not the
  Rx predicate.
- **20° is worse almost everywhere.**
  - The clear CCV is lower than at 30° up to 0.2 m, and the coastal CCV is 0 at all
    levels.
  - The EVV shrinks (clear about 17-18 m², coastal about 6 m²), because the narrower FOV
    makes Rx loss more frequent.
  - One exception: in clear water at 0.25 and 0.3 m, 20° keeps 1.70 m² certified. These
    are the 4 tiles at d0 = 9.75 m, |φ0| = 5° (`ccv_fov20_res_32.csv`).
  - The higher concentrator gain (K +2.5 dB) extends the power range beyond the 30°
    range limit. At that distance the bearing error from a 0.3 m localisation error is
    only asin(0.3/9.75) = 1.8°.
  - So the localisation limit is really a limit on loc/d, and a far, narrow-FOV tile can
    be certifiable where near tiles are not.
- **Answer to the question:** no. A 45° FOV does not produce certificates at 0.3 m. It
  buys certified area below the cut-off, at the cost of 2.5 dB of link budget. Only the
  narrow 20° FOV, through its longer power range, gives a sliver at 0.3 m.

### 12l. B3: a sway-capable AI controller (res_32_sway)

Sources:
- training: `code/run_b3_train.m` → `b3/actor_res_32_sway.mat`, `b3/imitation_error.csv`,
  `b3/closed_loop_performance.csv`, `b3/closed_loop_summary.csv`;
- evaluation: `code/run_b3_eval.m` (log: `logs/b3_eval.log`) →
  - `b3/hero_rx_cells.csv|mat` and `b3/hero_rx_compare.csv`;
  - `ccv/ccv_b3w025_res_32_sway.*` and `ccv/ccv_b3w050_res_32_sway.*`;
  - `b3/shieldB_mc.csv`;
- summaries: `code/b3_summary.py` → `b3/hero_rx_summary.csv`, `b3/ccv_status_summary.csv`.

The model is documented in `code/MODEL.md` Sec. 7. Wall time: training 49 s; evaluation
2,473 s.

**Design.**
- The extended teacher adds v_c = sat(0.5 φ̂), with |v_c| ≤ 0.3 m/s, to the classical law.
  This is the S1 fallback's sway law, with no gating.
- res_32_sway is a residual MLP (2×32 ReLU + linear skip) on [d̂, ê, u, v, r, ĉ, φ̂] with
  outputs [u_c, r_c, v_c], trained by imitation as res_32 was.
- Imitation is close (rollout test set): RMSE 6.8e-4 m/s (u_c), 1.1e-5 rad/s (r_c) and
  5.0e-6 m/s (v_c).
- The sway command uses the existing sway inner loop. The CORA model is the fallback model
  `aug_dyn_fb`, whose damping envelope |v| ≤ 0.35 m/s covers |v_c| ≤ 0.3.
- Reach settings: 0.02 s step, 6 Taylor terms, order 100. Reachability is skipped on
  MC-falsified cells, which leaves the verdicts unchanged.

**Sampled performance** (36 scenario groups × 300 runs, training bounds,
`closed_loop_summary.csv`):

| | Mean outage | Tx share | Rx share | Power share |
|---|---|---|---|---|
| res_32 | 0.167 | 0.007 | 0.136 | 0.064 |
| res_32_sway | 0.045 | 0.017 | 0 | 0.029 |

On the shield-B current steps, with no shield (`shieldB_mc.csv`; 200 runs per row; Wilson
95 % CI in brackets):

| Row | res_32 | res_32_sway |
|---|---|---|
| B 1.0× | 6/200 (3.0 %) | 0/200 [0, 1.9 %] |
| B 1.5× | 33/200 (16.5 %) | 0/200 |
| B 2.0× | 56/200 (28.0 %) | 0/200 |
| B 3.0× | 79/200 (39.5 %) | 0/200 |
| C spikes | 13/200 (6.5 %) | 0/200 |

- All res_32 outages here are Rx.
- The res_32 counts reproduce the NN column of S5 to within one outage. The draws differ
  because these runs used the client RNG stream rather than the pool workers' stream.
- **Empirically, sway authority in the controller removes the Rx-FOV failures and matches
  the shielded system without any shield.**

**Hero-map cells where Rx dominated** (|w| ≥ 0.05 m/s, loc ≤ 0.3 m, 120 cells,
`hero_rx_summary.csv`):

| | Certified | Falsified (Tx / Rx / power) | Inconclusive | Mean MC outage |
|---|---|---|---|---|
| res_32 | 4 | 88 (12 / 76 / 0) | 28 | 0.302 |
| res_32_sway | 0 | 49 (26 / 2 / 21) | 71 | 0.084 |

Transitions from res_32 to res_32_sway:
- Certified → Inconclusive: 4;
- Falsified → Falsified: 49;
- Falsified → Inconclusive: 39;
- Inconclusive → Inconclusive: 28.

Turbid water stays Falsified in all 40 cells.
- Provenance shifts from Rx (76 → 2) to Tx (12 → 26) and power (0 → 21). The sway motion
  trades the bearing problem for pointing and range excursions.
- 68 of the 71 Inconclusive cells are set explosions, and 3 left the damping envelope.

**Planar CCV at loc 0.1 m** (clear / coastal, m²; `ccv/ccv_summary_b3w*_res_32_sway.csv`,
`b3/ccv_status_summary.csv`):

| |w| bound | Controller | CCV | EVV | EVV falsified | EVV inconclusive |
|---|---|---|---|---|---|
| 0.025 | res_32 | 16.1 / 3.27 | 24.9 / 10.2 | 0.52 / 2.99 | 8.20 / 3.95 |
| 0.025 | res_32_sway | **0 / 0** | 37.3 / 14.4 | 6.26 / 4.76 | 31.0 / 9.64 |
| 0.05 | res_32 | 2.49 / 0 | 19.6 / 5.56 | 2.44 / 2.09 | 14.7 / 3.47 |
| 0.05 | res_32_sway | **0 / 0** | 37.3 / 14.4 | 12.7 / 6.24 | 24.7 / 8.16 |

- Every non-certified empirically viable tile of res_32_sway is a set explosion (71 + 36 at
  0.025 m/s), except one damping-envelope exit at 0.05 m/s.
- res_32's unresolved tiles at 0.025 m/s are mostly "possible violation", not explosion.

**Reading.**
- **Sway authority helps empirically and hurts verifiably.**
  - The empirically viable area grows by 50 % (clear) and 41 % (coastal) at
    |w| ≤ 0.025 m/s, and it is insensitive to doubling the current bound.
  - Rx-FOV failures almost disappear: in the hero cells, Rx witnesses fall from 76 to 2.
  - But no cell or tile is certified. The 4 hero cells and the 16.1 / 3.27 m² CCV that
    res_32 certifies are lost.
- **The extra input dimension makes verification harder.** The sway command is driven by
  the bearing estimate φ̂. Its error, asin(loc/d) + noise, enters a third actuated channel
  at every step, so the reachable v interval and then the d and φ widths grow until the
  set explodes.
- A pilot on a cell that res_32 certifies (clear, 4 m, loc 0.1, w 0.025) shows the order
  and step sensitivity of the explosion time:
  - 0.05 s step, order 100: 10.5 s;
  - 0.05 s step, order 200: 12 s;
  - 0.02 s step, order 200: 16 s.

  None reached 20 s.
- **The empirical gain also contains more false assurance.** The falsified part of the EVV
  rises to 6.3 / 4.8 m² at 0.025 m/s, with power and Tx witnesses.
- **Answer.** Giving the controller sway authority removes the Rx-FOV failure mode in
  simulation. It also replaces the certified envelope with a larger but entirely
  uncertified one. With this verification stack (CORA polynomial zonotopes, box noise, a
  20 s horizon), the extra actuated input does not enlarge the certified envelope; it
  removes it.
- Possible routes, not tried here:
  - a lower k_φ, or filtering of φ̂, to reduce the noise gain;
  - a shorter certified horizon with chaining;
  - the shield architecture of 7b/12f, which keeps a certifiable nominal controller and
    uses sway only in the fallback.

### 12m. Assurance co-design table (campaign D)

Sources: `code/run_codesign.m` → `codesign/codesign_table.csv` and
`figures/fig_codesign.pdf`. Only the combined row was computed, as
`codesign/ccv_combined_res_32_sway.csv|mat` and its summary (wall 1,184 s, log
`logs/codesign.log`). The other rows reuse:
- `ccv/ccv_summary_2d_res_32.csv` (Sec. 5);
- `ccv/ccv_summary_fov45_res_32.csv` (12k);
- `ccv/ccv_summary_b3w025_res_32_sway.csv` (12l).

All rows are planar CCV / EVV at |w| ≤ 0.025 m/s. The navigation upgrade is represented
by a smaller declared localisation bound (0.05 m instead of 0.1 m), as a proxy for a
better estimator. res_32_sway has no certificate in its own row (12l), so the control
upgrade is reported for completeness. Because of that, the table adds an "optical +
navigation" row: the combined system without the control upgrade, reused from 12k.

| System | FOV | Controller | loc (m) | Clear CCV / EVV (m²) | Clear gap | Clear ΔCCV | Coastal CCV / EVV (m²) | Coastal gap | Coastal ΔCCV |
|---|---|---|---|---|---|---|---|---|---|
| Baseline | 30° | res_32 | 0.10 | 16.1 / 24.9 | 35 % | (base) | 3.27 / 10.2 | 68 % | (base) |
| Optical upgrade | 45° | res_32 | 0.10 | 22.3 / 25.8 | 13 % | +38 % | 7.94 / 10.1 | 21 % | +143 % |
| Control upgrade | 30° | res_32_sway | 0.10 | 0 / 37.3 | 100 % | −100 % | 0 / 14.4 | 100 % | −100 % |
| Navigation upgrade | 30° | res_32 | 0.05 | 19.5 / 24.9 | 22 % | +21 % | 3.67 / 9.99 | 63 % | +12 % |
| Optical + navigation | 45° | res_32 | 0.05 | 24.0 / 25.1 | 5 % | +49 % | 8.94 / 10.1 | 11 % | +173 % |
| Combined (all three) | 45° | res_32_sway | 0.05 | 4.15 / 25.1 | 84 % | −74 % | 0 / 10.1 | 100 % | −100 % |

**Reading.**
- **The optical upgrade gives the most certified area.**
  - The optical upgrade alone adds +38 % (clear) and +143 % (coastal), while the EVV
    barely moves (+4 % / −1 %). It turns unresolved area into certified area.
  - The navigation upgrade alone adds +21 % / +12 %.
- **Optical and navigation gains interact differently by water.**
  - Clear water is sub-additive: +49 % for both, against +59 % for the sum. The certified
    area saturates, since the gap is already 5 % and EVV caps the gain.
  - Coastal water is super-additive: +173 % against +155 %.
  - In both waters the combination leaves almost no unresolved area (1.1 m²) and no
    demonstrated false assurance (0 m²).
- **The control upgrade works against assurance.** With sway authority, the EVV grows by
  50 % / 41 % but the CCV drops to 0 (12l).
  - In the most favourable setting (45°, 0.05 m), res_32_sway gets its first certificates:
    4.15 m² in clear water, 8 tiles at d0 = 4.75-6.75 m and |φ0| = 5°. That is still 74 %
    below the baseline and 83 % below the optical + navigation system with res_32.
  - Coastal water stays at 0.
  - The remaining viable tiles are set explosions: 64 clear and 41 coastal.
- **Co-design recommendation from these numbers:**
  - buy optics (FOV) and navigation accuracy for the certified envelope;
  - keep the nominal controller without sway;
  - put the sway authority in the shield fallback (12f), not in the verified nominal
    controller.

### 12n. Slowly varying current (campaign E)

Sources:
- method and soundness argument: `slowcur/METHOD.md` (written before the campaign, with an
  addendum after the unit tests);
- `code/run_slowcur.m` → `slowcur/slowcur_R0.csv|mat`, `slowcur/slowcur_R1.csv|mat`,
  `slowcur/ccv_slowcur_R{0,1}_res_32.*`, `slowcur/ccv_summary_slowcur_R{0,1}_res_32.csv`
  (log: `logs/slowcur.log`);
- `code/slowcur_summary.py` → `slowcur/summary.txt`;
- witness checks: `code/replay_slowcur_witness.m` → `slowcur/witness_R0_cell95.txt`,
  `code/verify_ccv_witness_slowcur.m` → `slowcur/ccv_witness_check.txt`;
- unit tests: `code/test_slowcur.m` (logs `logs/slowcur_test*.log`, outputs in `slowcur/dev/`).

Wall time on 10 workers: R0 cells 4,231 s; R1 cells 1,300 s; CCV R0 1,486 s; CCV R1 1,622 s.

**Question.** The reference CORA model lets the current vary arbitrarily in time inside its
box. Does temporal structure (a slowly varying current) enlarge the certified envelope, or
does the constant worst-case sideways current already dominate?

**Model** (`reach_cell.m` option `cellc.curModel = 'rate'`, default unchanged).
- The current becomes two states, its polar components (w_r, w_t). For a world-frame current
  W with dW/dt = μ, they obey dw_r/dt = φ'·w_t + ν_r and dw_t/dt = −φ'·w_r + ν_t, with
  ν = R(φ)μ. A constant world current is a rotation of (w_r, w_t) at the bearing rate.
- The initial current ranges over the octagon O(w0) that contains the declared disk.
- Regimes:
  - **R0, quasi-static**: ρ = 0, a constant current of unknown direction and magnitude ≤ w0;
  - **R1, slow**: |dW_x/dt|, |dW_y/dt| ≤ ρ = 0.157·w0 per second, enough to rotate the
    current by 90° in 10 s at w0;
  - **reference**: the box model of Sec. 3 and 12a.
- Magnitude bound. R0 needs no clipping: the exact flow is a rotation and keeps |w| ≤ w0.
  For R1, after each 0.5 s period the current block is re-enclosed by fresh octagon factors
  if it may leave O(w0). This is sound because the true current is in the disk at every
  sample. The effective bound inside the R1 reach is about 1.20·w0, against √2·w0 for the
  reference box.
- Re-enclosing after every period is also sound for R0. It gave a tighter enclosure than
  keeping the dependence on the initial current (unit tests, METHOD Sec. 7). The campaign ran
  both for R0 and certifies a cell if either does.
- Monte Carlo (500 runs) and the cross-entropy falsifier (200 × 25) sample the same regime
  (`cur_rate_wfun`: paths with |W| ≤ w0 and a rate ≤ ρ, constant for R0). The sideways
  adversary of 12j runs in its constant-current mode, which is admissible in both regimes.
- The exact models are nested: R0 ⊂ R1 ⊂ reference. A reference certificate is therefore also
  an R1 and an R0 certificate, and a regime witness is also a reference witness.

**Cells.** The 67 unresolved hero-map cells (the 70 of 12h minus cells 179, 198 and 205,
falsified in 12j), the 32 Certified cells, and the planar CCV at loc 0.1 m, clear and
coastal, |w| ≤ 0.025 m/s.
- 13 unresolved and 18 Certified cells have w0 = 0. With no current all three models
  coincide, so their reference verdicts carry over and they were not re-run.
- Reach passes per cell (A2 settings): order 100 then order 200, splitting depth 2,
  re-enclosing the current every period; for R0 also order 100 with the dependence kept.
- R1 was run on the cells that R0 certifies. In exact arithmetic R1 cannot certify a cell
  that R0 does not.

**Transitions of the 67 unresolved cells** (54 with w0 > 0 re-run):

| Reference reason → regime outcome | R0 | R1 |
|---|---|---|
| Certified | **0** | 0 (not run: R0 certified none) |
| Falsified | **1** (cell 95, from set explosion) | 1 (the R0 witness is admissible in R1) |
| Set explosion → set explosion | 47 | |
| ACE touched → ACE touched (Rx 5, power 1) | 6 | |
| w0 = 0, carried over | 13 | 13 |

- **67 → 0 certified + 1 falsified + 66 unresolved under R0.** Each re-run cell keeps its
  reference reason.
- The 6 ACE-touched cells first touch at 6.1 s (power, turbid) and 10.7-19.8 s (Rx).
  Constraining the current to be constant does not stop the reach from touching the edge.
- **Near-edge cells (39, class "borderline" in 12j).** Under R0, 38 stay unresolved (32 set
  explosion, 5 Rx, 1 power) and 1 is falsified (cell 95). None is certified.
- **Keeping the dependence on the initial current** (54 cells, R0) certified none: 48 set
  explosion, 3 explosion with `model-range`, 2 ACE touched, 1 ACE touched then explosion. On the test cell it exploded at 9.5 s,
  where the reference touched Rx at 13.6 s. More dependence makes the 'lin' enclosure looser
  here, not tighter.

**New witness: cell 95** (clear, 6.5 m, loc 1 m, w0 0.075 m/s; the 0.09 deg near miss of 12j).
- The R0 cross-entropy falsifier found a Tx-cone violation at 19.35 s, robustness −0.074 deg.
  A client-side rerun from the recorded seed gives −0.217 deg.
- Replay with explicit bound checks:
  - constant current of 0.072 m/s at 138° (inside the disk, rate 0);
  - localisation bias 1.0 m and heading bias 1.0° (both at their bounds), velocity biases at
    their bounds;
  - x0 inside the cell box, true c = 1.1 c_nom.
- A 4× finer simulation step gives the same robustness. The boresight error reaches 15.2°,
  against a Tx half-angle of 15°.
- The witness is admissible in the reference model as well. So cell 95 moves from
  unresolved to **Falsified** in the reference headline.
- Earlier searches missed it. The A2 strong falsifier samples a family that contains this
  scenario (rotation rate 0 is allowed). The 12j sideways family does not: there the
  localisation bias is perpendicular to the line of sight within ±60°, while here it starts
  close to the line of sight and rotates relative to it. The violation is again in the last
  second of the horizon.

**Certified cells (sanity check).**
- R0, regime enclosure alone: **32 of 32 stay certified** (14 re-run, all in pass 1). The
  certified margin bound changes by −0.00 to +0.33 dB (median +0.09 dB) against the operating
  map.
- R1, regime enclosure alone: 13 of the 14 re-run cells stay certified. Cell 10 (clear, 3 m,
  loc 0.1, w 0.05) touches Rx; it is also the cell that chaining could not re-prove (12h).
  - This is an enclosure effect, not a contradiction. Per axis, the R1 enclosure admits
    |w_t| up to about 1.11·w0 within a period, while the reference box stops at w0. 12i
    showed that the per-axis extent drives the growth.
  - By nesting, the reference certificate also certifies cell 10 under R1. With the nesting
    rule, R1 keeps all 32.
  - The R1 margin bound changes by −0.15 to +0.04 dB.

**CCV** (Sec. 5 settings, loc 0.1 m, |w| ≤ 0.025 m/s; m²):

| Model | Clear CCV | Clear EVV | Clear EVV falsified | Coastal CCV | Coastal EVV | Coastal EVV falsified |
|---|---|---|---|---|---|---|
| reference (box), Sec. 5 | 16.14 | 24.87 | 0.52 | 3.27 | 10.21 | 2.99 |
| campaign C (disk), 12i | 16.14 | 24.87 | 0.52 | 3.27 | 9.99 | 2.53 |
| R0 | **16.14** | 24.87 | 0.92 | **3.27** | 9.99 | 2.77 |
| R1, regime enclosure alone | 15.77 | 24.87 | 0.92 | 3.27 | 10.10 | 3.12 |

- **The certified area does not change under R0.** The 46 certified tiles are the same, and no
  tile gains a certificate.
- R1 loses one tile under its own enclosure (clear, 4.25 m, φ0 −15°), for the per-axis reason
  above. With the nesting rule the R1 CCV equals the reference CCV.
- Tile transitions, reference → R0, over 264 tiles:
  - 3 Inconclusive → Falsified (clear 2.25 m, φ0 ±15°; coastal 2.75 m, −15°);
  - 1 Falsified → Inconclusive (coastal 2.75 m, +15°). The reference witness there used a
    rotating current that R0 does not admit, and the regime falsifier found none.
- The 3 new witnesses were re-found on the client and replayed (`ccv_witness_check.txt`):
  - each is a constant current of magnitude exactly w0, with the other bounds respected;
  - each violates Rx at 19.55-19.95 s, with robustness −0.017 to −0.216 deg, the same at a
    4× finer step.

  They are admissible in the reference model, so the reference false-assurance area in clear
  water at loc 0.1 m grows by 2 tiles (0.39 m²).
- The EVV differences between runs are the seed-to-tile effect of 12g and 12i.

**Soundness checks.**
- `soundness_violation` = 0 in every row: cells R0 and R1, CCV R0 and R1.
- The regime falsifiers on every regime-certified cell with w0 > 0 found no witness:
  - R0, 14 cells: smallest robustness 3.67 deg (cross-entropy), 3.67 (sideways), 3.84 (Monte
    Carlo);
  - R1, 13 cells: 3.67, 3.67 and 3.81.
- Simulated R0 and R1 trajectories (300 per test) stayed inside the stored reach boxes at
  every step: cell 2 over 8 s; cells 2 and 10 over 20 s for the always-reset R0 enclosure.
- The 3 cells falsified in 12j stay falsified in both regimes. The constant-current sideways
  adversary re-finds each one: robustness −0.25, −0.32 and −1.87 deg (R0), Rx at 18.4-19.9 s.

**Updated headline (130 empirically viable hero-map cells).**
- **Certified 32**.
- **Falsified 32**: 31, plus cell 95 (Tx).
- **Unresolved 66**: near the edge 38, tool-limited 28.

**Reading.**
- Temporal structure in the current does not enlarge the certified envelope. A constant
  current of unknown direction (R0) is the most restrictive regime, and it certifies exactly
  the same cells and tiles as the reference model, which allows arbitrary time variation.
- This is consistent with 12h and 12j. The bearing is a neutral integrator, and the
  constant sideways current already produces the worst drift. Arbitrary switching adds
  little reachable spread beyond what a constant current produces.
- The remaining obstruction is set explosion, driven by noise, plus the Rx and Tx edges. All
  four new witnesses use a constant current, so slow currents are not benign.

### Errata (2026-10-06)
- **§12n:** the three new constant-current CCV witnesses add false-assurance area in BOTH waters. Clear gains
  0.39 m², giving 0.92 m² at loc 0.1. The coastal tile (2.75 m, −15°) adds 0.24 m², giving 3.23 m² at loc 0.1. By
  nesting, the same coastal witness also applies at loc 0.15 m; that was not re-run.
- **§12l:** the extra falsified area of res_32_sway is by power and Rx (ccv_status_summary.csv), not power and Tx.
- **§12j:** over the 66 cells still unresolved, the median certified link duration is 3.25 s and the median raw
  opportunity is 32.5 Mb.
