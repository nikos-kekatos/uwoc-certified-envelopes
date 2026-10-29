% RUN_PHASE6_SHIELD  Table II data (secondary contribution): four controllers under
% out-of-distribution current at 1.0/1.25/1.5/2.0 x the declared bound w = 0.05 m/s.
%   classical : teacher guidance law (communication-aware, v2)
%   NN        : selected actor, unshielded
%   NN+clip   : heuristic geometric clipping (NOT certified)
%   NN+shield : short-horizon CORA check (H = 2 s) with fallback "slow down,
%               turn to receiver"; the shield uses the DECLARED bounds (w = 0.10
%               m/s, loc 0.25 m) even when the true current is larger.
% Scenarios (identical across controllers): clear and coastal water, d0 ~ U[0.3,0.7] x
% aligned power range, |phi0| <= 10 deg, |e0| <= 10 deg, localisation error 0.1 m. Monte Carlo
% simulation: rates are sampled estimates, not guarantees.
P = setup_paths();
if ~exist('actorTag','var'), actorTag = 'res_32'; end
if ~exist('nTraj','var'), nTraj = 60; end
L = load(fullfile(P.results,'phase2',['actor_' actorTag '.mat'])); net = L.net;
fb = fallback_net(P);
outdir = fullfile(P.results,'phase6'); if ~exist(outdir,'dir'), mkdir(outdir); end
factors = [1.0 1.25 1.5 2.0]; wDecl = 0.05; locDecl = 0.1;
dout = arrayfun(@(wi) fzero(@(d) margin_db(P,d,0,0,P.water.c(wi)), [0.3 60]), 1:2);
% shield set-up (CORA system/options built once, copied to workers)
eo = default_eo();
sys = nonlinearSys(['uwoc2d_v2_' P.dampModel], @aug_dyn, 8, 5);
params.tStart = 0; params.tFinal = P.dt_ctrl;
params.R0 = polyZonotope(interval(zeros(8,1), ones(8,1)));
params.U = zonotope(zeros(5,1), diag([wDecl; wDecl; P.qErr(1:3)']));   % poly3 damping model
options = struct('timeStep',0.05,'taylorTerms',8,'zonotopeOrder',50,'alg','lin','tensorOrder',2);
[params, options] = validateOptions(sys, params, options, 'FunctionName', 'reach');
derivatives(sys, options);
for i = 1:(options.taylorTerms+1), options.factor(i) = options.timeStep^i/factorial(i); end
evo = nnHelper.validateNNoptions(struct('nn', struct('poly_method','singh')));
evo.nn.add_approx_error_to_GI = true;
sh = struct('sys',sys,'options',options,'params',params,'evo',evo,'H',2.0,'loc',locDecl, ...
    'w',wDecl,'epsPsi',P.eps_psi,'epsVel',[P.eps_u;P.eps_v;P.eps_r],'crel',P.c_rel_unc);
Sfb = ctrl_sets(fb);
get_pool(10);
pctRunOnAll(sprintf('addpath(''%s''); addpath(genpath(''%s''));', P.code, P.cora));
ctrlNames = {'classical','NN','NN+clip','NN+shield'};
rows = {}; traj = {};
for fi = 1:numel(factors)
    wTrue = factors(fi)*wDecl;
    % one scenario seed per trajectory, shared by all controllers
    for ci = 1:4
        res = cell(nTraj,1);
        parfor j = 1:nTraj
            rng(20000 + j);
            wi = 1 + (j > nTraj/2);                     % first half clear, second coastal
            cfg = struct('c',P.water.c(wi),'d0',0.5*dout(wi),'dhalf',0.2*dout(wi),'e0',deg2rad(10), ...
                'phi0',deg2rad([-10 10]),'loc',locDecl,'w',wTrue);
            s = make_scen(P, 1, cfg);
            shj = sh; shj.c = P.water.c(wi);
            st = struct('tShield',0,'nInt',0);
            switch ci
                case 1, f = @(z,k,x) deal(teacher_policy(P,z), false);
                case 2, f = @(z,k,x) deal(nn_forward(net,z), false);
                case 3, f = @(z,k,x) clipctrl(P, net, z);
                case 4, f = @(z,k,x,ph) shieldctrl(P, net, fb, Sfb, shj, z, ph);
            end
            t0 = tic;
            o = sim_closed_loop(P, s, f, struct('passPhiHat', ci == 4));
            o.wall = toc(t0);
            res{j} = o;
        end
        O = [res{:}];
        rows(end+1,:) = {ctrlNames{ci}, factors(fi), wTrue, mean([O.outage]), mean([O.tOut])/P.T, ...
            mean([O.tRobust])/P.T, 1 - mean([O.tOut])/P.T, mean([O.nInterv])/O(1).nCtrl, ...
            mean([O.effort]), mean([O.Mmin]), median([O.tAlign],'omitnan'), mean(isnan([O.tAlign])), ...
            mean([O.wall])/O(1).nCtrl, mean([O.violTx]), mean([O.violRx]), mean([O.violP])}; %#ok<SAGROW>
        fprintf('%s x%.2f: outage %.3f, interv %.3f, step time %.3fs\n', ctrlNames{ci}, factors(fi), ...
            rows{end,4}, rows{end,8}, rows{end,13});
    end
end
T = cell2table(rows, 'VariableNames', {'controller','w_factor','w_true_mps','outage_rate','outage_time_frac', ...
    'robust_time_frac','link_availability','intervention_rate','effort','mean_min_margin_dB', ...
    'median_time_to_align_s','frac_never_aligned','compute_s_per_step','Tx_rate','Rx_rate','P_rate'});
writetable(T, fullfile(outdir, ['ood_shield_' actorTag '.csv'])); disp(T)

function [tau, iv] = clipctrl(P, net, z)
% heuristic geometric clipping (baseline, NOT certified): speed limit, and when the
% estimated pointing error exceeds Theta_T/2 force no forward thrust and a turn
% towards the receiver.
tau = nn_forward(net, z); t0 = tau;
tau(1) = min(max(tau(1), -P.tau_u_max/2), P.tau_u_max/2);
if abs(z(2)) > P.Theta_T/2
    tau(1) = min(tau(1), 0);
    if sign(tau(2)) == sign(z(2)) || tau(2) == 0, tau(2) = -sign(z(2))*max(abs(tau(2)), 0.5*P.tau_r_max); end
end
iv = any(abs(tau - t0) > 1e-9);
end

function [tau, iv] = shieldctrl(P, net, fb, Sfb, sh, z, phih)
% the shield sees only the estimate (z, phi_hat) and the declared bounds
tau = nn_forward(net, z);
sh.phihat = phih;
ok = shield_check(P, Sfb, z, tau, sh);
iv = ~ok;
if ~ok, tau = nn_forward(fb, z); end
end
