% RUN_A2_INCONCLUSIVE  Staged resolution of the 74 Inconclusive (apparent-success)
% hero-map cells: pass 1 splitting depth 2 (opmap used 1); pass 2 zonotope order 200
% (from 100) for cells still unknown; stronger falsifier (pop 200 x 25 iterations) on
% the remainder; pass 3 (SEPARATE, weaker property): T = 10 s for cells still unknown,
% run only if more than 30 cells remain unknown.
P = setup_paths(); L = load(fullfile(P.results,'phase2','actor_res_32.mat')); net = L.net;
M = load(fullfile(P.results,'opmap','opmap_res_32.mat'));
sel = find(M.T.verdict_maint == "Inconclusive"); n = numel(sel); cellsS = M.cells(sel);
ro1 = default_eo().ro; ro2 = ro1; ro2.zonotopeOrder = 200;
fo = struct('pop',200,'iters',25,'elite',20,'tol',0.01);
get_pool(10); pctRunOnAll(sprintf('addpath(''%s''); addpath(genpath(''%s''));', P.code, P.cora));
c0 = cellsS{1}; c0.T = P.dt_ctrl; reach_cell(P, net, c0, ro1);
st = strings(n,4); cert = false(n,3); fals = false(n,1); frho = nan(n,1); fprov = zeros(n,1); rt = zeros(n,4);
t0 = tic;
parfor i = 1:n
    c = cellsS{i}; s = strings(1,4); ce = false(1,3); r = zeros(1,4);
    R1 = reach_refine(P, net, c, ro1, 2); s(1) = strjoin(unique(R1.statuses),'|'); ce(1) = R1.maint; r(1) = R1.runtime;
    fl = false; rh = nan; pv = 0;
    if ~ce(1)
        R2 = reach_refine(P, net, c, ro2, 2); s(2) = strjoin(unique(R2.statuses),'|'); ce(2) = R2.maint; r(2) = R2.runtime;
        if ~ce(2)
            rng(5000 + i); t1 = tic;
            F = falsify_cell(P, @(z,k,x) deal(nn_forward(net,z), false(1,size(z,2))), c, fo);
            fl = F.found; rh = F.rho; pv = F.prov; r(3) = toc(t1);

        end
    end
    st(i,:) = s; cert(i,:) = ce; fals(i) = fl; frho(i) = rh; fprov(i) = pv; rt(i,:) = r;
end
% pass 3 (T = 10 s, weaker property) only if more than 30 cells remain unknown
unk = find(~cert(:,1) & ~cert(:,2) & ~fals); pass3run = numel(unk) > 30;
if pass3run
    cU = cellsS(unk); s3 = strings(numel(unk),1); c3 = false(numel(unk),1); r3 = zeros(numel(unk),1);
    parfor q = 1:numel(unk)
        c10 = cU{q}; c10.T = 10; c10.Te = 5;
        R3 = reach_refine(P, net, c10, ro2, 2); s3(q) = strjoin(unique(R3.statuses),'|'); c3(q) = R3.maint; r3(q) = R3.runtime;
    end
    st(unk,4) = s3; cert(unk,3) = c3; rt(unk,4) = r3;
end
fprintf('A2: %d cells unknown after pass 2 + falsifier; pass 3 run: %d\n', numel(unk), pass3run);
wall = toc(t0);
T = M.T(sel, {'water','d0_m','loc_m','w_mps','provenance','reach_status'});
T.pass1_status = st(:,1); T.pass1_certified = cert(:,1);
T.pass2_status = st(:,2); T.pass2_certified = cert(:,2);
T.falsifier_found = fals; T.falsifier_min_rho = frho; T.falsifier_prov = fprov;
T.pass3_T10_status = st(:,4); T.pass3_T10_certified = cert(:,3);
T.runtime_s = rt;
final = repmat("Inconclusive", n, 1); final(cert(:,1)) = "Certified(pass1)";
final(~cert(:,1) & cert(:,2)) = "Certified(pass2)"; final(~cert(:,1) & ~cert(:,2) & fals) = "Falsified(strong falsifier)";
T.final_T20 = final;
outdir = fullfile(P.results,'a2'); if ~exist(outdir,'dir'), mkdir(outdir); end
writetable(T, fullfile(outdir,'a2_inconclusive.csv')); save(fullfile(outdir,'a2_inconclusive.mat'),'T','wall');
fprintf('A2 wall %.0f s\n', wall); disp(groupcounts(T,'final_T20')); disp(groupcounts(T(T.final_T20=="Inconclusive",:),'pass3_T10_certified'));
