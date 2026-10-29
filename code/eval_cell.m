function R = eval_cell(P, net, cellc, eo)
% EVAL_CELL  Monte Carlo + sound reachability (+ adaptive refinement) +
% falsification for one operating cell. Three verdicts per property:
%   Certified    : reachable-set over-approximation inside ACE_O (sound, conditional
%                  on model and declared bounds)
%   Falsified    : a concrete trajectory inside the declared bounds leaves ACE_O
%                  (found by Monte Carlo or by the adversarial falsifier)
%   Inconclusive : neither
% Provenance: Falsified -> first violated predicate of the concrete witness;
% Inconclusive -> predicates that the over-approximation may violate.
[ctrl, needsPhi] = make_ctrl(net);
if ~isfield(eo,'tol'), eo.tol = 0.01; end
names = {'Tx','Rx','P'};
% ---------------- 0) initial-outage precheck (concrete witness at t = 0) ----
if isfield(eo,'precheck') && eo.precheck
    xc = (cellc.lo + cellc.hi)/2;
    [M0, okTx0, okRx0] = ace_eval(P, xc, cellc.c, 0);
    if ~okTx0 || ~okRx0 || M0 < -eo.tol
        pv = find([~okTx0, ~okRx0, M0 < -eo.tol], 1);
        R = aux_skipped(names{pv}); return;
    end
end
% ---------------- 1) Monte Carlo (sampled; NOT verification) ----------------
rng(eo.seed);
t0 = tic;
o = sim_closed_loop(P, mc_scen(P, cellc, eo.nMC), ctrl, struct('T',cellc.T,'Te',cellc.Te,'passPhiHat',needsPhi));
R.mc_time = toc(t0);
R.mc_outage_rate = mean(o.rho < -eo.tol);
R.mc_est_viol_rate = mean(o.rhoLate < -eo.tol);
R.mc_min_rho = min(o.rho);
R.mc_mean_Mmin = mean(o.Mmin);
R.mc_robust_frac = mean(o.tRobust)/cellc.T;
viol = o.rho < -eo.tol;
R.mc_prov_Tx = sum(o.firstProv(viol)==1); R.mc_prov_Rx = sum(o.firstProv(viol)==2); R.mc_prov_P = sum(o.firstProv(viol)==3);
mcWitness = any(viol);
[~, iw] = min(o.rho); mcProv = o.firstProv(iw);
% ---------------- 2) Reachability --------------------------------------------
depth = eo.maxDepth; if mcWitness, depth = 0; end    % no refinement once falsified
skipW = isfield(eo,'skipReachIfWitness') && eo.skipReachIfWitness && mcWitness;   % verdict is Falsified either way
if (isfield(eo,'noReach') && eo.noReach) || skipW      % empirical-only evaluation (no CORA)
    RR = struct('maint',false,'est',false,'robust',false,'Mlow',nan,'possTx',false,'possRx',false, ...
        'possP',false,'tFirstViol',nan,'runtime',0,'nLeaves',0,'statuses',{{'skipped:empirical-only'}},'provFirst','');
else
    RR = reach_refine(P, net, cellc, eo.ro, depth);
end
R.reach = RR;
% ---------------- 3) Falsification -------------------------------------------
R.fals_found = false; R.fals_rho = nan; R.fals_time = 0; R.fals_prov = 0;
needF = ~RR.maint && ~mcWitness;
checkF = RR.maint && eo.checkCertified;          % sanity check of certified cells
if needF || checkF
    fo = eo.fo; fo.passPhiHat = needsPhi; if checkF, fo.iters = min(fo.iters, 6); end
    rng(eo.seed+1);
    F = falsify_cell(P, ctrl, cellc, fo);
    R.fals_found = F.found; R.fals_rho = F.rho; R.fals_time = F.runtime; R.fals_prov = F.prov;
end
% establishment property (separate witness search only if needed)
R.falsE_found = false;
estWitness = any(o.rhoLate < -eo.tol);
if ~RR.est && ~estWitness && eo.estFals
    fo = eo.fo; fo.objective = 'est'; fo.passPhiHat = needsPhi; rng(eo.seed+2);
    FE = falsify_cell(P, ctrl, cellc, fo);
    R.falsE_found = FE.found; R.fals_time = R.fals_time + FE.runtime;
end
% ---------------- verdicts ----------------------------------------------------
R.soundness_violation = RR.maint && (mcWitness || R.fals_found);
if RR.maint
    R.verdict = 'Certified'; R.prov = '';
elseif mcWitness
    R.verdict = 'Falsified'; R.prov = names{mcProv};
elseif R.fals_found
    R.verdict = 'Falsified'; R.prov = names{R.fals_prov};
elseif isfield(eo,'noReach') && eo.noReach
    R.verdict = 'NotFalsified(empirical)'; R.prov = '';
else
    R.verdict = 'Inconclusive';
    R.prov = strjoin(names([RR.possTx RR.possRx RR.possP]), '+');
end
if RR.est, R.verdict_est = 'Certified';
elseif estWitness || R.falsE_found, R.verdict_est = 'Falsified';
else, R.verdict_est = 'Inconclusive'; end
R.verdict_robust = ternary(RR.robust, 'Certified', 'NotCertified');
end
function v = ternary(c,a,b), if c, v = a; else, v = b; end, end
function R = aux_skipped(pv)
R.verdict = 'Falsified'; R.prov = pv; R.verdict_est = 'Inconclusive'; R.verdict_robust = 'NotCertified';
R.mc_time = 0; R.mc_outage_rate = 1; R.mc_est_viol_rate = nan; R.mc_min_rho = nan; R.mc_mean_Mmin = nan;
R.mc_robust_frac = nan; R.mc_prov_Tx = nan; R.mc_prov_Rx = nan; R.mc_prov_P = nan;
R.reach = struct('maint',false,'est',false,'robust',false,'Mlow',nan,'possTx',false,'possRx',false, ...
    'possP',false,'tFirstViol',0,'runtime',0,'nLeaves',0,'statuses',{{'skipped:initial-outage'}});
R.fals_found = false; R.fals_rho = nan; R.fals_time = 0; R.fals_prov = 0; R.falsE_found = false;
R.soundness_violation = false;
end
