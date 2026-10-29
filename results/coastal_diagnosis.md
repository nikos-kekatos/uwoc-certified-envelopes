# Coastal teacher vs res_32 difference (planar CCV, loc 0.1 m, |w| <= 0.025 m/s)

Generated 2026-10-05. Analysis only: no reachability was run. Scripts and raw output:
- `code/coastal_join.py` → `coastal_diag/join_clear.csv`, `coastal_diag/join_coastal.csv`,
  `coastal_diag/differing_tiles.csv` (per-tile join of `ccv/ccv_2d_loc01_empirical_teacher.csv`
  and the loc 0.1 m rows of `ccv/ccv_2d_res_32.csv`);
- `code/run_coastal_diag.m` → `coastal_diag/seed_reruns.csv`, `coastal_diag/mc5000.csv`,
  `coastal_diag/witness_cross.csv` (log: `logs/coastal_diag.log`);
- `code/coastal_summary.py` → `coastal_diag/summary.csv`.

## Observation

The empirical decomposition differs in coastal water only (`ccv_summary_2d_loc01_empirical_teacher.csv`,
`ccv_summary_2d_res_32.csv`):

| | Teacher | res_32 |
|---|---|---|
| EVV (m²) | 9.18 | 10.21 |
| EVV falsified, i.e. false assurance (m²) | 1.72 | 2.99 |

In clear water the two decompositions are identical tile by tile (`join_clear.csv`).

## 1-2. Per-tile join and the differing tiles

The tilings are identical (132 coastal tiles; d0 in 0.5 m and φ0 in 10° tiles). Four tiles
differ (`differing_tiles.csv`). All are Rx or power provenance, at |φ0| = 15°:

| d0 (m) | φ0 (°) | area (m²) | Teacher (original run) | res_32 (original run) | First violated predicate |
|---|---|---|---|---|---|
| 1.25 | −15 | 0.109 | 1 MC outage in 200 (min robustness −0.07): MC-outage, not in EVV | 0 MC outages; falsifier witness, robustness −2.93: EVV, Falsified | Rx |
| 2.75 | +15 | 0.240 | 0 MC outages; falsifier best robustness +0.11: EVV, not falsified | 0 MC outages; falsifier witness, robustness −0.04: EVV, Falsified | Rx |
| 5.25 | −15 | 0.458 | 1 MC outage in 200 (−0.07): MC-outage | 0 MC outages; falsifier witness, −0.36: EVV, Falsified | power |
| 5.25 | +15 | 0.458 | 1 MC outage in 200 (−0.15): MC-outage | 0 MC outages; falsifier witness, −0.39: EVV, Falsified | power |

These four tiles account for the whole difference:
- the EVV difference is 0.109 + 0.458 + 0.458 = 1.03 m²;
- the false-assurance difference is 1.03 + 0.24 = 1.27 m².

## 3. Cause

**Sampling variance (confirmed).** The two original runs used different random draws for
the same tile. `run_cells` seeds each tile with 1000 + its index in the run's cell list.
The teacher run listed one water at a time at loc 0.1 m only, while the res_32 run listed
all localisation levels and waters together. With the pool workers' generator (Threefry),
the original seeds reproduce both original rows exactly (`seed_reruns.csv`, rows
`orig_teacher_seed` and `orig_res32_seed`).

Each differing tile was rerun with five seeds:
- the teacher's original seed;
- the res_32 original seed;
- three new seeds.

Each rerun used the same empirical protocol for both controllers: 200 MC runs, then the
8 × 120 cross-entropy falsifier, with no CORA. The results (`summary.csv`):
- **Under a common seed, the teacher and res_32 fall into the same category in 20 of 20
  tile-seed pairs.** Swapping seeds swaps the outcome. The teacher run with the res_32
  seed reproduces the res_32 row, and the reverse also holds.
- Across seeds, each tile changes category for both controllers together.
  - Tile (1.25, −15) is in EVV under 2 of 5 seeds.
  - Tiles (5.25, ±15) are in EVV under 3 of 5 seeds.
  - Tile (2.75, +15) is always in EVV but is Falsified under only 2 of 5 seeds. Its best
    falsifier robustness is −0.046, against a threshold of −0.01.
- With 5,000 MC runs, the two controllers have identical outage counts:
  - 10 / 10 at (1.25, −15);
  - 8 / 8 at (5.25, −15);
  - 10 / 10 at (5.25, +15);
  - 0 / 0 at (2.75, +15).

  At an outage frequency of 0.16-0.2 %, 200 runs see no outage with probability 0.67-0.73.
  The EVV membership of such a tile is therefore close to a coin flip.

**Real behavioural difference (ruled out at these tiles).** All 20 falsifier witnesses
were replayed on the other controller, and all 20 transfer (`witness_cross.csv`). The
robustness on the other controller differs by at most 0.010. Along the witness
trajectories, both laws were evaluated on the same state estimates:
- |Δu_c| ≤ 0.004 m/s;
- |Δr_c| ≤ 9e-5 rad/s;
- the yaw-rate command never saturates.

The network's approximation error is far too small to move these tiles. There is also no
saturation or gating boundary on the witness paths.

**Tiling artefact (ruled out).** Both runs use the same tiles, and the join is one to
one. The differing tiles are ordinary interior tiles at |φ0| = 15°. They are genuinely
marginal: an outage frequency near 0.2 %, or a falsifier robustness within 0.05 of zero.

## Conclusion

The coastal difference between the classical teacher and res_32 is sampling variance,
not a property of the network. Four coastal tiles (1.27 m²) have an outage frequency of
about 0.2 %, or a falsifier robustness within 0.05 of zero. A 200-run Monte Carlo
followed by a heuristic falsifier assigns these tiles to "MC outage", "false assurance"
or "not falsified" depending on the random draw. The two runs happened to use different
draws. Under common seeds, the two controllers receive the same category in 20 of 20
tile-seed pairs. Their 5,000-run outage counts are identical, and every witness of one
controller is a witness of the other, with the commands differing by less than
0.004 m/s. The empirical decomposition of the classical law and of its imitation is
therefore the same within sampling resolution. The coastal EVV and false-assurance
areas carry a seed uncertainty of about ±1 m² at 200 runs per tile. Clear water, with
no marginal tiles, is unaffected.

**Recommended sentence for the papers.** "In coastal water the classical law and its
neural imitation differ by 1.0 m² of empirically viable area and 1.3 m² of
false-assurance area. The difference comes entirely from four marginal tiles, with
outage frequencies near 0.2 % or falsifier robustness within 0.05 of zero, that a
200-run Monte Carlo classifies differently under different random seeds. Under common
seeds, the two controllers receive identical verdicts on these tiles, so the empirical
decomposition is a property of the guidance law and the operating condition, not of
the network."
