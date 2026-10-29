% RUN_MC_PHYSICAL  Dual outage metric (review, 2026-10-18): for every operating-map cell,
% 500 Monte Carlo runs (same seeds as the map) recording, per run, which ACE predicates are
% violated anywhere in [0,T]: envelope outage (any predicate), physical outage (Rx FOV or
% power), power-only. Output: results/mc_physical/mc_physical_res_32.csv
P = setup_paths(); L = load(fullfile(P.results,'phase2','actor_res_32.mat')); ctrl = make_ctrl(L.net);
M = load(fullfile(P.results,'opmap','opmap_res_32.mat')); n = numel(M.cells);
eo = default_eo();
out = nan(n, 7);
get_pool(min(10, feature('numcores')));
parfor i = 1:n
    c = M.cells{i}; rng(1000 + i);
    o = sim_closed_loop(P, mc_scen(P, c, eo.nMC), ctrl, struct('T', c.T, 'Te', c.Te));
    anyv = o.rho < -eo.tol;                        % envelope outage (robustness < -tol)
    phys = (o.violRx | o.violP);                   % physical criteria within [0,T]
    out(i,:) = [mean(anyv), mean(phys), mean(o.violP), mean(o.violRx), mean(o.violTx), mean(anyv & ~phys), min(o.Mmin)];
end
T = M.T(:, {'water','d0_m','loc_m','w_mps','verdict_maint','provenance','mc_outage_rate'});
T.mc_env_outage = out(:,1); T.mc_phys_outage = out(:,2); T.mc_power = out(:,3); T.mc_rx = out(:,4); T.mc_tx = out(:,5);
T.mc_env_only = out(:,6); T.mc_min_margin_dB = out(:,7);
outdir = fullfile(P.results,'mc_physical'); if ~exist(outdir,'dir'), mkdir(outdir); end
writetable(T, fullfile(outdir,'mc_physical_res_32.csv'));
fprintf('cells with envelope outage: %d, with physical outage: %d, envelope-only: %d\n', sum(T.mc_env_outage>0), sum(T.mc_phys_outage>0), sum(T.mc_env_outage>0 & T.mc_phys_outage==0));
