% RUN_SLOWCUR  Campaign E: slowly varying current (results/slowcur/METHOD.md).
% Workspace options:
%   scStage  cell array of {'R0','R1','ccvR0','ccvR1'} (default all, in this order)
%   scW      pool size (default 10; use <= 2 while the pool is shared)
%   scSub    subset of the 99 job indices (unit tests)
%   scTag    suffix of the output files (default '')
% Cells (slowcur_cells): 67 unresolved + 32 Certified hero-map cells, plus the 3 cells
% falsified in Sec. 12j (falsifier only, to confirm their witness is admissible).
% Per cell and regime:
%   reach  pass 1 = reach_refine(order 100, depth 2); pass 2 = order 200, depth 2 if pass 1
%          does not certify (A2 settings); both re-enclose the current after every control
%          period (cellc.rateReset = 'always'). R0 only: pass 3 = order 100, depth 2, keeping
%          the dependence on the initial current. Certified if any pass certifies. Cells with w0 = 0 are not re-run: with no current
%          the model is identical to the reference, so the reference verdict carries over.
%   MC     500 runs of the regime family (mc_scen with curModel 'rate').
%   fals   cross-entropy 200 x 25 in the regime family (falsify_cell) + constant sideways
%          adversary (slowcur_sideways). Run on every cell with w0 > 0.
% R1 is run on the cells that R0 certifies (METHOD Sec. 6).
if ~exist('scStage','var'), scStage = {'R0','R1','ccvR0','ccvR1'}; end
if ~exist('scW','var'), scW = 10; end
if ~exist('scTag','var'), scTag = ''; end
P = setup_paths(); L = load(fullfile(P.results,'phase2','actor_res_32.mat')); net = L.net;
od = fullfile(P.results,'slowcur'); if ~exist(od,'dir'), mkdir(od); end
S = slowcur_cells(P); M = S.M;
rhoFac = struct('R0', 0, 'R1', pi/20);
t00 = tic;
for st = 1:numel(scStage)
    stg = scStage{st};
    if any(strcmp(stg, {'R0','R1'}))
        jobs = (1:99)';
        if exist('scSub','var'), jobs = jobs(scSub(:)); end
        if strcmp(stg,'R1')
            R0f = fullfile(od, ['slowcur_R0' scTag '.mat']);
            R0 = load(R0f); jobs = jobs(ismember(jobs, R0.T.job(R0.T.verdict == "Certified" & R0.T.w_mps > 0)));
        end
        jobs = [jobs; 100 + (1:numel(S.fals3))'];          % the 3 sideways-falsified cells
        idxAll = [S.idxOp; S.fals3]; setAll = [S.set; repmat("falsified3", numel(S.fals3), 1)];
        neAll = [S.nearEdge; false(numel(S.fals3),1)];
        jj = jobs; jj(jj > 100) = jj(jj > 100) - 100 + 99;
        n = numel(jj); cellsS = M.cells(idxAll(jj));
        ro1 = default_eo().ro; ro1.tmax = 1800; ro2 = ro1; ro2.zonotopeOrder = 200;
        fo = struct('pop',200,'iters',25,'elite',20,'tol',0.01);
        get_pool(scW); pctRunOnAll(sprintf('addpath(''%s''); addpath(genpath(''%s''));', P.code, P.cora));
        c0 = cellsS{1}; c0.T = P.dt_ctrl; c0.curModel = 'rate'; c0.rho = rhoFac.(stg)*max(c0.w,0.025); c0.w = max(c0.w, 0.025);
        reach_cell(P, net, c0, ro1);                         % generate CORA derivative files once
        ctrl = make_ctrl(net);
        out = cell(n,1); isF = setAll(jj) == "falsified3";
        parfor q = 1:n
            c = cellsS{q}; c.curModel = 'rate'; c.rho = rhoFac.(stg)*c.w; o = struct();
            o.p1_status = ""; o.p1_cert = false; o.p2_status = ""; o.p2_cert = false; o.p3_status = ""; o.p3_cert = false;
            o.cert_by = ""; o.Mlow = nan; o.possTx = false; o.possRx = false; o.possP = false; o.tFirstViol = nan;
            o.provFirst = ""; o.reach_s = 0; o.ran = false;
            if c.w > 0 && ~isF(q)
                o.ran = true;
                % pass 1/2: re-enclose the current after every period (R0: piecewise-constant
                % enclosure; R1: same as the automatic test, which fires nearly every period);
                % pass 3 (R0 only): keep the dependence on the initial current (no reset)
                cA = c; cA.rateReset = 'always';
                R1 = reach_refine(P, net, cA, ro1, 2); o.p1_status = strjoin(unique(R1.statuses),'|'); o.p1_cert = R1.maint;
                RR = R1; o.reach_s = R1.runtime; if R1.maint, o.cert_by = "p1"; end
                if ~R1.maint
                    R2 = reach_refine(P, net, cA, ro2, 2); o.p2_status = strjoin(unique(R2.statuses),'|'); o.p2_cert = R2.maint;
                    RR = R2; o.reach_s = o.reach_s + R2.runtime; if R2.maint, o.cert_by = "p2"; end
                end
                if ~o.p1_cert && ~o.p2_cert && c.rho == 0
                    R3 = reach_refine(P, net, c, ro1, 2); o.p3_status = strjoin(unique(R3.statuses),'|'); o.p3_cert = R3.maint;
                    o.reach_s = o.reach_s + R3.runtime; if R3.maint, o.cert_by = "p3"; RR = R3; end
                end
                o.Mlow = RR.Mlow; o.possTx = RR.possTx; o.possRx = RR.possRx; o.possP = RR.possP;
                o.tFirstViol = RR.tFirstViol; o.provFirst = string(RR.provFirst);
            end
            o.mc_rho = nan; o.mc_outage = nan; o.ce_found = false; o.ce_rho = nan; o.ce_prov = 0;
            o.sw_found = false; o.sw_rho = nan; o.sw_prov = 0; o.sw_tOut = nan; o.sw_nviol = 0; o.fals_s = 0;
            if c.w > 0
                t1 = tic;
                rng(7000 + q);
                so = sim_closed_loop(P, mc_scen(P, c, 500), ctrl, struct('T', c.T));
                o.mc_rho = min(so.rho); o.mc_outage = mean(so.rho < -0.01);
                rng(7500 + q);
                F = falsify_cell(P, ctrl, c, fo); o.ce_found = F.found; o.ce_rho = F.rho; o.ce_prov = F.prov;
                rng(8000 + q);
                SW = slowcur_sideways(P, ctrl, c, 3000);
                o.sw_found = SW.found; o.sw_rho = SW.min_rho; o.sw_prov = SW.w_prov; o.sw_tOut = SW.w_tOut; o.sw_nviol = SW.n_viol;
                o.fals_s = toc(t1);
            end
            out{q} = o;
        end
        O = [out{:}]; T = struct2table(O);
        I = idxAll(jj);
        T = [table(jobs, I, setAll(jj), neAll(jj), string(M.T.water(I)), M.T.d0_m(I), M.T.loc_m(I), M.T.w_mps(I), ...
            'VariableNames', {'job','cell','set','near_edge','water','d0_m','loc_m','w_mps'}), T];
        % reference verdict
        ref = repmat("Inconclusive", n, 1); ref(T.set ~= "unresolved67") = "Certified"; ref(T.set == "falsified3") = "Falsified";
        T.ref_verdict = ref;
        % regime verdict
        cert = T.p1_cert | T.p2_cert | T.p3_cert;
        wit = (T.mc_rho < -0.01) | T.ce_found | T.sw_found;
        v = repmat("Inconclusive", n, 1); v(cert) = "Certified"; v(~cert & wit) = "Falsified";
        w0 = T.w_mps == 0; v(w0) = T.ref_verdict(w0);                  % identical model, carried over
        T.verdict = v; T.carried_w0 = w0;
        T.soundness_violation = cert & wit;
        rs = strings(n,1);
        for q = 1:n
            if v(q) ~= "Inconclusive" || ~T.ran(q), continue; end
            s = T.p2_status(q); if s == "", s = T.p1_status(q); end
            if contains(s, "explosion") || contains(s, "error") || contains(s, "timeout"), rs(q) = "explosion";
            elseif contains(s, "model-range"), rs(q) = "model-range";
            else
                nm = ["Tx","Rx","P"]; rs(q) = "ace:" + strjoin(nm([T.possTx(q) T.possRx(q) T.possP(q)]), "+");
            end
        end
        T.reason = rs;
        writetable(T, fullfile(od, ['slowcur_' stg scTag '.csv'])); save(fullfile(od, ['slowcur_' stg scTag '.mat']), 'T');
        fprintf('[slowcur] %s done (%d jobs), %.0f s\n', stg, n, toc(t00));
        disp(groupcounts(T, {'set','verdict'}));
        fprintf('[slowcur] %s soundness violations: %d\n', stg, nnz(T.soundness_violation));
    elseif any(strcmp(stg, {'ccvR0','ccvR1'}))
        rf = rhoFac.(stg(4:5));
                actorTag = 'res_32'; ccvModel = '2d'; ccvTag = ['slowcur_' stg(4:5) scTag]; ccvLocs = 0.1; ccvWaters = [1 2];
        ccvCurModel = 'rate'; ccvRhoFac = rf; ccvRateReset = 'always'; ccvOutDir = od;
        get_pool(scW);
        run_ccv;
        clear ccvCurModel ccvRhoFac ccvRateReset ccvOutDir ccvTag
        fprintf('[slowcur] %s done, %.0f s\n', stg, toc(t00));
    end
end
