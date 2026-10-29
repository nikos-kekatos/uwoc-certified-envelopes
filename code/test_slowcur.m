% TEST_SLOWCUR  Unit tests for campaign E (serial, 2 threads). Writes results/slowcur/test_*.txt
P = setup_paths(); maxNumCompThreads(2);
L = load(fullfile(P.results,'phase2','actor_res_32.mat')); net = L.net; ctrl = make_ctrl(net);
od = fullfile(P.results,'slowcur'); if ~exist(od,'dir'), mkdir(od); end
if ~exist('tsStage','var'), tsStage = {'cells','paths','reach','mcbox'}; end
S = slowcur_cells(P); M = S.M;
fprintf('cells: %d unresolved, %d certified, %d near-edge\n', nnz(S.set=="unresolved67"), nnz(S.set~="unresolved67"), nnz(S.nearEdge));
% ---- 1) admissibility of the sampled current paths ----
if any(strcmp(tsStage,'paths'))
    c = M.cells{S.idxOp(1)}; c.w = 0.075; tt = 0:0.01:20; x = zeros(6,1);
    for rhoF = [0 pi/20]
        c.rho = rhoF*c.w;
        for kind = ["mc","fals"]
            TH = rand(5,2000); sn = rand(5,2000) < 0.3; TH(sn) = round(TH(sn));
            wf = cur_rate_wfun(c, TH, char(kind));
            W = zeros(2,2000,numel(tt));
            for k = 1:numel(tt), W(:,:,k) = wf(tt(k), zeros(6,2000)); end   % phi = 0: polar = world
            mag = squeeze(sqrt(sum(W.^2,1))); rate = abs(diff(W,1,3))/0.01;
            fprintf('paths rho=%.4f %s: max|W|/w0 = %.6f, max rate/rho = %.4f (rho>0), max change = %.2e\n', ...
                c.rho, kind, max(mag(:))/c.w, max(rate(:))/max(c.rho,eps), max(abs(W(:,:,end)-W(:,:,1)),[],'all'));
        end
    end
end
% ---- 2) reach on a few cells: reference vs R0 vs R1 ----
if any(strcmp(tsStage,'reach'))
    ro = default_eo().ro; ro.tmax = 1500;
    if ~exist('tsCells','var'), tsCells = [find(S.set=="certified_hero" & M.T.w_mps(S.idxOp) > 0,1), 1]; end
    for q = tsCells
        c = M.cells{S.idxOp(q)};
        fprintf('--- cell %d (%s) %s d0=%g loc=%g w=%g\n', S.idxOp(q), S.set(q), M.T.water(S.idxOp(q)), M.T.d0_m(S.idxOp(q)), c.loc, c.w);
        if ~exist('tsRegs','var'), tsRegs = ["ref","disk","R0","R1"]; end
        for reg = tsRegs
            cc = c;
            switch reg
                case "disk", cc.curModel = 'disk';
                case "R0", cc.curModel = 'rate'; cc.rho = 0;
                case "R1", cc.curModel = 'rate'; cc.rho = pi/20*c.w;
                case "R0r", cc.curModel = 'rate'; cc.rho = 0; cc.rateReset = 'always';
                case "R0o2", cc.curModel = 'rate'; cc.rho = 0;
            end
            ror = ro; if reg == "R0o2", ror.zonotopeOrder = 200; end
            r = reach_cell(P, net, cc, ror);
            nr = nan; if isfield(r,'nReset'), nr = r.nReset; end
            fprintf('  %-4s status %-10s maint %d Mlow %7.3f tReached %5.2f tFirstViol %5.2f %s widths d %.3f phi %.3f e %.3f resets %g  %.0f s\n', ...
                reg, r.status, r.maint, r.Mlow, r.tReached, r.tFirstViol, r.provFirst, r.width_d_final, r.width_phi_final, r.width_e_final, nr, r.runtime);
        end
    end
end
% ---- 3) enclosure check: R0/R1 simulated trajectories inside the stored reach boxes ----
if any(strcmp(tsStage,'mcbox'))
    q = find(S.set=="certified_hero" & M.T.w_mps(S.idxOp) > 0, 1); c = M.cells{S.idxOp(q)};
    fprintf('enclosure test on cell %d, w = %g\n', S.idxOp(q), c.w);
    ro = default_eo().ro; ro.storeBoxes = true;
    for rhoF = [0 pi/20]
        cc = c; cc.curModel = 'rate'; cc.rho = rhoF*c.w; cc.T = 8;
        r = reach_cell(P, net, cc, ro);
        rng(3); sc = mc_scen(P, cc, 300);
        o = sim_closed_loop(P, sc, ctrl, struct('T', cc.T, 'keep', true));
        B = r.boxes; viol = 0; worst = -inf;
        for k = 1:numel(o.t)
            j = find(B(:,1) <= o.t(k)+1e-9 & B(:,2) >= o.t(k)-1e-9, 1);
            if isempty(j), continue; end
            xs = squeeze(o.X(1:3,:,k)); lo = B(j,3:5)'; hi = B(j,6:8)';
            ex = max(max(lo - xs, xs - hi), [], 1); worst = max(worst, max(ex));
            viol = viol + nnz(ex > 1e-6);
        end
        fprintf('enclosure rho=%.4f: status %s, %d samples outside the reach boxes (max excess %.2e)\n', cc.rho, r.status, viol, worst);
    end
end
