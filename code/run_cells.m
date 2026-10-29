function [Rs, T] = run_cells(P, net, cells, eo, nW)
% RUN_CELLS  Evaluate many cells in parallel (parfor) and tabulate.
if nargin < 5, nW = 10; end
% generate CORA derivative files once on the client (avoid races on workers)
c0 = cells{1}; c0.T = P.dt_ctrl; ro = eo.ro; ro.tmax = 60;
reach_cell(P, net, c0, ro);
get_pool(nW);
pctRunOnAll(sprintf('addpath(''%s''); addpath(genpath(''%s''));', P.code, P.cora));
n = numel(cells); Rs = cell(n,1);
parfor i = 1:n
    eoi = eo; eoi.seed = 1000 + i;
    try
        Rs{i} = eval_cell(P, net, cells{i}, eoi);
    catch ME
        Rs{i} = struct('verdict','Inconclusive','prov','','verdict_est','Inconclusive', ...
            'verdict_robust','NotCertified','error',ME.message);
    end
end
T = cells2table(cells, Rs);
end

function T = cells2table(cells, Rs)
n = numel(cells);
water = strings(n,1); d0 = zeros(n,1); phi0 = zeros(n,1); e0 = zeros(n,1); loc = d0; w = d0; crel = d0; epsPsi = d0;
verdict = strings(n,1); prov = verdict; vest = verdict; vrob = verdict; status = verdict;
Mlow = nan(n,1); rt = Mlow; leaves = Mlow; mcr = Mlow; mce = Mlow; mcmin = Mlow; mcMmin = Mlow;
mcTx = Mlow; mcRx = Mlow; mcP = Mlow; ff = false(n,1); frho = Mlow; ft = Mlow; sv = ff; mct = Mlow;
pTx = ff; pRx = ff; pP = ff; tfv = Mlow; mcrob = Mlow;
P = uwoc_params();
for i = 1:n
    c = cells{i}; R = Rs{i};
    water(i) = P.water.name{c.wi}; d0(i) = mean([c.lo(1) c.hi(1)]); phi0(i) = rad2deg(mean([c.lo(2) c.hi(2)]));
    e0(i) = rad2deg(c.hi(3)); loc(i) = c.loc; w(i) = c.w; crel(i) = c.crel; epsPsi(i) = rad2deg(c.epsPsi);
    verdict(i) = R.verdict; prov(i) = R.prov; vest(i) = R.verdict_est; vrob(i) = R.verdict_robust;
    if isfield(R,'reach')
        Mlow(i) = R.reach.Mlow; rt(i) = R.reach.runtime; leaves(i) = R.reach.nLeaves;
        status(i) = strjoin(unique(R.reach.statuses),'|');
        pTx(i) = R.reach.possTx; pRx(i) = R.reach.possRx; pP(i) = R.reach.possP; tfv(i) = R.reach.tFirstViol;
        mcr(i) = R.mc_outage_rate; mce(i) = R.mc_est_viol_rate; mcmin(i) = R.mc_min_rho; mcMmin(i) = R.mc_mean_Mmin;
        mcTx(i) = R.mc_prov_Tx; mcRx(i) = R.mc_prov_Rx; mcP(i) = R.mc_prov_P; mct(i) = R.mc_time; mcrob(i) = R.mc_robust_frac;
        ff(i) = R.fals_found; frho(i) = R.fals_rho; ft(i) = R.fals_time; sv(i) = R.soundness_violation;
    else
        status(i) = "error:" + string(R.error);
    end
end
T = table(water, d0, phi0, e0, loc, w, crel, epsPsi, verdict, prov, vest, vrob, Mlow, rt, leaves, status, ...
    pTx, pRx, pP, tfv, mcr, mce, mcmin, mcMmin, mcrob, mcTx, mcRx, mcP, mct, ff, frho, ft, sv, ...
    'VariableNames', {'water','d0_m','phi0_deg','e0_deg','loc_m','w_mps','c_rel_unc','eps_psi_deg', ...
    'verdict_maint','provenance','verdict_est','verdict_robust','reach_Mlow_dB','reach_time_s','reach_leaves', ...
    'reach_status','reach_possTx','reach_possRx','reach_possP','reach_tFirstViol_s', ...
    'mc_outage_rate','mc_est_viol_rate','mc_min_rho','mc_mean_Mmin_dB','mc_robust_frac','mc_n_Tx','mc_n_Rx','mc_n_P','mc_time_s', ...
    'fals_found','fals_min_rho','fals_time_s','soundness_violation'});
end
