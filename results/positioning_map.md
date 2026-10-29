# B2: positioning technology vs the localisation-error axis (writing only, 2026-10-05)

**What the axis means.** The localisation-error axis of the certificates is a HARD bound
on the per-step horizontal position error of the transmitter relative to the receiver.
Published accuracies are usually statistics (standard deviation, CEP), so a bound needs a
coverage factor; we use about 3σ. The bound is relative to the receiver, so errors in the
receiver's own position also count. A full error budget is outside this note.

**Status labels.**
- VERIFIED: the number was read in the source text (PDF text extracted on 2026-10-05).
- UNVERIFIED: seen only in a search snippet or secondary summary.

| Technology | Published accuracy | Source | Status | Implied hard bound in our setting |
|---|---|---|---|---|
| High-frequency (300 kHz) LBL | ±0.007 m XYZ, update 1-10 Hz, range about 100 m ("sub-centimeter precision") | Kinsey, Eustice, Whitcomb, "A survey of underwater vehicle navigation: recent advances and new challenges", IFAC MCMC 2006, Table 1 and §2.3.1 | VERIFIED | ≪ 0.05 m (inside every certified cell) |
| Standard 12 kHz LBL | range-dependent precision 0.1-10 m, ranges 5-10 km, update every ≥ 1-20 s | same, Table 1 and §2.3.1 | VERIFIED | 0.3-30 m (3σ); mostly outside the certified envelope |
| USBL (survey grade, deep-water example) | seabed position σ ≈ 0.97 m N / 0.91 m E, "0.08% of water depth or 0.046° accuracy" (field example) | Kongsberg, HiPAP product description (400578-HiPAP-502.pdf) | VERIFIED (example in the document) | at 100 m slant range: σ ≈ 0.08 m, bound ≈ 0.24 m; at 30 m: bound ≈ 0.07 m |
| USBL, typical spec | 0.15 % of slant range (HiPAP 502, cymbal mode, free line of sight) | Kongsberg (search snippet) | UNVERIFIED | at 100 m: σ ≈ 0.15 m, bound ≈ 0.45 m |
| DVL-aided INS (dead reckoning) | best INS drift 0.1 % of distance travelled; modest units 2-5 % | Paull, Saeedi, Seto, Li, "AUV Navigation and Localization: A Review", IEEE JOE 39(1):131-149, 2014, doi:10.1109/JOE.2013.2278891, §III | VERIFIED | over 20 s at up to 0.2 m/s (≤ 4 m travelled) the drift is 0.004 m (best) or 0.08-0.2 m (modest), added to the error of the last absolute fix |
| DVL velocity (bottom lock) | precision 0.3 % or less | Kinsey et al. 2006, Table 1 | VERIFIED | velocity, not position (enters ε_u, ε_v) |
| Optical-beacon visual ranging (short range) | average relative distance error 1.04 % over 2-10 m (0.83 % below 7 m), pool/tank tests | Zhang, Zhong, Yang, Zhou, Shen, Sensors 22(20):7940, 2022, doi:10.3390/s22207940 | VERIFIED (open-access text) | range error ≈ 0.04-0.10 m at 4-10 m (range only; the bearing error must be added) |
| Optical docking light arrays | centimetre-level accuracy reported, e.g. 1.6-2.4 cm (light plus ArUco fusion); ≤ 20 cm (L-shaped array) | survey snippets on recent docking papers (MDPI Drones/Sensors 2024-2025) | UNVERIFIED | 0.02-0.2 m |

**Reading against the certificates.**
- Certified planar start area (clear water, |w| ≤ 0.025 m/s) is 19.5 m² at a 0.05 m
  bound, 16.1 m² at 0.1 m, and 0 at 0.3 m (Sec. 5 of RESULTS.md).
- A3 (localisation cliff at 0.15 / 0.2 / 0.25 m, box vs disk model) will place the cliff
  more precisely: certificates exist up to 0.25 m (clear) and 0.15 m (coastal); the decline is steady, not a cliff (RESULTS.md §12e).
- Provisional reading:
  - High-frequency LBL and short-range optical ranging (with a comparable bearing
    accuracy) fall inside the certified envelope.
  - DVL-aided INS between absolute fixes stays inside only with a good INS (0.1 % drift)
    and frequent fixes.
  - USBL qualifies only at short slant range (tens of metres).
  - Standard 12 kHz LBL does not qualify for any certificate in this model.
