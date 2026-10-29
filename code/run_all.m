% RUN_ALL  Reproduce the main calibrated (v1) results in results/ (see ../README.md).
% Run from the repository root:  matlab -batch "addpath('code'); run_all"
% (about 4 h on 10 workers), then, also from the repository root:
%   python code/analyze_v1.py && python code/make_figures.py
%   python code/export_onnx.py res_32   (after export_actor_json)
diary(fullfile(fileparts(fileparts(mfilename('fullpath'))),'results','logs','run_all.log'));
t00 = tic;
clearvars -except t00; run_phase2_train;                                   % actors + imitation + closed-loop MC
clearvars -except t00; actorTag = 'res_32'; run_operating_map;             % hero map (2-D, 294 cells)
clearvars -except t00; actorTag = 'res_32'; run_phase1_ace;                % link budget, ACE regions, tubes
clearvars -except t00; actorTag = 'res_32'; ccvModel = '2d'; ccvTag = '2d'; run_ccv;          % 2-D CCV vs loc
clearvars -except t00; actorTag = 'res_32'; ccvModel = '3d'; ccvTag = '3d'; ccvLocs = 0.1; run_ccv;   % 3-D CCV
clearvars -except t00; actorTag = 'res_32'; ladderLoc = 0.1; run_ladder_ccv;  % 2D/3D vs 6-DOF on the CCV tiling
clearvars -except t00; run_consistency_check;                              % rung consistency (3-D vs 6-DOF)
clearvars -except t00; actorTag = 'res_32'; run_ladder;                    % vertical-uncertainty levels
clearvars -except t00; actorTag = 'res_32'; nTraj = 40; run_phase6_shield; % shield (secondary)
clearvars -except t00; actorTag = 'res_32'; export_actor_json;
fprintf('run_all done in %.0f s\n', toc(t00));
diary off
