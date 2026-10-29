% RUN_T80_PILOT  Longer-horizon pilot (2026-10-18): re-run reachability + MC +
% falsification with T = 80 s on the operating-map cells that are verified at
% T = 20 s (verdict_maint == Certified in results/opmap/opmap_res_32.csv).
% Purpose: answer "is 20 s too short" with data. Output: results/t80_pilot/.
P = setup_paths();
if ~exist('actorTag','var'), actorTag = 'res_32'; end
if ~exist('Tnew','var'), Tnew = 80; end
L = load(fullfile(P.results,'phase2',['actor_' actorTag '.mat']));
T20 = readtable(fullfile(P.results,'opmap',['opmap_' actorTag '.csv']), 'TextType','string');
sel = T20(T20.verdict_maint == "Certified", :);
fprintf('T=%g pilot on %d cells verified at T=20\n', Tnew, height(sel));
eo = default_eo(); eo.precheck = true; eo.maxDepth = 1; eo.nMC = 300;
eo.ro.tmax = 3600;                      % allow longer reachability per cell (20 s runs used 900)
cells = {}; meta = [];
for i = 1:height(sel)
    wi = find(strcmp(P.water.name, sel.water(i)), 1);
    cells{end+1} = make_cell(P, wi, sel.d0_m(i), deg2rad(sel.e0_deg(i)), sel.loc_m(i), sel.w_mps(i), 'T', Tnew); %#ok<SAGROW>
    meta(end+1,:) = [wi, sel.d0_m(i), sel.loc_m(i), sel.w_mps(i)]; %#ok<SAGROW>
end
outdir = fullfile(P.results,'t80_pilot'); if ~exist(outdir,'dir'), mkdir(outdir); end
t0 = tic;
[Rs, T] = run_cells(P, L.net, cells, eo, min(10, feature('numcores')));
wall = toc(t0);
T.T_s = repmat(Tnew, height(T), 1);
save(fullfile(outdir, sprintf('t%d_%s.mat', Tnew, actorTag)), 'Rs', 'T', 'cells', 'eo', 'wall');
writetable(T, fullfile(outdir, sprintf('t%d_%s.csv', Tnew, actorTag)));
fprintf('wall %.1f s\n', wall); disp(groupcounts(T, {'water','verdict_maint'}));
