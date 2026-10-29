% RUN_SHIELD_V2  S3-S5: harder test set and shield ablation (secondary contribution).
% Declared bounds of the shielded system: |w| <= 0.05 m/s, localisation 0.10 m.
% Rows (S4), 200 seeded trajectories each:
%   A  replay of the falsifier witnesses of the 27 apparent-success-but-Falsified
%      operating-map cells (8 per witness: the witness + 7 neighbours, first 200)
%   B1..B4 starts near the envelope boundary (d0 0.6-0.85 of the power range,
%      |phi0| 10-25 deg, |e0| <= 10 deg) with a current step at t_s ~ U[3,8] s from
%      <= 0.5 x to 1.0 / 1.5 / 2.0 / 3.0 x the declared bound
%   C  as B1 plus localisation spikes (5 % of steps, 0.5-1.0 m)
% Controllers (S5): classical, NN, NN+clip, NN+monitor->sway fallback, lookup shield
% with old / sway fallback, lookup+sway+monitor, online-CORA shield with old / sway
% fallback (online variants on the first 20 trajectories of each row, cost).
P = setup_paths();
L = load(fullfile(P.results,'phase2','actor_res_32.mat')); net = L.net;
LT = load_shield_tables(P);
decl = struct('w', 0.05, 'loc', 0.10);
outdir = fullfile(P.results,'shield'); if ~exist(outdir,'dir'), mkdir(outdir); end
nRow = 200; nOnline = 20;
% ---------------- online CORA shield set-up ----------------
sh = struct('H',2.0,'loc',decl.loc,'w',decl.w,'epsPsi',P.eps_psi,'epsVel',[P.eps_u;P.eps_v;P.eps_r],'crel',P.c_rel_unc);
evo = nnHelper.validateNNoptions(struct('nn', struct('poly_method','singh'))); evo.nn.add_approx_error_to_GI = true; sh.evo = evo;
[sh.sys, sh.params, sh.options] = aux_sys(P, 'old', decl);
[sh.sysFb, sh.paramsFb, sh.optionsFb] = aux_sys(P, 'sway', decl);
sh.Sfb = ctrl_sets(fallback_net(P));
% ---------------- rows ----------------
rows = {}; rowName = {};
rng(31); rows{end+1} = aux_rowA(P, net, nRow); rowName{end+1} = 'A_witness';
facs = [1.0 1.5 2.0 3.0];
for f = facs, rng(40 + round(10*f)); rows{end+1} = aux_rowB(P, decl, nRow, f, 0); rowName{end+1} = sprintf('B_x%.1f', f); end
rng(60); rows{end+1} = aux_rowB(P, decl, nRow, 1.0, 0.05); rowName{end+1} = 'C_spikes';
save(fullfile(outdir,'s4_rows.mat'), 'rows', 'rowName', 'decl');
ctrls = {'classical','NN','NN+clip','NN+M(sway)','L(old)','L(sway)','L(sway)+M','O(old)','O(sway)'};
jobs = {};
for r = 1:numel(rows)
    for c = 1:numel(ctrls)
        if startsWith(ctrls{c}, 'O(')
            for j = 1:nOnline, jobs{end+1} = [r c j]; end %#ok<SAGROW>
        else
            jobs{end+1} = [r c 0]; %#ok<SAGROW>
        end
    end
end
get_pool(10);
pctRunOnAll(sprintf('addpath(''%s''); addpath(genpath(''%s''));', P.code, P.cora));
res = cell(numel(jobs),1);
t0 = tic;
parfor jj = 1:numel(jobs)
    r = jobs{jj}(1); c = jobs{jj}(2); j = jobs{jj}(3);
    G = rows{r};
    if j > 0, G = subset_G(G, j); end
    rng(1000*r + 10*c + j);
    res{jj} = aux_run(P, net, LT, sh, decl, G, ctrls{c});
end
wall = toc(t0);
save(fullfile(outdir,'s5_raw.mat'), 'res', 'jobs', 'ctrls', 'rowName', 'wall', '-v7.3');
% ---------------- aggregate ----------------
out = {};
for r = 1:numel(rows)
    for c = 1:numel(ctrls)
        m = find(cellfun(@(q) q(1)==r && q(2)==c, jobs));
        O = [res{m}];
        oc = [O.outage]; n = numel(oc); k = sum(oc);
        [p, lo, hi] = wilson(k, n);
        tOut = [O.tOut]; tRec = [O.tRecover]; nI = [O.nInterv]; nS = [O.nSteps]; nU = [O.nUnnec];
        tDec = [O.tDec]; fl = [O.firstFlag]; ts = [O.ts]; flagged = [O.flagged];
        G = rows{r}; sub = 1:n; if startsWith(ctrls{c},'O('), sub = 1:nOnline; end
        overB = G.B(sub) > decl.w + 1e-9;
        delay = fl(overB & isfinite(fl)) - ts(overB & isfinite(fl));
        ag = sum(reshape([O.agree],4,[]),2)';
        out(end+1,:) = {rowName{r}, ctrls{c}, n, k, p, lo, hi, mean(tOut), 1 - mean(tOut)/P.T, ...
            mean(tRec(isfinite(tRec))), sum(nI)/sum(nS), sum(nU)/max(sum(nI),1), ...
            mean(tDec), prctile([tDec NaN],95), max([tDec 0]), mean(flagged(~overB)), mean(flagged(overB)), ...
            median(delay), sum(isfinite(fl(overB)))/max(nnz(overB),1), ag(1), ag(2), ag(3), ag(4), ...
            mean([O.Tx]), mean([O.Rx]), mean([O.Pw]), mean([O.fbCert])}; %#ok<SAGROW>
    end
end
T = cell2table(out, 'VariableNames', {'row','controller','n','n_outage','outage_rate','ci_lo','ci_hi', ...
    'mean_outage_time_s','availability','mean_recovery_s','intervention_rate','unnecessary_share', ...
    'decision_mean_s','decision_p95_s','decision_max_s','flag_rate_within_bound','flag_rate_over_bound', ...
    'median_detection_delay_s','detected_share_over_bound','agree_both_acc','agree_both_rej', ...
    'lut_rej_online_acc','online_rej_lut_acc','Tx_rate','Rx_rate','P_rate','fallback_from_certified_tile'});
writetable(T, fullfile(outdir,'s5_ablation.csv')); disp(T(:,1:12));
fprintf('wall %.0f s\n', wall);

% ======================================================================
function [sys, params, options] = aux_sys(P, kind, decl)
if strcmp(kind,'sway')
    sys = nonlinearSys('uwoc2d_v2_fb', @aug_dyn_fb, 9, 5); nx = 9;
    qE = P.qpoly.err*P.qXfb.^2.*P.qDq; ts = 0.02; tt = 6;
else
    sys = nonlinearSys(['uwoc2d_v2_' P.dampModel], @aug_dyn, 8, 5); nx = 8;
    qE = P.qErr; ts = 0.05; tt = 8;
end
params.tStart = 0; params.tFinal = P.dt_ctrl;
params.R0 = polyZonotope(interval(zeros(nx,1), ones(nx,1)));
params.U = zonotope(zeros(5,1), diag([decl.w; decl.w; qE(1:3)']));
options = struct('timeStep',ts,'taylorTerms',tt,'zonotopeOrder',50,'alg','lin','tensorOrder',2);
[params, options] = validateOptions(sys, params, options, 'FunctionName', 'reach');
derivatives(sys, options);
for i = 1:(options.taylorTerms+1), options.factor(i) = options.timeStep^i/factorial(i); end
end

function R = aux_run(P, net, LT, sh, decl, G, name)
scen = scen_generic(P, G); N = size(G.x0,2);
wi = G.wi; S = [];
switch name
    case 'classical', f = @(z,k,x,ex) deal([teacher_policy(P,z); zeros(1,size(z,2))], false(1,size(z,2)));
    case 'NN',        f = @(z,k,x,ex) deal([nn_forward(net,z); zeros(1,size(z,2))], false(1,size(z,2)));
    case 'NN+clip',   f = @(z,k,x,ex) aux_clip(P, net, z);
    otherwise
        chk = 'none'; fb = 'sway'; mon = false;
        if startsWith(name,'L('), chk = 'lookup'; end
        if startsWith(name,'O('), chk = 'online'; end
        if contains(name,'old'), fb = 'old'; end
        if contains(name,'M'), mon = true; end
        S = ShieldCtrl(P, net, chk, fb, mon, wi, decl, LT, sh, scen);
        f = @(z,k,x,ex) S.step(z, k, x, ex);
end
o = sim_closed_loop(P, scen, f, struct('passExtra', true));
R.outage = o.outage; R.tOut = o.tOut; R.tRecover = o.tRecover; R.ts = G.ts;
R.Tx = o.violTx; R.Rx = o.violRx; R.Pw = o.violP;
if isempty(S)
    R.nInterv = zeros(1,N); R.nSteps = o.nCtrl*ones(1,N); R.nUnnec = zeros(1,N); R.tDec = [];
    R.firstFlag = nan(1,N); R.flagged = false(1,N); R.agree = [0 0 0 0]; R.fbCert = nan(1,N);
    if strcmp(name,'NN+clip'), R.nInterv = o.nInterv; end
else
    R.nInterv = S.nInterv; R.nSteps = S.nSteps*ones(1,N); R.nUnnec = S.nUnnec; R.tDec = S.tDec;
    R.firstFlag = S.firstFlag; R.flagged = isfinite(S.firstFlag); R.agree = S.agree; R.fbCert = S.fbCert;
end
end

function [cmd, iv] = aux_clip(P, net, z)
% heuristic geometric clipping (baseline, NOT certified)
cmd = nn_forward(net, z); c0 = cmd;
cmd(1,:) = min(max(cmd(1,:), -P.uc_max/2), P.uc_max/2);
far = abs(z(2,:)) > P.Theta_T/2;
cmd(1,far) = min(cmd(1,far), 0);
bad = far & (sign(cmd(2,:)) == sign(z(2,:)) | cmd(2,:) == 0);
cmd(2,bad) = -sign(z(2,bad)).*max(abs(cmd(2,bad)), 0.5*P.rc_max);
iv = any(abs(cmd - c0) > 1e-12, 1);
cmd = [cmd; zeros(1,size(z,2))];
end

function G = aux_rowA(P, net, n)
% replay of the falsifier witnesses (opmap cells with 0 MC outages but Falsified)
M = load(fullfile(P.results,'opmap','opmap_res_32.mat'));
sel = find(M.T.mc_outage_rate == 0 & M.T.verdict_maint == "Falsified");
fo = default_eo().fo; Gs = {};
for q = 1:numel(sel)
    i = sel(q); c = M.cells{i};
    rng(1000 + i + 1);                                    % falsifier seed used in run_cells/eval_cell
    F = falsify_cell(P, @(z,k,x) deal(nn_forward(net,z), false(1,size(z,2))), c, fo);
    TH = F.theta;
    for j = 1:8
        th = TH; if j > 1, th = min(max(TH + 0.03*randn(size(TH)), 0), 1); end
        Gs{end+1} = aux_theta2G(P, c, th); %#ok<AGROW>
    end
end
% round-robin over witnesses so that all are represented in the first n
nw = numel(sel); order = reshape(reshape(1:8*nw, 8, nw)', 1, []);
G = aux_catG(Gs(order(1:n)));
end

function g = aux_theta2G(P, c, TH)
g.x0 = c.lo + (c.hi - c.lo).*TH(1:6); g.c = c.c*(1 + c.crel*(2*TH(7)-1)); g.chat = c.c; g.wi = c.wi;
g.A = c.w*TH(8); g.a1 = 2*pi*TH(9); g.o1 = 0.2*(2*TH(10)-1); g.B = g.A; g.a2 = g.a1; g.o2 = g.o1; g.ts = 0;
g.br = c.loc*TH(11); g.ba = 2*pi*TH(12); g.bo = 0.5*(2*TH(13)-1); g.hb = c.epsPsi*(2*TH(14)-1);
g.Tp = 1 + 39*TH(15); g.phs = 2*pi*TH(16); g.vb = c.epsVel(:).*(2*TH(17:19)-1);
g.locR = 0; g.epsPsiR = 0; g.epsVelR = [0;0;0]; g.pS = 0; g.sMin = 0; g.sMax = 0;
end

function G = aux_catG(Gs)
f = fieldnames(Gs{1}); G = struct();
for i = 1:numel(f), G.(f{i}) = cell2mat(cellfun(@(g) g.(f{i}), Gs, 'uni', 0)); end
end

function G = aux_rowB(P, decl, n, fac, pS)
U = @(a,b,m) a + (b-a).*rand(1,m);
wi = [ones(1,n/2) 2*ones(1,n/2)];
dout = arrayfun(@(w) fzero(@(d) margin_db(P,d,0,0,P.water.c(w)), [0.3 60]), 1:2);
d0 = U(0.6,0.85,n).*dout(wi);
G.x0 = [d0; sign(rand(1,n)-0.5).*deg2rad(U(10,25,n)); deg2rad(U(-10,10,n)); U(0,0.05,n); U(-0.02,0.02,n); U(-0.02,0.02,n)];
G.c = P.water.c(wi).*(1 + P.c_rel_unc*(2*rand(1,n)-1)); G.chat = P.water.c(wi); G.wi = wi;
G.A = 0.5*decl.w*sqrt(rand(1,n)); G.a1 = 2*pi*rand(1,n); G.o1 = zeros(1,n);
G.B = fac*decl.w*ones(1,n); G.a2 = 2*pi*rand(1,n); G.o2 = zeros(1,n); G.ts = U(3,8,n);
G.br = zeros(1,n); G.ba = zeros(1,n); G.bo = zeros(1,n); G.hb = zeros(1,n); G.Tp = ones(1,n); G.phs = zeros(1,n);
G.vb = zeros(3,n); G.locR = decl.loc*ones(1,n); G.epsPsiR = P.eps_psi*ones(1,n);
G.epsVelR = repmat([P.eps_u; P.eps_v; P.eps_r], 1, n);
G.pS = pS*ones(1,n); G.sMin = 0.5*ones(1,n); G.sMax = 1.0*ones(1,n);
end

function [p, lo, hi] = wilson(k, n)
z = 1.96; p = k/n; den = 1 + z^2/n; c = (p + z^2/(2*n))/den;
h = z*sqrt(p*(1-p)/n + z^2/(4*n^2))/den; lo = max(0, c-h); hi = min(1, c+h);
end
