% RUN_TSWEEP  Verified duration T* for the 13 operating-map cells that are verified at
% T = 20 s and have a nonzero current bound: re-run at T = 30, 40, 60 s (the 80 s pilot
% already lost all of them). Output: results/tsweep/tsweep_res_32.csv with a T_s column.
P = setup_paths(); actorTag = 'res_32';
L = load(fullfile(P.results,'phase2',['actor_' actorTag '.mat']));
T20 = readtable(fullfile(P.results,'opmap',['opmap_' actorTag '.csv']), 'TextType','string');
sel = T20(T20.verdict_maint == "Certified" & T20.w_mps > 0, :);
Ts = [30 40 60];
eo = default_eo(); eo.precheck = true; eo.maxDepth = 1; eo.nMC = 300; eo.ro.tmax = 1800;
cells = {}; meta = [];
for Tn = Ts
    for i = 1:height(sel)
        wi = find(strcmp(P.water.name, sel.water(i)), 1);
        cells{end+1} = make_cell(P, wi, sel.d0_m(i), deg2rad(sel.e0_deg(i)), sel.loc_m(i), sel.w_mps(i), 'T', Tn); %#ok<SAGROW>
        meta(end+1,:) = [Tn, wi, sel.d0_m(i), sel.loc_m(i), sel.w_mps(i)]; %#ok<SAGROW>
    end
end
fprintf('T sweep: %d cells x %d horizons = %d runs\n', height(sel), numel(Ts), numel(cells));
outdir = fullfile(P.results,'tsweep'); if ~exist(outdir,'dir'), mkdir(outdir); end
t0 = tic; [Rs, T] = run_cells(P, L.net, cells, eo, min(10, feature('numcores'))); wall = toc(t0);
T.T_s = meta(:,1);
save(fullfile(outdir, ['tsweep_' actorTag '.mat']), 'Rs', 'T', 'cells', 'eo', 'wall');
writetable(T, fullfile(outdir, ['tsweep_' actorTag '.csv']));
fprintf('wall %.1f s\n', wall); disp(groupcounts(T, {'T_s','verdict_maint'}));
