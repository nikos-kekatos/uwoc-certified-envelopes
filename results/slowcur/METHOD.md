# Campaign E: slowly varying current model (method and soundness argument)

Written 2026-10-05, before the campaign. Code: `code/aug_dyn_rate.m`, `code/reach_cell.m`
(option `cellc.curModel = 'rate'`), `code/cur_rate_wfun.m`, `code/mc_scen.m`,
`code/falsify_cell.m`, `code/slowcur_sideways.m`, `code/slowcur_cells.m`, `code/run_slowcur.m`.

## 1. Question

The reference CORA model takes the current as polar components (w_r, w_t) in the box
[−w0, w0]², with arbitrary time variation. Real currents vary slowly. Campaign E asks whether
temporal structure in the current enlarges the certified envelope, or whether the constant
worst-case sideways current already dominates.

## 2. Augmented state and declared current model

- The current is W = (W_x, W_y) in the world frame (the line of sight at φ = 0 is the +x
  axis, as in `mc_scen`). The plant sees its polar components
  w_r = W_x cos φ + W_y sin φ and w_t = −W_x sin φ + W_y cos φ (the map `polarw` used by
  every simulator).
- CORA state x = [d, φ, e, u, v, r, w_r, w_t] plus the held commands (u_c, r_c). With
  dW/dt = μ, differentiation gives dw_r/dt = φ'·w_t + ν_r and dw_t/dt = −φ'·w_r + ν_t, with
  ν = R(φ)μ. A constant world current is therefore a rotation of (w_r, w_t) at the bearing
  rate. This polar form keeps the plant affine in the current. A first version with W in the
  world frame (plant terms W·sin φ, W·cos φ over a bearing interval up to 1 rad) exploded
  earlier than the reference on the test cell, so it was replaced before the campaign.
- Declared model: |W(t)| ≤ w0 for all t (the disk), and |dW_x/dt|, |dW_y/dt| ≤ ρ.
- Regimes:
  - **R0, quasi-static**: ρ = 0. W is constant, with unknown direction and magnitude ≤ w0.
  - **R1, slow**: ρ = (π/2)·w0/10 s = 0.157·w0 per second. At magnitude w0 a rotation of 90°
    in 10 s has |dW/dt| = 0.157·w0, so it is admissible.
  - **Reference**: the existing box model (Sec. 3, 12a). Campaign C (octagon enclosure of the
    disk, still arbitrary in time) isolates the effect of time structure from the effect of
    the set shape, where its results are available.
- Every R0 current is admissible in R1, and every R1 current is admissible in the reference
  (its polar components stay in the disk, hence in the box). So exact certified sets are
  nested: reference ⊆ R1 ⊆ R0. A cell certified under the reference must remain certifiable
  under R0 and R1 in exact arithmetic; the over-approximation can still lose it.

## 3. CORA enclosure and soundness

- **Initial current**: (w_r, w_t)(0) = R(φ0)W(0) lies in the disk |w| ≤ w0 (the disk is
  rotation invariant). It is enclosed by the octagonal zonotope O(w0) with four generators
  of length w0 tan(π/8) at 0°, 45°, 90°, 135° (as in campaign C). O(w0) = {w : |n_j·w| ≤ w0,
  j = 1..4} with n_j at the same four angles, so O(w0) contains the disk. The initial current
  is independent of the cell box.
- **Dynamics** (`aug_dyn_rate.m`): the rotation terms above, plus ν as a time-varying bounded
  input of `nonlinearSys`. For every φ, R(φ)[−ρ, ρ]² lies in the disk of radius √2ρ, which is
  enclosed by the octagon O(√2ρ); this octagon is the input set. For ρ = 0 the input is 0.
- **R0 soundness**: the CORA model is the exact closed loop for every constant world current
  whose initial polar value lies in O(w0); CORA over-approximates all its trajectories. The
  declared R0 set (W constant in the disk) is a subset. No clipping is needed: the exact flow
  is a rotation and preserves |w|, so the magnitude stays ≤ w0 for every declared current. The effective
  magnitude bound inside the reach is the octagon, |W| ≤ w0 sec(π/8) = 1.082·w0, against
  √2·w0 = 1.414·w0 for the reference box.
- **R1 and the magnitude bound (clip by re-enclosure)**: without clipping, the rate-bounded
  set grows by ρt per axis, which reaches 3.1·w0 at 20 s and would be weaker than the
  reference. Instead, after each control period (t_k = 0.5k s) the carried current set is tested
  against O(w0) with interval bounds of n_j·W (sound upper bounds of the support function).
  If it may leave O(w0), the current rows of the polynomial zonotope are replaced by fresh
  independent factors that span O(w0); the rows of [d, φ, e, u, v, r] and their factors are
  kept unchanged.
  - Soundness: every true state at t_k satisfies x ∈ Π_x(R_k) and |w| = |W| ≤ w0, so
    w ∈ O(w0). The new set is exactly Π_x(R_k) × O(w0), which contains every true pair (x, w).
    The next period then integrates the model from it.
  - Effective bound: the carried current set at every t_k lies in O(w0) (it passed the test or
    was reset). Inside a period the rotation part preserves the magnitude and the input adds at
    most O(√2ρΔ), Δ = 0.5 s. For R1 (√2ρΔ = 0.111·w0) the reach therefore admits currents up to
    about 1.082·(1 + 0.111)·w0 = 1.20·w0, a slightly larger set than the declared R1 model and
    still smaller than the reference box (√2·w0).
  - The reset loses the correlation of W with x. This is a conservatism of the enclosure, not
    of the model. The count of resets is reported per cell.
- The world-frame rate box enters through ν ∈ O(√2ρ), which contains R(φ)[−ρ, ρ]² for every φ.
- **Unchanged parts**: actor, noise injection (fresh factors per step), damping surrogate
  and its envelope check, ACE checks, splitting (only the six cell coordinates are split).
  For w0 = 0 the current block is identically zero and the model equals the reference.

## 4. Changes to reach_cell.m (option, default unchanged)

`cellc.curModel = 'rate'` with `cellc.rho` (m/s², per world axis) selects `aug_dyn_rate`
(10 states, 5 inputs [ν_r, ν_t, damping errors]), builds X0 = box × O(w0), and, for ρ > 0,
applies the per-period test and reset (`res.nReset`). `cellc.rateResetTol` (default 0) would
relax the test threshold to w0(1 + tol); it is not used in the campaign. Without the field,
or with any other curModel, the code path is the old one.

## 5. Monte Carlo and falsifier sample the same model

- `cur_rate_wfun` generates paths W(t) = m(t)[cos a(t), sin a(t)] with
  m(t) = clamp(m0 + ṁt, 0, w0), |ṁ| ≤ ρ, and a rotation rate |ω| ≤ (ρ − |ṁ|)/w0 that may
  reverse once at t_s. Hence |W(t)| ≤ w0 and |dW_i/dt| ≤ |ṁ| + m|ω| ≤ ρ. For ρ = 0 the path is
  constant. Admissibility was checked numerically (`test_slowcur.m`, 2,000 paths per regime).
- `mc_scen` (MC, 500 runs per cell) uses these paths with m0 = w0√U (uniform on the disk)
  when curModel = 'rate'; `falsify_cell` (cross-entropy) uses them with two extra parameters
  (reversal time, magnitude ramp). The noise families are unchanged.
- `slowcur_sideways` runs the Sec. 12j sideways adversary restricted to its `const` mode
  (constant world current of magnitude w0, perpendicular ±30°), which is admissible in both
  regimes; `track` and `switch` are not admissible in R0, and `switch` not in R1.

## 6. Campaign and reporting

- Cells: the 67 unresolved hero-map cells (the 70 of Sec. 12h minus cells 179, 198, 205,
  falsified in Sec. 12j by constant currents that are admissible in R0 and R1), and the 32
  Certified cells. Planar CCV at loc 0.1 m, clear and coastal, |w| ≤ 0.025 m/s.
- Reach settings: those of A2 (pass 1 order 100 with splitting depth 2; pass 2 order 200 for
  cells still unknown), so that the comparison with the reference A2 result and campaign C is
  like for like. CCV with the Sec. 5 settings (`run_ccv`).
- R0 on all cells. R1 on all cells that R0 certifies (in exact arithmetic R1 cannot certify a
  cell that R0 cannot, because the R1 model contains the R0 model).
- Every new certificate is attacked by the regime falsifier (cross-entropy 200 × 25) and by
  the constant sideways adversary; any witness would be a soundness violation. The regime
  falsifiers also run on the cells that stay unresolved (a witness there is also a witness
  for the reference model).
- Transitions: certified / falsified / unresolved by reason (explosion, ACE touched with
  predicate, model-range), per regime; the 39 near-edge cells reported separately.

## 7. Addendum after the unit tests (before the full campaign)

- Unit tests (`code/test_slowcur.m`, logs `logs/slowcur_test*.log`) on cells 2 (clear, 3 m,
  loc 0.05, w 0.025, Certified) and 4 (clear, 3 m, loc 0.05, w 0.075, unresolved) showed that
  keeping the dependence on the initial current makes the enclosure looser than the
  reference: on cell 4 the R0 reach exploded at 9.5 s, against an Rx touch at 13.6 s for the
  box, also at zonotope order 200. Re-enclosing the current by fresh octagon factors after
  every period (`cellc.rateReset = 'always'`, sound by the argument of Sec. 3 because
  |w| ≤ w0 at every t_k) gave the tightest enclosure (cell 2: margin bound 8.19 dB against
  8.11 dB for the box; cell 4: Rx touch at 13.65 s).
- Campaign passes per cell: pass 1 always-reset, order 100, depth 2; pass 2 always-reset,
  order 200, depth 2; pass 3 (R0 only) keep-dependence, order 100, depth 2. A cell is
  certified in a regime if any pass certifies it.
- Nesting rule used in the report: the reference model contains R1 and R0, so a reference
  certificate is also a certificate for R1 and R0. Results are reported both for the regime
  enclosure alone and with this rule.
- Enclosure check: 300 simulated R0 trajectories (keep-dependence enclosure) and 300 R1
  trajectories (automatic reset) of cell 2 over 8 s stay inside the stored
  reach boxes of (d, φ, e) at every simulation step (0 samples outside).
- The same check for the always-reset R0 enclosure over the full 20 s, cells 2 and 10
  (clear, 3 m, loc 0.05/0.1, w 0.025/0.05), with 300 R0 trajectories each: 0 samples outside.
