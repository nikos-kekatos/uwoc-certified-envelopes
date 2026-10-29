% RUN_TEACHER_REACH  Reachability of the classical teacher law (exact PWL net,
% teacher_net) on the 24 baseline comparison cells with the CURRENT model,
% cell definitions and CORA settings. Output: results/teacher_reach/.
P = setup_paths();
M = load(fullfile(P.results,'opmap','opmap_res_32.mat'));
sel = find(ismember(M.T.loc_m, [0.05 0.3]) & ismember(M.T.w_mps, [0 0.1]));   % same 24 cells as run_baseline_pat
cells = M.cells(sel); n = numel(cells);
eo = default_eo(); eo.precheck = true; eo.maxDepth = 1; eo.nMC = 200;    % reach ON (noReach not set)
eo.ro.tmax = 1800;
fprintf('teacher reachability on %d cells\n', n);
outdir = fullfile(P.results,'teacher_reach'); if ~exist(outdir,'dir'), mkdir(outdir); end
wiC = cellfun(@(c) c.wi, cells); Ts = {}; Rs = {};
t0 = tic;
for wi = unique(wiC)
    m = find(wiC == wi);
    [Rw, Tw] = run_cells(P, teacher_net(P, wi), cells(m), eo, min(10, feature('numcores')));
    Tw.sel = sel(m); Ts{end+1} = Tw; Rs = [Rs; Rw]; %#ok<AGROW>
end
T = vertcat(Ts{:}); wall = toc(t0);
B = readtable(fullfile(P.results,'baseline','baseline_pat.csv'), 'TextType','string');
T.res32_verdict = strings(height(T),1);
for i = 1:height(T)
    k = B.water == T.water(i) & abs(B.d0_m - T.d0_m(i))<1e-9 & abs(B.loc_m - T.loc_m(i))<1e-9 & abs(B.w_mps - T.w_mps(i))<1e-9;
    if any(k), T.res32_verdict(i) = B.res_32_verdict(find(k,1)); end
end
save(fullfile(outdir,'teacher_reach.mat'), 'Rs', 'T', 'cells', 'eo', 'wall');
writetable(T, fullfile(outdir,'teacher_reach.csv'));
fprintf('wall %.1f s\n', wall); disp(groupcounts(T, {'verdict_maint','res32_verdict'}));
