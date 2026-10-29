% RUN_SHIELD_TABLE_SWAY_V2  S1 sway-fallback table over its operating range (Task 12f).
% The v1 table (run_shield_tables, results/shield/table_sway.*) assumes |v| <= 0.05 m/s.
% The logged fallback steps (run_shield_sway_v2_eval('v1log'),
% results/shield/sway_v2_invocation_pctl_v1log.csv) reach |v_hat| ~ 0.21 m/s, while u and r
% stay inside the v1 bins (u in [-0.2, 0.2] in 2 bins, r in [-0.2, 0.2] in 3 bins).
% v2 adds sway-velocity bins of the v1 width (0.1 m/s):
%   v in [-0.25,-0.15], [-0.15,-0.05], [-0.05,0.05], [0.05,0.15], [0.15,0.25].
% Everything else is identical to v1: the same d/phi/e/u/r bins, H = 4 s, declared bounds
% |w| <= 0.05 m/s and localisation 0.10 m, c +-10 %, the fallback CORA model aug_dyn_fb
% (damping envelope P.qXfb, |v| <= 0.35), time step 0.02 s, 6 Taylor terms, 100 MC runs,
% falsifier 4 x 120.
% Three sources per tile (column 'source'):
%   'v1'       v in [-0.05, 0.05]: the v1 tile itself (identical cell and settings);
%   'computed' v in [0.05, 0.25]: computed here;
%   'mirror'   v in [-0.25, -0.05]: the mirror image (phi, e, v, r, w_t) -> -(.) of a
%              computed tile. The planar model, the fallback law (odd in phi_hat and
%              e_hat, even in d_hat), the ACE predicates and every declared bound are
%              invariant under this reflection, so the mirrored over-approximation is a
%              sound over-approximation for the mirrored tile, and mirrored witnesses are
%              witnesses. The v1 table is used as a numerical check of the symmetry.
% One cost change that cannot alter a verdict: reachability is skipped for tiles that
% Monte Carlo already falsifies (eo.skipReachIfWitness; such tiles are Falsified either way).
% Output: results/shield/table_sway_v2.csv|mat, results/shield/table_sway_v2_summary.csv
P = setup_paths();
H = 4; wDecl = 0.05; locDecl = 0.10;
eBins = deg2rad([-10 -5; -5 5; 5 10]);
phiE = deg2rad(-30:10:30);
rB = [-0.2 -0.07; -0.07 0.07; 0.07 0.2];
uB = [-0.2 0; 0 0.2];
vNew = [0.05 0.15; 0.15 0.25];
cells = {}; meta = [];
for wi = 1:3
    dout = fzero(@(d) margin_db(P,d,0,0,P.water.c(wi)), [0.3 60]);
    dE = 1:0.5:(floor(2*dout)/2);
    for i = 1:numel(dE)-1
        for j = 1:numel(phiE)-1
            for k = 1:size(eBins,1)
                for a = 1:size(uB,1)
                    for vv = 1:size(vNew,1)
                        for b = 1:size(rB,1)
                            c = make_cell(P, wi, (dE(i)+dE(i+1))/2, deg2rad(5), locDecl, wDecl, 'T', H, 'Te', H);
                            c.lo = [dE(i); phiE(j); eBins(k,1); uB(a,1); vNew(vv,1); rB(b,1)];
                            c.hi = [dE(i+1); phiE(j+1); eBins(k,2); uB(a,2); vNew(vv,2); rB(b,2)];
                            cells{end+1} = c; %#ok<SAGROW>
                            meta(end+1,:) = [wi dE(i) dE(i+1) phiE(j) phiE(j+1) eBins(k,:) uB(a,:) vNew(vv,:) rB(b,:)]; %#ok<SAGROW>
                        end
                    end
                end
            end
        end
    end
end
fprintf('[sway_v2] %d tiles to compute\n', numel(cells));
eo = default_eo(); eo.nMC = 100; eo.maxDepth = 0; eo.checkCertified = false; eo.estFals = false;
eo.precheck = true; eo.fo.iters = 4; eo.skipReachIfWitness = true;
eo.ro.timeStep = 0.02; eo.ro.taylorTerms = 6;
outdir = fullfile(P.results,'shield');
t0 = tic; Ts = {}; Rall = {};
for wi = 1:3
    m = find(meta(:,1) == wi); tw = tic;
    [Rs, T] = run_cells(P, fallback_sway(P, wi), cells(m), eo, 10);
    T.e_lo_deg = rad2deg(meta(m,6)); T.e_hi_deg = rad2deg(meta(m,7));
    T.d_lo = meta(m,2); T.d_hi = meta(m,3); T.phi_lo_deg = rad2deg(meta(m,4)); T.phi_hi_deg = rad2deg(meta(m,5));
    T.u_lo = meta(m,8); T.u_hi = meta(m,9); T.v_lo = meta(m,10); T.v_hi = meta(m,11); T.r_lo = meta(m,12); T.r_hi = meta(m,13);
    Ts{end+1} = T; Rall = [Rall; Rs]; %#ok<SAGROW,AGROW>
    fprintf('[sway_v2] water %d: %d tiles, wall %.0f s\n', wi, numel(m), toc(tw));
    save(fullfile(outdir, 'table_sway_v2_partial.mat'), 'Ts', 'Rall');
end
Tc = vertcat(Ts{:}); wall = toc(t0);
Tc.source = repmat("computed", height(Tc), 1);
% mirror tiles (v < -0.05)
Tm = Tc;
Tm.phi_lo_deg = -Tc.phi_hi_deg; Tm.phi_hi_deg = -Tc.phi_lo_deg; Tm.phi0_deg = -Tc.phi0_deg;
Tm.e_lo_deg = -Tc.e_hi_deg; Tm.e_hi_deg = -Tc.e_lo_deg;
Tm.v_lo = -Tc.v_hi; Tm.v_hi = -Tc.v_lo; Tm.r_lo = -Tc.r_hi; Tm.r_hi = -Tc.r_lo;
Tm.source = repmat("mirror", height(Tm), 1);
% v1 tiles (|v| <= 0.05)
S1 = load(fullfile(outdir, 'table_sway.mat')); T1 = S1.T;
T1.v_lo = -0.05*ones(height(T1),1); T1.v_hi = 0.05*ones(height(T1),1); T1.source = repmat("v1", height(T1), 1);
T1 = T1(:, Tc.Properties.VariableNames);
T = [T1; Tc; Tm];
% ---------------- symmetry check on the v1 table ----------------
key = @(Q, s) round([double(categorical(Q.water)) Q.d_lo s*Q.phi_lo_deg s*Q.phi_hi_deg s*Q.e_lo_deg s*Q.e_hi_deg Q.u_lo s*Q.r_lo s*Q.r_hi]*1000);
K1 = key(T1, 1); K1m = key(T1, -1); K1m = K1m(:, [1 2 4 3 6 5 7 9 8]);
[tf, loc] = ismember(K1m, K1, 'rows');
agree = T1.verdict_maint(tf) == T1.verdict_maint(loc(tf));
certPair = T1.verdict_maint(tf) == "Certified" | T1.verdict_maint(loc(tf)) == "Certified";
fprintf('[sway_v2] v1 mirror check: %d pairs, verdict agreement %d (%.3f); among pairs with a Certified member: %d of %d agree\n', ...
    nnz(tf), nnz(agree), mean(agree), nnz(agree & certPair), nnz(certPair));
% ---------------- envelope / status accounting ----------------
inEnv = max(abs([T.u_lo T.u_hi]),[],2) <= P.qXfb(1) & max(abs([T.v_lo T.v_hi]),[],2) <= P.qXfb(2) & max(abs([T.r_lo T.r_hi]),[],2) <= P.qXfb(3);
mr = contains(T.reach_status, "model-range");
ex = contains(T.reach_status, "explosion") | contains(T.reach_status, "Explosion");
sumRows = {};
vb = unique([T.v_lo T.v_hi], 'rows');
for q = 1:size(vb,1)
    for wi = 1:3
        m = T.v_lo == vb(q,1) & T.water == P.water.name{wi};
        sumRows(end+1,:) = {vb(q,1), vb(q,2), P.water.name{wi}, nnz(m), nnz(m & T.verdict_maint=="Certified"), ...
            nnz(m & T.verdict_maint=="Falsified"), nnz(m & T.verdict_maint=="Inconclusive"), nnz(m & ~inEnv), ...
            nnz(m & mr), nnz(m & mr & T.verdict_maint=="Inconclusive"), nnz(m & ex), string(strjoin(unique(T.source(m)),'/'))}; %#ok<SAGROW>
    end
end
TS = cell2table(sumRows, 'VariableNames', {'v_lo','v_hi','water','n','certified','falsified','inconclusive', ...
    'initial_box_outside_envelope','reach_left_envelope','inconclusive_by_envelope','reach_explosion','source'});
symm = struct('pairs', nnz(tf), 'agree', nnz(agree), 'pairsWithCert', nnz(certPair), 'agreeWithCert', nnz(agree & certPair));
save(fullfile(outdir, 'table_sway_v2.mat'), 'T', 'Rall', 'H', 'wDecl', 'locDecl', 'wall', 'symm', 'TS');
writetable(T, fullfile(outdir, 'table_sway_v2.csv'));
writetable(TS, fullfile(outdir, 'table_sway_v2_summary.csv'));
fprintf('[sway_v2] computed-tile wall %.0f s\n', wall); disp(TS); disp(groupcounts(T, {'water','verdict_maint'}));
