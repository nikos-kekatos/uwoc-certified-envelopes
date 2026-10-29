# Model used by the UWOC assurance pipeline (calibrated set "v1", 2026-10-04/05)

All constants are set in `uwoc_params.m`.
- **VERIFIED**: the number was read in the cited source (checked by a literature pass
  on 2026-10-04).
- **ASSUMED**: a design or scenario choice. It is a declared bound or gain, not a
  physical constant.

Every certificate is conditional on this model and on the declared bounds. The earlier
provisional constants (v0) and their results are not distributed.

## 1. Water (inherent optical properties)

| Water | a (1/m) | b (1/m) | c (1/m) | Status / source |
|---|---|---|---|---|
| clear ocean | 0.114 | 0.037 | 0.151 | VERIFIED: Petzold (1972) as tabulated by Mobley, *Light and Water* (1994), Table 3.11, p.112 |
| coastal ocean | 0.179 | 0.219 | 0.398 | VERIFIED: same table |
| turbid harbor | 0.366 | 1.824 | 2.190 | VERIFIED: same table |

In Mobley's table, b is measured at 514 nm, c is measured at 530 nm, and a = c(530) − b(514).
Secondary sources (Kaushal & Kaddoum 2016, Table 4, citing Hanson & Radic 2008) quote
0.220/0.399 and 1.829/2.195; Kaushal & Kaddoum also has the typo c = 0.339. We use
Mobley's values. The declared uncertainty of c is ±10 % (ASSUMED).

## 2. Optical link

| Quantity | Value | Status / source |
|---|---|---|
| wavelength | 532 nm | VERIFIED as the system wavelength in Celik et al., IEEE TWC 19(2) 2020, Tab. I; Jamali et al., IEEE PTL 29(5) 2017, Tab. I |
| transmit power P_t | 0.1 W | VERIFIED: N'Doye, Zhang, Alouini, Laleg-Kirati, "Establishing and Maintaining a Reliable Optical Wireless Communication in Underwater Environment", IEEE Access 9:62519, 2021, Table 1 |
| source pattern | Lambertian, half-power semi-angle Φ½ = 15°, order m = −ln2 / ln cos Φ½ = 19.99 | VERIFIED: N'Doye 2021 Eq. 1 and Table 1 |
| Tx / Rx optical efficiency | 0.9 / 0.9 | VERIFIED: Celik et al. 2020, Table I |
| detector area A_r | 1 cm² | VERIFIED: N'Doye 2021, Table 1 |
| concentrator FOV Ψ_C (Rx FOV) | 30° half-angle; gain n²/sin²Ψ_C, n = 1.52 (gain 9.24) | VERIFIED: N'Doye 2021, Eq. 3 and Table 1 (hard FOV cut-off) |
| optical filter Δλ | 30 nm | VERIFIED: N'Doye 2021, Table 1 |
| detector | Si PIN, quantum efficiency 0.8 → R = ηqλ/(hc) = 0.343 A/W; T = 290 K; R_L = 100 Ω; I_dark = 1.226 nA | VERIFIED: Jamali et al. 2017, Table I (R computed by us) |
| modulation, bit rate, noise bandwidth | OOK-NRZ, 10 Mb/s, B = R_b | ASSUMED (N'Doye 2021 reports about 10 Mb/s links at metre ranges) |
| target BER | 1e-6 | ASSUMED |
| background light | E_s(532 nm, surface) = 0.7645 W/m²/nm, t = 0.95, P_b = E_s t Δλ A_eff exp(−a z_op) | VERIFIED: N'Doye 2021, Eqs. 9-10. ASSUMED: operating depth z_op = 30 m, evaluated for the clearest water with a(1 − 0.1), which gives the largest background (conservative for all water types) |

**Receiver sensitivity tied to BER.** For OOK-NRZ with a PIN receiver under Gaussian
noise (the standard textbook result, e.g. Agrawal, *Fiber-Optic Communication Systems*;
we did not check the equation number):

P_min = (Q/R)(σ₀ + qQB), with Q = Q⁻¹(BER) = 4.753 and σ₀² = σ_T² + σ_B² + σ_D².
- σ_T² = 4kTB/R_L = 1.60e-15 A²
- σ_B² = 2qRP_bB = 1.02e-15 A²
- σ_D² = 2qI_dB = 3.9e-21 A²

This gives **P_min = 7.09e-7 W = −31.49 dBm**.

**Link margin** (a single function, `margin_db.m`, used by every rung):

P_r = η_t η_r P_t (m+1)/(2π d²) cos^m(e) · A_r g cos(ψ) · exp(−c d)

M = 10 log10(P_r/P_min) = K − 20 log10 d − 4.343 c d + 10 m log10 cos e + 10 log10 cos ψ,
with K = 25.47 dB.

M decreases monotonically in d, c, |e| and |ψ|. Forward-scattering gain and turbulence
are not modelled; Beer-Lambert with the full extinction c is a conservative choice.

Aligned ranges at nominal c (from `results/phase1/ace_ranges.csv`):

| Water | M = 0 | M = 6 dB |
|---|---|---|
| clear | 9.30 m | 5.99 m |
| coastal | 5.86 m | 4.13 m |
| turbid | 2.03 m | 1.61 m |

**ACE predicates.** Each is a separate predicate; there is no zero-power encoding.

| Predicate | Form | Definition |
|---|---|---|
| ACE_Tx | b_T·ℓ = cos e ≥ cos Φ½ | receiver inside the Lambertian half-power cone |
| ACE_Rx | n_R·(−ℓ) = cos ψ ≥ cos Ψ_C | light inside the concentrator FOV (N'Doye's hard cut-off) |
| ACE_Power | M ≥ 0 | |
| robust | M ≥ 6 dB, plus the geometric predicates | 6 dB reserve is ASSUMED |

## 3. Vehicle: BlueROV2 Heavy (von Benzon et al., J. Mar. Sci. Eng. 10(12):1898, 2022, Table A1, VERIFIED)

Mass m = 13.5 kg; I = (0.26, 0.23, 0.37) kg m²; r_g = 0; r_b = (0, 0, −0.01) m;
displaced volume 0.0134 m³ (ρ = 1000 kg/m³, g = 9.82 m/s²).

| | surge | sway | heave | roll | pitch | yaw |
|---|---|---|---|---|---|---|
| added mass (kg, kg m²) | 6.36 | 7.12 | 18.68 | 0.189 | 0.135 | 0.222 |
| linear damping | 13.7 | 0 | 33.0 | 0 | 0.8 | 0 |
| quadratic damping | 141.0 | 217.0 | 190.0 | 1.19 | 0.47 | 1.5 |
| body-frame force/moment maxima (Table 4) | 85 N | 85 N | 120 N | 26 N m | 14 N m | 22 N m |

The paper reports added-mass uncertainty of 10-20 % for translation and 30-100 % for
rotation. It writes D = −diag(X_u, …) while listing positive values; we use them as
magnitudes.

**Actor interface and low-level control** (as in Weng et al., JFR 2024, where the
actions are surge and yaw-rate commands of ±0.2 m/s and ±0.2 rad/s):
- The actor outputs commands u_c, r_c, saturated at ±0.2 m/s and ±0.2 rad/s and held for
  0.5 s (ZOH). The 0.5 s period is ASSUMED; Weng uses 0.2 s.
- A fast low-level velocity loop, modelled in continuous time, produces the forces:
  X = K_u(u_c − u), Y = −K_v v (sway hold), N = K_r(r_c − r), with K_u = K_v = 100 N s/m
  and K_r = 5 N m s (ASSUMED gains).
- Depth hold: Z = −k_z ẑ − k_w w, k_z = 15 N/m, k_w = 40 N s/m (ASSUMED).
- 6-DOF rung only: attitude hold K = −4φ̂ − p, M = −4θ̂ − q (ASSUMED), on the estimated
  roll and pitch.

**Planar 3-DOF (rung 1)**, receiver-centred polar coordinates (d, φ, e) and
water-relative (u, v, r):

    d' = −u cos e + v sin e + w_r
    φ' = (−u sin e − v cos e + w_t)/d
    e' = r − φ'
    m11 u' = K_u(u_c − u) + m22 v r − (d11 + q11|u|)u
    m22 v' = −K_v v − m11 u r − (d22 + q22|v|)v
    m33 r' = K_r(r_c − r) − (m22 − m11) u v − (d33 + q33|r|)r

with m11 = 19.86 kg, m22 = 20.62 kg, m33 = 0.592 kg m².

**3-D reduced (rung 2)**: the planar model plus
- relative depth z, with z' = w + w_v,
- heave (m + Z_ẇ) w' = −k_z(z + δz) − k_w w − (Z_w + Z_w|w||w|)w,
- a static boresight pitch offset θ0 (mount/trim; the body is level).

The 3-D ACE uses cos e3 = (cos θ0 cos e + ζ sin θ0)/√(1+ζ²) and
cos ψ = (cos φ cos α − ζ sin α)/√(1+ζ²), with ζ = z/d and receiver tilt α.

**6-DOF (rung 3, simulation only)**: the full Fossen model
M ν̇_r + C(ν_r)ν_r + D(ν_r)ν_r + g(η) = τ, with an irrotational 3-D current, rigid-body
and added-mass Coriolis terms (including the Munk moment), restoring forces from W, B
and r_b, and the low-level loops above.

**Quadratic damping in the CORA model (rungs 1-2).** The simulators use q|x|x exactly.
The CORA model replaces x|x| by X² p(x/X), with p(t) = 0.3125 t + 0.7291 t³ (least-squares
fit on [−1, 1]). The worst-case fit error (×1.05) enters as a bounded force input, and
reach_cell asserts at every step that |u| ≤ 0.3, |v| ≤ 0.15, |r| ≤ 0.3, |w| ≤ 0.3
(otherwise the cell is Inconclusive, status `model-range`). The model is therefore
sound for the true quadratic damping inside that envelope.

## 4. Declared uncertainty (scenario bounds, ASSUMED)

| Quantity | Bound |
|---|---|
| horizontal localisation error (per control step) | 0.05-1 m (grid) |
| heading error | 1° |
| DVL velocity / gyro errors | 0.02 m/s, 0.01 rad/s |
| current | 0-0.2 m/s horizontal (grid); vertical 0.02-0.1 m/s (3-D/6-DOF levels) |
| extinction | ±10 % |
| initial cell | d0 ± 0.25 m, \|φ0\| ≤ 3°, \|e0\| ≤ 5°, u0 ∈ [0, 0.05] |
| 3-D / 6-DOF extras | depth offset, boresight pitch offset, Rx tilt, depth-estimate error, roll/pitch-estimate error 1°, initial roll/pitch 2° |

Monte Carlo and the falsifiers sample inside the same bounds. Localisation error and
current are sampled inside a disk, which lies inside the box used by reachability.

## 5. Reachability settings

- CORA v2026.1.0 (git 904a4442e68b1dc149a34e917dd63a7d3fb49a3a), nonlinearSys, alg 'lin',
  tensorOrder 2, time step 0.05 s, 8 Taylor terms, zonotope order 100.
- Sets are polynomial zonotopes; NN images use 'singh' (sound enclosures). Measurement
  noise enters as fresh independent factors each control step.
- Horizon T = 20 s.

## 6. Runtime assurance components (S1-S3, secondary contribution)

All gains and thresholds in this section are ASSUMED design choices.

**Old fallback ("slow down, turn to Rx").** u_c = 0, r_c = sat(−0.8 ê); sway is held at zero.

**Sway-capable fallback (S1, `fallback_sway.m`).** An exact piecewise-linear network on
[d̂, ê, u, v, r, ĉ, φ̂]:
- u_c = sat(0.1 (d̂ − d_ref(c))), which holds the standoff range;
- r_c = sat(−0.5 ê), which keeps the Tx cone on the receiver;
- v_c = sat(0.5 φ̂), which sways to cancel lateral drift and hold the bearing.

Limits: |v_c| ≤ 0.3 m/s (BlueROV2 Heavy maximum sway is 0.63 m/s, von Benzon 2022,
Table 4). The low-level sway loop becomes Y = K_v(v_c − v). The fallback's CORA model is
`aug_dyn_fb.m`: a wider damping-model envelope (|v| ≤ 0.35 m/s), a 0.02 s step and
6 Taylor terms.

**Certificates for the runtime checks (S1/S2, `run_shield_tables.m`).**
- Horizon H = 4 s.
- Runtime tiles: d in 0.5 m bins, φ in 5° bins over ±25°, e in {[−10,−5], [−5,5], [5,10]}°,
  with operational velocities u ∈ ±0.2, v ∈ ±0.05, r ∈ ±0.2.
- Declared bounds: |w| ≤ 0.05 m/s, localisation 0.1 m, c ±10 %.
- Tables are computed for the NN actor, the sway fallback and the old fallback.

Twenty-second certificates of the sway fallback were not obtainable: CORA's linearisation
fixpoint diverges, or the set leaves the damping envelope, after 1-7.5 s. The rolling shield
therefore relies on 4 s certificates re-checked every 0.5 s. This is a bounded-horizon
assurance argument, not an infinite-horizon one.

**Lookup shield (S2, `ShieldCtrl.lut`).** The one-step (0.5 s) numeric prediction of the
estimate under the proposed command, without current, is inflated by:
- localisation + w·Δt + 0.05 m in d;
- asin(loc/d) + w·Δt/d + 1° in φ;
- ε_ψ + asin(loc/d) + w·Δt/d + 1° in e.

The command is accepted iff every overlapping NN tile is Certified.

**Online shield (`shield_check.m`).** A CORA check over 2 s: one period of the proposed
action, then the chosen fallback, from the estimate box under the declared bounds.

**Current monitor (S3, `ShieldCtrl`).**
- Measurement: ŵ = true current + uniform error ±0.03 m/s per axis. This represents a
  DVL bottom-track minus water-track velocity, which is ASSUMED available.
- Filter: first-order low-pass with τ = 3 s.
- Flag when |ŵ_f| > the declared bound (0.05 m/s), with hysteresis at 0.9 of the threshold.
- A flag forces the fallback.

## 7. Sway-capable AI controller (B3, `res_32_sway`)

All gains and limits in this section are ASSUMED design choices.

- **Teacher** (`teacher_sway_policy.m`). It is the classical law plus a sway-speed command:
  - u_c = sat(k_d (d̂ − d_ref(ĉ)));
  - r_c = sat(−k_e ê);
  - v_c = sat(k_φ φ̂), with k_φ = 0.5 and |v_c| ≤ 0.3 m/s (`P.b3`).

  This is the same sway law and the same limit as the S1 fallback. The BlueROV2 Heavy
  maximum sway speed is 0.63 m/s (von Benzon 2022, Table 4). The law has no gating, only
  actuator saturation.
- **Actor.** A residual MLP (linear skip + 2×32 ReLU) on z7 = [d̂; ê; u; v; r; ĉ; φ̂] with
  outputs [u_c; r_c; v_c].
  - It is trained by imitation with the recipe of `run_phase2_train.m`, using
    `gen_teacher_data_sway.m` and `train_actor.m` with 3 outputs (`run_b3_train.m`).
  - The uniform samples cover φ̂ ∈ ±40° and v ∈ ±0.3 m/s.
- **Closed loop.**
  - The sway command goes through the existing low-level sway loop
    Y = K_v (v_c − v), with K_v = 100 N s/m (`plant_f.m`, row 3 of the command).
  - The CORA model is `aug_dyn_fb.m`, the same model as the S1 fallback. It uses the
    damping-model envelope |u| ≤ 0.3, |v| ≤ 0.35 and |r| ≤ 0.3, which covers |v_c| ≤ 0.3.
  - The reach step is 0.02 s with 6 Taylor terms. `reach_cell` selects this model for
    7-input networks; leaving the envelope makes a cell Inconclusive (`model-range`).
  - In simulation, the bearing estimate φ̂ is passed to the actor (`passPhiHat` /
    `ex.phih`).
