% RUN_BASELINE_PAT  Classical PAT baseline: the teacher LOS/communication-aware law
% (exact PWL network, teacher_net) vs the residual actor res_32 on 24 hero-map cells
% (3 waters x near/far x localisation {0.05, 0.3} m x current {0, 0.1} m/s), same bounds
% and scenarios. The teacher is an EMPIRICAL comparator only ("empirically viable
% classical controller"): Monte Carlo + targeted falsification, no CORA. res_32 keeps its
% formal verdict (CORA + MC + falsifier). Sampled outage, control effort and mean
% |pointing error| from 500 Monte Carlo runs (same seeds for both).
P = setup_paths(); L = load(fullfile(P.results,'phase2','actor_res_32.mat'));
M = load(fullfile(P.results,'opmap','opmap_res_32.mat'));
sel = find(ismember(M.T.loc_m, [0.05 0.3]) & ismember(M.T.w_mps, [0 0.1]));
n = numel(sel); cellsS = M.cells(sel); eo = default_eo(); eo.precheck = true; eo.maxDepth = 1;
names = {'teacher','res_32'}; out = cell(n, 2);
get_pool(10); pctRunOnAll(sprintf('addpath(''%s''); addpath(genpath(''%s''));', P.code, P.cora));
c0 = cellsS{1}; c0.T = P.dt_ctrl; reach_cell(P, L.net, c0, eo.ro);
parfor i = 1:n
    c = cellsS{i}; r = cell(1,2);
    for a = 1:2
        if a == 1, net = teacher_net(P, c.wi); else, net = L.net; end
        eoi = eo; eoi.seed = 1000 + sel(i); if a == 1, eoi.noReach = true; end
        R = eval_cell(P, net, c, eoi);
        rng(90000 + i);
        o = sim_closed_loop(P, mc_scen(P, c, 500), @(z,k,x) deal(nn_forward(net,z), false(1,size(z,2))), struct('keep', true));
        mE = mean(mean(abs(squeeze(o.X(3,:,:))), 2));
        r{a} = {R.verdict, R.prov, R.reach.Mlow, mean(o.outage), mean(o.effort), rad2deg(mE), mean(o.tRobust)/P.T};
    end
    out(i,:) = r;
end
T = M.T(sel, {'water','d0_m','loc_m','w_mps'}); T.range_class = M.T.range_class(sel);
for a = 1:2
    v = vertcat(out{:,a});
    T.([names{a} '_verdict']) = string(v(:,1)); T.([names{a} '_prov']) = string(v(:,2));
    T.([names{a} '_Mlow_dB']) = cell2mat(v(:,3)); T.([names{a} '_mc_outage']) = cell2mat(v(:,4));
    T.([names{a} '_effort']) = cell2mat(v(:,5)); T.([names{a} '_mean_abs_e_deg']) = cell2mat(v(:,6));
    T.([names{a} '_robust_frac']) = cell2mat(v(:,7));
end
outdir = fullfile(P.results,'baseline'); if ~exist(outdir,'dir'), mkdir(outdir); end
writetable(T, fullfile(outdir,'baseline_pat.csv')); disp(T(:, {'water','d0_m','loc_m','w_mps','teacher_verdict','res_32_verdict'}));
