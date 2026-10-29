# Data not included in the repository

All raw outputs needed to check the reported numbers are in `results/`. The files below
were left out because of their size or because they are not needed for reproduction.

| File | Size | Why not included | How to obtain |
|---|---|---|---|
| `results/phase2/teacher_data.mat` | 20.1 MB | imitation-learning dataset of the classical teacher; only an input to actor training | regenerated automatically by `code/run_phase2_train.m` when absent (`gen_teacher_data(P, 150000, 60, 11)`, fixed seed); available on request |
| `results/b3/teacher_sway_data.mat` | 25.4 MB | dataset of the sway-capable teacher (B3, RESULTS.md §12l) | regenerated automatically by `code/run_b3_train.m` when absent (`gen_teacher_data_sway(P, 150000, 60, 11)`); available on request |
| `results/logs/*.log` | 5.9 MB | MATLAB console transcripts of the reference run; they contain machine-specific paths | written again to `results/logs/` on a rerun |
| provisional (v0) results and scripts | — | superseded by the calibrated model v1; not used by any reported number | not distributed |

The trained actors produced from these datasets are included (`models/` and
`results/phase2/`), so no result other than re-training depends on the missing files.
Re-training regenerates the datasets with the same seeds; bit-identical weights are not
guaranteed across MATLAB versions and hardware.

Requests: contact the first author (see `CITATION.cff`).
