# Code

MATLAB pipeline (CORA reachability, falsification, Monte Carlo, runtime shield) and
Python summaries/figures. Run everything from the repository root; see `../README.md`
for requirements, the script-to-result map and runtimes. Outputs go to `../results/`,
figures to `../figures/`, the exported actor to `../models/`. Every constant and its
source is listed in `MODEL.md`.

## Main files
| File | Role |
|---|---|
| `uwoc_params.m`, `MODEL.md` | calibrated constants (water, transceiver, P_min from BER, BlueROV2, low-level loop), with sources |
| `margin_db.m`, `link_margin.m`, `ace_eval.m`, `ace_box3.m` | channel formula; separate Tx/Rx/power predicates (simulation; sound box check in 3-D) |
| `plant_f.m`, `plant_f3.m`, `sim6dof_closed_loop.m`, `vehicle6dof.m` | TRUE plants: planar 3-DOF, 3-D reduced, 6-DOF Fossen (BlueROV2) |
| `aug_dyn.m`, `aug_dyn3.m`, `qdamp_model.m` | CORA models (ZOH commands, low-level loop, polynomial damping with bounded error) |
| `teacher_policy.m`, `fallback_net.m`, `gen_teacher_data.m`, `train_actor.m`, `run_phase2_train.m` | teacher, fallback, imitation training (MLP and residual MLP; 16-256 units) |
| `nn_forward.m`, `ctrl_sets.m`, `nn_set_eval.m` | numeric and set-based actor evaluation |
| `reach_cell.m`, `reach_refine.m` | closed-loop CORA reachability (2-D or 3-D), noise as fresh factors, model-envelope assertion |
| `sim_closed_loop.m`, `mc_scen.m`, `make_scen.m`, `falsify_cell.m`, `falsify6_cell.m` | Monte Carlo and cross-entropy falsifiers (2-D, 3-D, 6-DOF) |
| `eval_cell.m`, `run_cells.m`, `make_cell.m`, `default_eo.m`, `get_pool.m` | three-verdict evaluation per cell, in parallel |
| `run_operating_map.m` | hero map: water x localisation x current |
| `run_phase1_ace.m` | link budget, ACE regions, reachable tubes |
| `run_ccv.m` | certified communication volume (2-D or 3-D) vs empirical viable volume |
| `run_ladder_ccv.m`, `run_ladder.m` | 2D -> 3D -> 6-DOF false assurance, Wilson intervals, mechanisms |
| `shield_check.m`, `run_phase6_shield.m` | runtime shield under OOD current (secondary) |
| `export_actor_json.m`, `export_onnx.py` | ONNX export and numerical check |
| `analyze_v1.py`, `make_figures.py` | summaries (`results/summary_v1.json`) and PDF figures |

