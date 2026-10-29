% RUN_CHAIN_NEXT  Revised queue part 1 (2026-10-05): A2, A1, classical baseline (+ teacher EVV).
diary(fullfile(fileparts(fileparts(mfilename('fullpath'))),'results','logs','chain_next.log'));
t00 = tic;
clearvars -except t00; run_a2_inconclusive; fprintf('[chain] A2 done %.0f s\n', toc(t00));
clearvars -except t00; run_a1_mc_budget; fprintf('[chain] A1 done %.0f s\n', toc(t00));
clearvars -except t00; run_baseline_pat; fprintf('[chain] baseline done %.0f s\n', toc(t00));
clearvars -except t00; actorTag = 'teacher'; ccvModel = '2d'; ccvTag = '2d_loc01_empirical'; ccvLocs = 0.1; ccvWaters = [1 2]; ccvNoReach = true; run_ccv; fprintf('[chain] teacher ccv done %.0f s\n', toc(t00));
diary off
