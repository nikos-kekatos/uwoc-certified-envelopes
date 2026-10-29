# Chained short-window certification: method and soundness argument

Written 2026-10-05, before the campaign. Code: `code/chain_cell.m`, `code/run_chain_certify.m`.

## 1. The system seen at sampling instants

The planar closed loop of `reach_cell.m` (rung 1, actor res_32) has, at every control instant
t_k = 0.5 k s, the full state x = [d, φ, e, u, v, r]. There is no other memory:
- The actor is a memoryless map of the estimate z = [d̂, ê, û, v̂, r̂, ĉ] (ĉ = nominal c, constant).
- The commands (u_c, r_c) are recomputed at t_k and held over [t_k, t_k + 0.5). They are
  states of the CORA model only inside a period and are overwritten at the next sample.
- The inner velocity loop acts on the plant states u, v, r, which are part of x.
- The damping-surrogate error is a bounded input (box, any time variation), not a state.

The uncertainty is declared by constant boxes: current (w_r, w_t) ∈ [−w, w]², arbitrary in
time; damping-surrogate error in a fixed box, arbitrary in time; measurement noise inside a
box that depends only on the current set (via d_lo), fresh at every sample; true extinction
c ∈ c_nom(1 ± 0.1), a constant that enters only the ACE power predicate (checked with the
worst case χ = c_nom·1.1). The dynamics (`aug_dyn.m`) do not depend on t.

Hence the set-valued one-period map F (all states reachable at t_{k+1} from a state at t_k
under all admissible inputs and noise) does not depend on k. The same holds for the tube map
Tube(A) over one period. The restriction of any admissible trajectory to a window
[t_j, t_j + H], with H a multiple of 0.5 s and t_j a sampling instant, is an admissible
trajectory of the same system started at x(t_j). This is the time-shift property used below.

## 2. Window certificate

For a start set A (box or parallelotope) and window length H ∈ {4, 5} s (8 or 10 periods),
`chain_cell` runs the same CORA closed-loop reach as `reach_cell` (same model, inputs, noise
injection, time step 0.05 s, 8 Taylor terms, zonotope order 100, 'singh' NN enclosures) from A
over [0, H]. The window is **OK** iff
1. every time-interval set satisfies ACE_Tx, ACE_Rx and ACE_Power (M ≥ 0 at χ), with the
   same interval checks as `reach_cell`;
2. every time-interval set stays inside the damping-surrogate envelope |u| ≤ 0.3, |v| ≤ 0.15,
   |r| ≤ 0.3 (otherwise the status is `model-range` and the cell stays Inconclusive);
3. no CORA set explosion, split, d_lo ≤ 0.2 m or timeout occurs.
It returns an outer enclosure E of the reachable set at t = H.

## 3. Chain and closure

Let A_0 = X0 (the cell's initial box). For k = 0, 1, …: run the window from A_k and get E_k;
set A_{k+1} = simp(E_k) inflated by a relative margin m, where simp is either the interval
hull (box) or the order-1 PCA reduction of zonotope(E_k) (parallelotope). E_k ⊆ A_{k+1} holds
by construction (both operations are outer enclosures); it is re-checked numerically.

**Claim 1 (20 s certificate).** If windows 0 … N−1 are OK with N·H ≥ 20 s, the cell is
Certified on [0, 20 s]. Proof by induction on k: the true states at t = kH lie in A_k
(k = 0: definition; step: by the time-shift property they are reachable within H from A_k,
hence lie in E_k ⊆ A_{k+1}). The true trajectory on [kH, (k+1)H] is a trajectory from A_k,
hence inside the window-k tube, which satisfies all ACE predicates.

**Claim 2 (unbounded certificate).** If moreover E_k ⊆ A_j for some j ≤ k (closure), the cell
is Certified for every horizon: the true states at t = (k+1)H lie in A_j, and from A_j the
windows j … k were already shown OK, so the argument repeats with period k − j + 1 windows.
The case j = k is the inductive invariant S = A_k: Tube_H(S) ⊆ ACE and E(S) ⊆ S.

Containment tests are sufficient conditions only:
- box A: interval(E_k) ⊆ A;
- parallelotope A = {c + G a : ‖a‖∞ ≤ 1}, G invertible: interval(G⁻¹(E_k − c)) ⊆ [−1, 1]⁶.
  The interval enclosure of the linearly transformed polynomial zonotope is an outer bound,
  so a positive answer is sound.

## 4. What is and is not claimed

- Same conditions as every other certificate: model in MODEL.md and the declared bounds.
- The windows are aligned with the 0.5 s sampling grid (H multiple of 0.5, start at a sample).
- Exogenous bounds must be time-invariant boxes. A time-varying bound (e.g. a schedule of
  currents) would break the time-shift property and is not covered.
- The noise bound on ê depends on the d_lo of the current set; it is recomputed at every
  sample from the set actually carried, as in `reach_cell`.
- A window that fails (ACE touched, explosion, model-range) leaves the cell Inconclusive. No
  verdict of Falsified comes from chaining. Reasons reported: `ace`, `explosion` (incl. CORA
  error/split/d_lo ≤ 0.2 m), `model-range`, `timeout`. For the 20 s chain, containment holds by
  construction (A_{k+1} is an outer enclosure of E_k); a failed numerical re-check would be
  reported as `containment` and would indicate a bug. Containment matters only for closure.
- Margin: m = 0.02 (2 % of each half-width). It is not needed for the 20 s chain and is kept
  small so that closure of the non-bearing part can be detected.

## 5. Why full closure (Claim 2) cannot succeed for this model

The bearing φ appears in no right-hand side of `aug_dyn.m`, not in the actor input, and not in
the noise bounds. It is a neutral integrator: over a window, φ(H) = φ(0) + Δ, where Δ depends
only on the trajectory of [d, e, u, v, r] and on the inputs. For a box start set A, every
start state shares the same φ fiber, so the φ interval of E contains the φ interval of A
shifted by every attainable Δ. E ⊆ A in φ would need all attainable increments to be the single
value 0, which fails as soon as the noise or the current moves the vehicle tangentially. The
same holds for a parallelotope whenever Δ is not a single point for a fixed [d, e, u, v, r]
start. So an inductive invariant over windows in the full state does not exist, and the
achievable result is the explicit chain of Claim 1 (a 20 s certificate). The campaign still
runs the closure test (expected 0 successes) and records closure of [d, e, u, v, r] alone
(column `close5_win`) as a diagnostic, not as a certificate.
- Soundness check: every chain-certified cell is attacked by the cross-entropy falsifier
  (`falsify_cell`) at T = 20 s, and the unbounded ones also at T = 60 s. Any witness is a bug.
