% RUN_T80_FINAL3  (2026-10-18) Complete the T = 80 s envelope over all 32 final
% verified cells: re-run reachability + MC + falsification at T = 80 s on the 3
% cells that were verified only in the A2 second pass (results/a2/a2_inconclusive.csv,
% pass2_certified == 1). run_t80_pilot.m covered the other 29 (verified in the first
% pass). Settings follow A2 pass 2 (run_a2_inconclusive.m), NOT the first-pass /
% pilot settings: zonotope order 200 (pilot: 100) and splitting depth 2 (pilot: 1),
% so a loss of proof at 80 s is not an artifact of the coarser representation.
% Everything else as the pilot: precheck, nMC = 300, ro.tmax = 3600 per leaf,
% timeStep 0.05, taylorTerms 8, polyMethod singh, Te = 10. Output: results/t80_final3/.
P = setup_paths();
if ~exist('actorTag','var'), actorTag = 'res_32'; end
if ~exist('Tnew','var'), Tnew = 80; end
outdir = fullfile(P.results,'t80_final3'); if ~exist(outdir,'dir'), mkdir(outdir); end
diary(fullfile(outdir, sprintf('t%d_final3_run.log', Tnew))); diary on;
fprintf('run_t80_final3 started %s\n', char(datetime('now')));
L = load(fullfile(P.results,'phase2',['actor_' actorTag '.mat']));
A2 = readtable(fullfile(P.results,'a2','a2_inconclusive.csv'), 'TextType','string');
OM = readtable(fullfile(P.results,'opmap',['opmap_' actorTag '.csv']), 'TextType','string');
sel = A2(A2.pass2_certified == 1, :);
fprintf('T=%g final-3 on %d cells verified in A2 pass 2\n', Tnew, height(sel));
eo = default_eo(); eo.precheck = true; eo.maxDepth = 2; eo.nMC = 300;
eo.ro.tmax = 3600;                      % per-leaf reachability budget (pilot used the same)
eo.ro.zonotopeOrder = 200;              % A2 pass-2 representation (default_eo / pilot: 100)
fprintf('settings: maxDepth=%d zonotopeOrder=%d timeStep=%g taylorTerms=%d polyMethod=%s tmax=%g nMC=%d precheck=%d\n', ...
    eo.maxDepth, eo.ro.zonotopeOrder, eo.ro.timeStep, eo.ro.taylorTerms, eo.ro.polyMethod, eo.ro.tmax, eo.nMC, eo.precheck);
cells = {}; meta = [];
for i = 1:height(sel)
    wi = find(strcmp(P.water.name, sel.water(i)), 1);
    j = find(OM.water == sel.water(i) & abs(OM.d0_m - sel.d0_m(i)) < 1e-9 & ...
             abs(OM.loc_m - sel.loc_m(i)) < 1e-9 & abs(OM.w_mps - sel.w_mps(i)) < 1e-9, 1);
    assert(~isempty(j), 'cell %d not found in opmap table', i);
    e0 = OM.e0_deg(j);
    fprintf('  cell %d: %s d0=%g loc=%g w=%g e0=%g deg (opmap T20: %s; a2 pass2: %s)\n', i, sel.water(i), ...
        sel.d0_m(i), sel.loc_m(i), sel.w_mps(i), e0, OM.verdict_maint(j), sel.pass2_status(i));
    cells{end+1} = make_cell(P, wi, sel.d0_m(i), deg2rad(e0), sel.loc_m(i), sel.w_mps(i), 'T', Tnew); %#ok<SAGROW>
    meta(end+1,:) = [wi, sel.d0_m(i), sel.loc_m(i), sel.w_mps(i), e0]; %#ok<SAGROW>
end
t0 = tic;
[Rs, T] = run_cells(P, L.net, cells, eo, min([numel(cells), 10, feature('numcores')]));
wall = toc(t0);
T.T_s = repmat(Tnew, height(T), 1);
T.settings = repmat(sprintf('a2pass2:order%d,depth%d,tmax%g', eo.ro.zonotopeOrder, eo.maxDepth, eo.ro.tmax), height(T), 1);
save(fullfile(outdir, sprintf('t%d_final3_%s.mat', Tnew, actorTag)), 'Rs', 'T', 'cells', 'eo', 'wall', 'meta');
writetable(T, fullfile(outdir, sprintf('t%d_final3_%s.csv', Tnew, actorTag)));
fprintf('\nwall %.1f s\n', wall);
fprintf('%-8s %-5s %-5s %-6s | %-13s %-9s %-9s %-8s %-7s %-7s %-7s %-5s %-6s %s\n', 'water','d0','loc','w', ...
    'verdict_maint','Mlow_dB','tFirst_s','mcOut','mcMin','falsF','falsRho','nLeaf','prov','reach_status');
for i = 1:height(T)
    fprintf('%-8s %-5g %-5g %-6g | %-13s %-9.3f %-9.3g %-8.4f %-7.3f %-7d %-7.3f %-5d %-6s %s\n', T.water(i), T.d0_m(i), T.loc_m(i), T.w_mps(i), ...
        T.verdict_maint(i), T.reach_Mlow_dB(i), T.reach_tFirstViol_s(i), T.mc_outage_rate(i), T.mc_min_rho(i), ...
        T.fals_found(i), T.fals_min_rho(i), T.reach_leaves(i), T.provenance(i), T.reach_status(i));
    R = Rs{i};
    if isfield(R,'reach')
        fprintf('    MC first-violation counts Tx/Rx/P = %d/%d/%d; reach possTx/Rx/P = %d/%d/%d; reach provFirst = %s; leaf statuses = %s; reach time %.0f s\n', ...
            R.mc_prov_Tx, R.mc_prov_Rx, R.mc_prov_P, R.reach.possTx, R.reach.possRx, R.reach.possP, ...
            string(R.reach.provFirst), strjoin(string(R.reach.statuses), ','), R.reach.runtime);
    else
        fprintf('    error: %s\n', R.error);
    end
end
disp(groupcounts(T, {'water','verdict_maint'}));
fprintf('run_t80_final3 finished %s\n', char(datetime('now')));
diary off;
