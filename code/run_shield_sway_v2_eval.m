function run_shield_sway_v2_eval(tag)
% RUN_SHIELD_SWAY_V2_EVAL  Re-run of the S5 rows that use the sway fallback
% (B x1.0/1.5/2.0/3.0 and C; controllers NN+M(sway), L(sway), L(sway)+M) with the same
% scenario rows (results/shield/s4_rows.mat), the same seeds (rng(1000 r + 10 c), r and c
% the indices of run_shield_v2.m) and 200 trajectories per row. Every fallback step is
% logged (state estimate, true state, true current, whether the fallback was already
% active) and checked against the v1 sway table (table_sway.mat, |v| <= 0.05) and, if it
% exists, the v2 sway table with velocity bins (table_sway_v2.mat).
% The control law is unchanged (the tables only score the fallback steps), so outages
% must reproduce s5_ablation.csv.
% Outputs (results/shield/): sway_v2_eval_<tag>.csv, sway_v2_fblog_<tag>.csv|mat,
% sway_v2_invocation_pctl_<tag>.csv, sway_v2_noncert_reasons_<tag>.csv
if nargin < 1, tag = 'run'; end
P = setup_paths();
L = load(fullfile(P.results,'phase2','actor_res_32.mat')); net = L.net;
LT = load_shield_tables(P);
f2 = fullfile(P.results,'shield','table_sway_v2.mat');
LTv2 = []; if exist(f2,'file'), LTv2 = load_shield_table_sway_v2(P, f2); end
fprintf('[sway_v2_eval] v2 table loaded: %d\n', ~isempty(LTv2));
S4 = load(fullfile(P.results,'shield','s4_rows.mat')); rows = S4.rows; rowName = S4.rowName; decl = S4.decl;
ctrlsAll = {'classical','NN','NN+clip','NN+M(sway)','L(old)','L(sway)','L(sway)+M','O(old)','O(sway)'};
rSel = 2:6; cSel = [4 6 7];
jobs = {}; for r = rSel, for c = cSel, jobs{end+1} = [r c]; end, end %#ok<AGROW>
get_pool(10);
pctRunOnAll(sprintf('addpath(''%s''); addpath(genpath(''%s''));', P.code, P.cora));
res = cell(numel(jobs),1); t0 = tic;
parfor jj = 1:numel(jobs)
    r = jobs{jj}(1); c = jobs{jj}(2);
    rng(1000*r + 10*c + 0);                       % seed of run_shield_v2.m (j = 0)
    res{jj} = aux_run(P, net, LT, LTv2, decl, rows{r}, ctrlsAll{c});
end
wall = toc(t0);
outdir = fullfile(P.results,'shield');
% ---------------- aggregate ----------------
out = {}; LOG = []; H = 4; dt = P.dt_ctrl;
for jj = 1:numel(jobs)
    r = jobs{jj}(1); c = jobs{jj}(2); R = res{jj};
    oc = R.outage; n = numel(oc); k = sum(oc); [p, lo, hi] = wilson(k, n);
    Lg = R.fbLog; nL = size(Lg,1);
    LOG = [LOG; [repmat([r c], nL, 1), Lg]]; %#ok<AGROW>
    on = Lg(:,3) == 0;                              % onset: fallback not active at the previous step
    c1 = Lg(:,17) == 1; c2 = Lg(:,18) == 1; inb = Lg(:,16) <= decl.w + 1e-9;
    [cov1, cov1v] = aux_cover(Lg, 17, H, dt, decl.w); [cov2, cov2v] = aux_cover(Lg, 18, H, dt, decl.w);
    tl = Lg(:,19);
    out(end+1,:) = {rowName{r}, ctrlsAll{c}, n, k, p, lo, hi, sum(R.nInterv)/sum(R.nSteps), ...
        sum(R.nUnnec)/max(sum(R.nInterv),1), nL, nnz(on), mean(Lg(:,3)), mean(inb), ...
        mean(c1(on)), mean(c2(on)), mean(c1), mean(c2), mean(cov1), mean(cov2), mean(cov1v), mean(cov2v), ...
        mean(R.fbCert, 'omitnan'), mean(R.tDec), prctile(R.tDec, 95), max(R.tDec), ...
        mean(tl, 'omitnan'), prctile(tl, 95), max([tl; 0])}; %#ok<AGROW>
end
T = cell2table(out, 'VariableNames', {'row','controller','n','n_outage','outage_rate','ci_lo','ci_hi', ...
    'intervention_rate','unnecessary_share','n_fallback_steps','n_invocations','share_steps_already_active', ...
    'share_steps_current_in_bound','inv_cert_v1','inv_cert_v2','step_cert_v1','step_cert_v2', ...
    'time_cov_v1','time_cov_v2','time_cov_inbound_v1','time_cov_inbound_v2','legacy_fbCert_v1_omitnan', ...
    'decision_mean_s','decision_p95_s','decision_max_s','fb_lookup_v2_mean_s','fb_lookup_v2_p95_s','fb_lookup_v2_max_s'});
writetable(T, fullfile(outdir, ['sway_v2_eval_' tag '.csv']));
cols = {'row_idx','ctrl_idx','traj','t','was_active','dh','eh','uh','vh','rh','phih','d','phi','e','u','v','r', ...
    'w_true','cert_v1','cert_v2','t_lookup_v2','wi','acc_nn','monitor_flag','pad'};
TL = array2table(LOG, 'VariableNames', cols);
writetable(TL, fullfile(outdir, ['sway_v2_fblog_' tag '.csv']));
save(fullfile(outdir, ['sway_v2_fblog_' tag '.mat']), 'TL', 'T', 'wall', 'jobs', 'rowName', 'ctrlsAll');
% ---------------- invocation-state percentiles ----------------
pc = [0 1 5 25 50 75 95 99 100];
vars = {'uh','vh','rh','u','v','r','eh','e','phih','phi','d','w_true'};
scl = [1 1 1 1 1 1 180/pi 180/pi 180/pi 180/pi 1 1];
po = {};
sets = {'L(sway) onsets', TL.ctrl_idx==6 & TL.was_active==0; 'L(sway) all fallback steps', TL.ctrl_idx==6; ...
        'L(sway)+M onsets', TL.ctrl_idx==7 & TL.was_active==0; 'L(sway)+M all fallback steps', TL.ctrl_idx==7; ...
        'NN+M(sway) onsets', TL.ctrl_idx==4 & TL.was_active==0; 'NN+M(sway) all fallback steps', TL.ctrl_idx==4};
for s = 1:size(sets,1)
    m = sets{s,2};
    for v = 1:numel(vars)
        x = TL.(vars{v})(m)*scl(v);
        po(end+1,:) = [sets(s,1), vars(v), {nnz(m)}, num2cell(prctile(x, pc)), {prctile(abs(x), 95)}]; %#ok<AGROW>
    end
end
TP = cell2table(po, 'VariableNames', [{'set','var','n'}, arrayfun(@(q) sprintf('p%g', q), pc, 'uni', 0), {'abs_p95'}]);
writetable(TP, fullfile(outdir, ['sway_v2_invocation_pctl_' tag '.csv']));
% ---------------- why a fallback step is not certified ----------------
ro = {};
for s = 1:size(sets,1)
    m = find(sets{s,2});
    rv1 = aux_reason(P, decl, TL(m,:), LT.sway, 'v1');
    ro(end+1,:) = [sets(s,1), {'v1'}, {numel(m)}, num2cell(histcounts(rv1, 0.5:1:5.5)/max(numel(m),1))]; %#ok<AGROW>
    if ~isempty(LTv2)
        rv2 = aux_reason(P, decl, TL(m,:), LTv2, 'v2');
        ro(end+1,:) = [sets(s,1), {'v2'}, {numel(m)}, num2cell(histcounts(rv2, 0.5:1:5.5)/max(numel(m),1))]; %#ok<AGROW>
    end
end
TR = cell2table(ro, 'VariableNames', {'set','table','n','certified','outside_d_phi_e_range','outside_v_range', ...
    'outside_u_r_range','inside_but_uncertified_tile'});
writetable(TR, fullfile(outdir, ['sway_v2_noncert_reasons_' tag '.csv']));
disp(T(:, [1:7 11 14:21])); disp(TR);
fprintf('[sway_v2_eval] wall %.0f s\n', wall);
end

% ======================================================================
function R = aux_run(P, net, LT, LTv2, decl, G, name)
scen = scen_generic(P, G); wi = G.wi;
chk = 'none'; if startsWith(name,'L('), chk = 'lookup'; end
mon = contains(name,'M');
S = ShieldCtrl(P, net, chk, 'sway', mon, wi, decl, LT, struct(), scen);
S.logFb = true; S.LTv2 = LTv2;
o = sim_closed_loop(P, scen, @(z,k,x,ex) S.step(z, k, x, ex), struct('passExtra', true));
R.outage = o.outage; R.nInterv = S.nInterv; R.nSteps = S.nSteps*ones(1,numel(wi)); R.nUnnec = S.nUnnec;
R.tDec = S.tDec; R.fbCert = S.fbCert; R.fbLog = S.fbLog;
end

function [cov, covIn] = aux_cover(Lg, col, H, dt, wDecl)
% A fallback step is covered by a certificate if, in the same continuous fallback
% episode, a step at most H - dt earlier (or the step itself) started inside a
% certified tile: the H = 4 s certificate of that start covers the next H seconds of
% fallback operation. covIn additionally requires the true current at the step to be
% within the declared bound (the certificate's assumption).
n = size(Lg,1); cov = false(n,1); covIn = false(n,1);
if n == 0, return; end
for i = unique(Lg(:,1))'
    m = find(Lg(:,1) == i); [~, o] = sort(Lg(m,2)); m = m(o);
    lastCert = -inf;
    for q = 1:numel(m)
        j = m(q);
        if Lg(j,3) == 0, lastCert = -inf; end           % new episode
        if Lg(j,col) == 1, lastCert = Lg(j,2); end
        cov(j) = Lg(j,2) - lastCert <= H - dt + 1e-9;
        covIn(j) = cov(j) && Lg(j,16) <= wDecl + 1e-9;
    end
end
end

function rs = aux_reason(P, decl, TL, TB, ver)
% 1 certified, 2 estimate box outside the tiled d/phi/e range, 3 outside the v range,
% 4 outside the u/r range, 5 inside the tiled range but overlapping an uncertified tile
n = height(TL); rs = zeros(n,1); loc = decl.loc;
for j = 1:n
    wi = TL.wi(j); Tb = TB{wi};
    d = TL.dh(j); ab = asin(min(loc/max(d - loc, 0.3), 1));
    xh = [TL.dh(j); TL.phih(j); TL.eh(j); TL.uh(j); TL.vh(j); TL.rh(j)];
    mg = [loc; ab; P.eps_psi + ab; P.eps_u; P.eps_v; P.eps_r];
    box = [xh - mg, xh + mg];
    if isempty(Tb), rs(j) = 2; continue; end
    E = Tb.E;
    if strcmp(ver,'v1'), ed = {E.d, E.p, E.e, E.u, [-0.05 0.05], E.r}; else, ed = {E.d, E.p, E.e, E.u, E.v, E.r}; end
    out = false(1,6);
    for k = 1:6, out(k) = box(k,1) < ed{k}(1) || box(k,2) > ed{k}(end); end
    if any(out(1:3)), rs(j) = 2;
    elseif out(5), rs(j) = 3;
    elseif any(out([4 6])), rs(j) = 4;
    else
        if strcmp(ver,'v1'), ok = shield_lookup(TB, wi, box([1 2 3 4 6],:)); else, ok = shield_lookup_v2(TB, wi, box); end
        rs(j) = 5 - 4*ok;
    end
end
end

function [p, lo, hi] = wilson(k, n)
z = 1.96; p = k/n; den = 1 + z^2/n; c = (p + z^2/(2*n))/den;
h = z*sqrt(p*(1-p)/n + z^2/(4*n^2))/den; lo = max(0, c-h); hi = min(1, c+h);
end
