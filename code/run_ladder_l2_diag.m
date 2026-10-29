% RUN_LADDER_L2_DIAG  Why the 3-D rung is Inconclusive at vertical level L2: reach
% status of all 29 2-D-certified operating-map cells at level L2 (no refinement).
P = setup_paths(); L = load(fullfile(P.results,'phase2','actor_res_32.mat'));
G = load(fullfile(P.results,'opmap','opmap_res_32.mat'));
sel = find(G.T.verdict_maint == "Certified"); lv = P.ladder.levels(2); n = numel(sel);
st = strings(n,1); tR = nan(n,1); Ml = nan(n,1);
get_pool(10); pctRunOnAll(sprintf('addpath(''%s''); addpath(genpath(''%s''));', P.code, P.cora));
cellsS = G.cells(sel); ro = default_eo().ro;
parfor i = 1:n
    c = cellsS{i}; c3 = c; c3.model = '3d';
    c3.lo = [c.lo; -lv.zhalf; 0; -lv.th0]; c3.hi = [c.hi; lv.zhalf; 0; lv.th0];
    c3.wv = lv.wv; c3.locz = lv.locz; c3.alphaR = lv.alphaR;
    r = reach_cell(P, L.net, c3, ro); st(i) = r.status; tR(i) = r.tReached; Ml(i) = r.Mlow;
end
T = table(G.T.water(sel), G.T.d0_m(sel), G.T.loc_m(sel), G.T.w_mps(sel), st, tR, Ml, ...
    'VariableNames', {'water','d0_m','loc_m','w_mps','reach_status_L2','t_reached_s','Mlow_dB'});
writetable(T, fullfile(P.results,'ladder','ladder_L2_reach_status.csv')); disp(groupcounts(T,'reach_status_L2'))
