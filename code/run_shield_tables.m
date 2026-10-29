% RUN_SHIELD_TABLES  S1 + S2 precomputation. Runtime tiling of invocation states
% (water, d, phi, e boxes x velocity bins: u (0.1 m/s bins for the NN, 0.2 for the
% fallbacks), r in 3 bins, |v| <= 0.05) under the DECLARED bounds
% (|w| <= 0.05 m/s, localisation 0.10 m, c +-10 %), horizon H = 4 s:
%   - 'nn'   : residual actor res_32       (lookup certificates for the S2 shield)
%   - 'sway' : sway-capable fallback (S1)  (certified fallback region)
%   - 'old'  : slow-down/turn fallback     (baseline fallback region)
% Each cell gets Certified / Falsified / Inconclusive (CORA + Monte Carlo + falsifier).
P = setup_paths();
L = load(fullfile(P.results,'phase2','actor_res_32.mat'));
H = 4; wDecl = 0.05; locDecl = 0.10;
eBins = deg2rad([-10 -5; -5 5; 5 10]);
phiE = deg2rad(-30:10:30);
rB = [-0.2 -0.07; -0.07 0.07; 0.07 0.2];
uBnn = [-0.2 -0.1; -0.1 0; 0 0.1; 0.1 0.2]; uBfb = [-0.2 0; 0 0.2];
for ci = 1:3, cellsC{ci} = {}; metaC{ci} = []; end %#ok<SAGROW>
for ci = 1:3
uB = uBnn; if ci > 1, uB = uBfb; end
cells = {}; meta = [];
for wi = 1:3
    dout = fzero(@(d) margin_db(P,d,0,0,P.water.c(wi)), [0.3 60]);
    dE = 1:0.5:(floor(2*dout)/2);
    for i = 1:numel(dE)-1
        for j = 1:numel(phiE)-1
            for k = 1:size(eBins,1)
              for a = 1:size(uB,1)
                for b = 1:size(rB,1)
                c = make_cell(P, wi, (dE(i)+dE(i+1))/2, deg2rad(5), locDecl, wDecl, 'T', H, 'Te', H);
                c.lo = [dE(i); phiE(j); eBins(k,1); uB(a,1); -0.05; rB(b,1)];
                c.hi = [dE(i+1); phiE(j+1); eBins(k,2); uB(a,2); 0.05; rB(b,2)];
                cells{end+1} = c; meta(end+1,:) = [wi dE(i) dE(i+1) phiE(j) phiE(j+1) eBins(k,:) uB(a,:) rB(b,:)]; %#ok<SAGROW>
                end
              end
            end
        end
    end
end
cellsC{ci} = cells; metaC{ci} = meta;
end
eo = default_eo(); eo.nMC = 100; eo.maxDepth = 0; eo.checkCertified = false; eo.estFals = false;
eo.precheck = true; eo.fo.iters = 4;
outdir = fullfile(P.results,'shield'); if ~exist(outdir,'dir'), mkdir(outdir); end
ctrls = {'nn','sway','old'};
for ci = 1:3
    t0 = tic;
    eoc = eo; cells = cellsC{ci}; meta = metaC{ci};
    switch ctrls{ci}
        case 'nn',   nets = repmat({L.net}, 1, 3);
        case 'sway', nets = arrayfun(@(wi) fallback_sway(P, wi), 1:3, 'uni', 0); eoc.ro.timeStep = 0.02; eoc.ro.taylorTerms = 6;
        case 'old',  nets = repmat({fallback_net(P)}, 1, 3);
    end
    % run per water (the sway fallback is water-specific through d_ref)
    Ts = {}; Rall = {};
    for wi = 1:3
        m = find(meta(:,1) == wi);
        [Rs, T] = run_cells(P, nets{wi}, cells(m), eoc, 10);
        T.e_lo_deg = rad2deg(meta(m,6)); T.e_hi_deg = rad2deg(meta(m,7));
        T.d_lo = meta(m,2); T.d_hi = meta(m,3); T.phi_lo_deg = rad2deg(meta(m,4)); T.phi_hi_deg = rad2deg(meta(m,5));
        T.u_lo = meta(m,8); T.u_hi = meta(m,9); T.r_lo = meta(m,10); T.r_hi = meta(m,11);
        Ts{end+1} = T; Rall = [Rall; Rs]; %#ok<AGROW>
    end
    T = vertcat(Ts{:}); wall = toc(t0);
    save(fullfile(outdir, ['table_' ctrls{ci} '.mat']), 'T', 'Rall', 'H', 'wDecl', 'locDecl', 'wall');
    writetable(T, fullfile(outdir, ['table_' ctrls{ci} '.csv']));
    fprintf('[tables] %s: wall %.0f s\n', ctrls{ci}, wall); disp(groupcounts(T, {'water','verdict_maint'}));
end
