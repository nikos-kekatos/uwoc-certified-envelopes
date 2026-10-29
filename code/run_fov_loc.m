% RUN_FOV_LOC  Campaign A: Rx FOV x localisation trade-off (planar CCV, res_32, clear +
% coastal, |w| <= 0.025 m/s, full planar tiling of Sec. 5 / 12e).
% FOV variants via link_variant (as in B1: concentrator gain, background-limited P_min
% and K are recomputed; the Rx-FOV predicate uses the new half-angle).
% New runs: FOV 45 and 20 deg at loc {0.05 0.1 0.15 0.2 0.25 0.3} m.
% The 30 deg (baseline) points are reused from ccv_summary_2d_res_32.csv (0.05/0.1/0.3)
% and ccv_summary_a3_box_res_32.csv (0.15/0.2/0.25); they are not recomputed.
% Raw output: results/ccv/ccv_fov{45,20}_res_32.csv|mat and ccv_summary_fov*_res_32.csv.
% Summary + figure: fov_loc_summary.m -> results/fov_loc/, figures/fig_fov_loc.pdf
diary(fullfile(fileparts(fileparts(mfilename('fullpath'))),'results','logs','fov_loc.log'));
t00 = tic;
for fov = [45 20]
    clearvars -except t00 fov
    Pover = @(P) link_variant(P, 'FOV', fov);
    actorTag = 'res_32'; ccvModel = '2d'; ccvTag = sprintf('fov%d', fov);
    ccvLocs = [0.05 0.1 0.15 0.2 0.25 0.3]; ccvWaters = [1 2];
    run_ccv;
    fprintf('[fov_loc] FOV %d done %.0f s\n', fov, toc(t00));
end
fov_loc_summary;
diary off
