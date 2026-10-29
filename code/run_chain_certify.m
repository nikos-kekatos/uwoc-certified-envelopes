% RUN_CHAIN_CERTIFY  Chained short-window certification (results/chain/METHOD.md) of
% the 70 hero-map cells still Inconclusive after A2, plus the 32 Certified cells as a
% consistency check. Configurations: H in {4,5} s x re-start set in {box, par}.
% Chain-certified cells are then attacked by the strong falsifier (any witness = bug).
% Optional workspace variables: chainWorkers (default 10), chainSubset (indices into
% the 102-cell list, for testing), chainTag (output suffix).
if ~exist('chainWorkers','var'), chainWorkers = 10; end
if ~exist('chainTag','var'), chainTag = ''; end
P = setup_paths(); L = load(fullfile(P.results,'phase2','actor_res_32.mat')); net = L.net;
M = load(fullfile(P.results,'opmap','opmap_res_32.mat'));
A2 = load(fullfile(P.results,'a2','a2_inconclusive.mat'));
sel = find(M.T.verdict_maint == "Inconclusive");
inc = sel(A2.T.final_T20 == "Inconclusive");                       % 70
cer = [find(M.T.verdict_maint == "Certified"); sel(A2.T.final_T20 == "Certified(pass2)")];   % 29 + 3
grp = [repmat("inconclusive70", numel(inc), 1); repmat("certified32", numel(cer), 1)];
idx = [inc; cer];
if exist('chainSubset','var'), idx = idx(chainSubset); grp = grp(chainSubset); end
nCell = numel(idx);
Hs = [4 5]; sets = {'box','par'};
[gc, gh, gs] = ndgrid(1:nCell, 1:numel(Hs), 1:numel(sets)); nJ = numel(gc);
ro = default_eo().ro; ro.tmax = 1200;
outdir = fullfile(P.results,'chain'); if ~exist(outdir,'dir'), mkdir(outdir); end
get_pool(chainWorkers); pctRunOnAll(sprintf('addpath(''%s''); addpath(genpath(''%s''));', P.code, P.cora));
c0 = M.cells{idx(1)}; c0.T = P.dt_ctrl; reach_cell(P, net, c0, ro);   % warm-up (cached derivatives)
cellsJ = M.cells(idx(gc(:)));
st = strings(nJ,1); rs = strings(nJ,1); pv = strings(nJ,1);
c20 = false(nJ,1); cInf = false(nJ,1); nWin = zeros(nJ,1); tF = nan(nJ,1); Ml = nan(nJ,1);
rt = zeros(nJ,1); c5 = nan(nJ,1); phW = nan(nJ,1); wMax = nan(nJ,1);
t0 = tic;
parfor q = 1:nJ
    H = Hs(gh(q)); co = struct('H',H,'setType',sets{gs(q)},'margin',0.02,'ro',ro,'maxWin',round(20/H)+1);
    r = chain_cell(P, net, cellsJ{q}, co);
    st(q) = r.status; rs(q) = r.reason; pv(q) = r.provFirst; c20(q) = r.cert20; cInf(q) = r.certInf;
    nWin(q) = r.nWinOK; tF(q) = r.tFail; Ml(q) = r.Mlow; rt(q) = r.runtime; c5(q) = r.close5K;
    if ~isempty(r.phiEnd), phW(q) = r.phiEnd(end,2) - r.phiEnd(end,1); end
    if ~isempty(r.winTime), wMax(q) = max(r.winTime); end
end
wallChain = toc(t0);
J = M.T(idx(gc(:)), {'water','d0_m','loc_m','w_mps'});
J.group = grp(gc(:)); J.cell = idx(gc(:)); J.H_s = Hs(gh(:))'; J.set = string(sets(gs(:)))';
J.status = st; J.reason = rs; J.prov = pv; J.cert20 = c20; J.certInf = cInf; J.nWinOK = nWin;
J.tCert_s = nWin.*J.H_s; J.tFail_s = tF; J.Mlow_dB = Ml; J.close5_win = c5; J.phi_width_last_rad = phW;
J.win_max_s = wMax; J.runtime_s = rt;
writetable(J, fullfile(outdir, ['chain_jobs' chainTag '.csv']));
fprintf('[chain] reach part wall %.0f s, CPU %.0f s\n', wallChain, sum(rt));

% ---- per cell and H: certified by any set type? reason otherwise (furthest-reaching config)
S = M.T(idx, {'water','d0_m','loc_m','w_mps','verdict_maint'}); S.group = grp; S.cell = idx;
for h = 1:numel(Hs)
    v = strings(nCell,1); why = strings(nCell,1); bestSet = strings(nCell,1);
    for i = 1:nCell
        jj = find(gc(:) == i & gh(:) == h);
        if any(c20(jj))
            v(i) = "Certified(chain)"; k = jj(find(c20(jj),1)); bestSet(i) = J.set(k);
            if any(cInf(jj)), v(i) = "Certified(chain,unbounded)"; end
        else
            [~, b] = max(nWin(jj) + 1e-3*fillmissing(tF(jj),'constant',0)); k = jj(b);
            v(i) = "Inconclusive"; why(i) = rs(k); bestSet(i) = J.set(k);
        end
    end
    S.(sprintf('chain_H%d', Hs(h))) = v; S.(sprintf('reason_H%d', Hs(h))) = why; S.(sprintf('set_H%d', Hs(h))) = bestSet;
end

% ---- soundness: strong falsifier on every chain-certified cell (T = 20 s)
fc = find(S.chain_H4 ~= "Inconclusive" | S.chain_H5 ~= "Inconclusive");
fo = struct('pop',200,'iters',25,'elite',20,'tol',0.01);
ff = false(numel(fc),1); fr = nan(numel(fc),1); fp = zeros(numel(fc),1); ftm = zeros(numel(fc),1);
cellsF = M.cells(idx(fc)); t1 = tic;
parfor q = 1:numel(fc)
    rng(7000 + q); tt = tic;
    F = falsify_cell(P, @(z,k,x) deal(nn_forward(net,z), false(1,size(z,2))), cellsF{q}, fo);
    ff(q) = F.found; fr(q) = F.rho; fp(q) = F.prov; ftm(q) = toc(tt);
end
wallFals = toc(t1);
S.fals_found = false(nCell,1); S.fals_min_rho = nan(nCell,1); S.fals_prov = zeros(nCell,1);
S.fals_found(fc) = ff; S.fals_min_rho(fc) = fr; S.fals_prov(fc) = fp;
S.soundness_violation = S.fals_found & (S.chain_H4 ~= "Inconclusive" | S.chain_H5 ~= "Inconclusive");
writetable(S, fullfile(outdir, ['chain_cells' chainTag '.csv']));
wall = toc(t0);
save(fullfile(outdir, ['chain' chainTag '.mat']), 'J', 'S', 'wall', 'wallChain', 'wallFals');
fprintf('[chain] falsifier wall %.0f s (%d cells, CPU %.0f s), witnesses %d\n', wallFals, numel(fc), sum(ftm), sum(ff));
fprintf('[chain] total wall %.0f s\n', wall);
for h = Hs
    for g = unique(S.group)'
        fprintf('--- H = %d, %s\n', h, g); m = S.group == g;
        disp(groupcounts(S(m,:), sprintf('chain_H%d', h)));
        disp(groupcounts(S(m & S.(sprintf('chain_H%d',h)) == "Inconclusive",:), sprintf('reason_H%d', h)));
    end
end
