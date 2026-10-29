% RUN_A1_MC_BUDGET  Monte Carlo budget: the 27 hero-map cells that are Falsified but
% showed 0 outages in 500 runs, and 10 Certified cells (sanity: must stay at 0), at
% 5,000 Monte Carlo runs, and 50,000 only for falsified cells still at 0 after 5,000
% (same sampling model as mc_scen; independent seeds).
P = setup_paths(); L = load(fullfile(P.results,'phase2','actor_res_32.mat')); net = L.net;
M = load(fullfile(P.results,'opmap','opmap_res_32.mat'));
f27 = find(M.T.mc_outage_rate == 0 & M.T.verdict_maint == "Falsified");
cc = find(M.T.verdict_maint == "Certified"); c10 = cc(round(linspace(1, numel(cc), 10)));
sel = [f27; c10]; grp = [repmat("falsified_mc0", numel(f27), 1); repmat("certified", numel(c10), 1)];
budgets = [5000 50000]; chunk = 5000; n = numel(sel); cellsS = M.cells(sel);
cnt = zeros(n, 2); prov = zeros(n, 2);
get_pool(10); pctRunOnAll(sprintf('addpath(''%s'');', P.code));
t0 = tic;
parfor i = 1:n
    c = cellsS{i}; k = zeros(1,2); pv = zeros(1,2);
    for b = 1:2
        if b == 2 && (k(1) > 0 || grp(i) == "certified"), k(2) = NaN; continue; end   % 50k only where 5k found nothing
        rng(70000 + 100*i + b); tot = 0; firstp = 0;
        for q = 1:budgets(b)/chunk
            o = sim_closed_loop(P, mc_scen(P, c, chunk), @(z,kk,x) deal(nn_forward(net,z), false(1,size(z,2))), struct('T', c.T));
            v = o.rho < -0.01; tot = tot + sum(v);
            if firstp == 0 && any(v), firstp = mode(o.firstProv(v)); end
        end
        k(b) = tot; pv(b) = firstp;
    end
    cnt(i,:) = k; prov(i,:) = pv;
end
wall = toc(t0);
T = M.T(sel, {'water','d0_m','loc_m','w_mps','verdict_maint','provenance'}); T.group = grp;
T.outages_5k = cnt(:,1); T.rate_5k = cnt(:,1)/5000; T.outages_50k = cnt(:,2); T.rate_50k = cnt(:,2)/50000;
T.prov_5k = prov(:,1); T.prov_50k = prov(:,2);
outdir = fullfile(P.results,'a1'); if ~exist(outdir,'dir'), mkdir(outdir); end
writetable(T, fullfile(outdir,'a1_mc_budget.csv'));
fprintf('A1 wall %.0f s\n', wall);
fprintf('falsified cells still missed: 5k %d/27, 50k %d/27; certified with outages: 5k %d, 50k %d\n', ...
    sum(T.outages_5k(grp=="falsified_mc0")==0), sum(T.outages_50k(grp=="falsified_mc0")==0 & T.outages_5k(grp=="falsified_mc0")==0), ...
    sum(T.outages_5k(grp=="certified")>0), sum(T.outages_50k(grp=="certified")>0));
