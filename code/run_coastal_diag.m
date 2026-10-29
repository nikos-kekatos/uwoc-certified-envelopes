function run_coastal_diag()
% RUN_COASTAL_DIAG  Task 2 step 3 (simulation only, no reachability): why the coastal
% EVV / false-assurance area of the classical teacher (9.18 / 1.72 m^2) differs from
% res_32 (10.21 / 2.99 m^2) at loc 0.1 m, |w| <= 0.025 m/s.
% Input: results/coastal_diag/differing_tiles.csv (code/coastal_join.py).
% For each differing tile and each controller (teacher_net, res_32), with the empirical
% protocol of the CCV runs (200 MC runs + cross-entropy falsifier, 8 x 120, no CORA):
%   (a) the controller's own original seed and the other controller's original seed
%       (seeds of run_cells: 1000 + index in the run's cell list);
%   (b) three new seeds (identical for both controllers);
%   (c) a 5,000-run Monte Carlo (same seed for both) for the outage frequency.
% Witness cross-check: every falsifier witness found for one controller is replayed on
% the other (same scenario), and along the res_32 witness trajectory both laws are
% evaluated on the same state estimates (action difference).
% Outputs: results/coastal_diag/seed_reruns.csv, mc5000.csv, witness_cross.csv
P = setup_paths();
rng(0, 'threefry');   % the generator of the pool workers that ran the CCV tilings; rng(seed) keeps the type,
                      % so the original seeds reproduce the original MC / falsifier draws exactly
L = load(fullfile(P.results,'phase2','actor_res_32.mat')); netR = L.net; netT = teacher_net(P, 2);
MR = load(fullfile(P.results,'ccv','ccv_2d_res_32.mat'));
MT = load(fullfile(P.results,'ccv','ccv_2d_loc01_empirical_teacher.mat'));
D = readtable(fullfile(P.results,'coastal_diag','differing_tiles.csv'), 'TextType', 'string');
outdir = fullfile(P.results,'coastal_diag');
eo = default_eo(); eo.nMC = P.ccv.nMC; eo.maxDepth = 1; eo.checkCertified = false;
eo.estFals = false; eo.precheck = true; eo.fo.iters = 8; eo.noReach = true;
wiT = cellfun(@(c) c.wi, MT.cells); nClearT = nnz(wiT == 1);
nt = height(D); tiles = cell(nt,1); seedR = zeros(nt,1); seedT = zeros(nt,1);
for q = 1:nt
    iR = find(cellfun(@(c) c.wi == 2 && abs(c.loc - 0.1) < 1e-9 && abs(mean([c.lo(1) c.hi(1)]) - D.d0_m(q)) < 1e-9 && ...
        abs(rad2deg(mean([c.lo(2) c.hi(2)])) - D.phi0_deg(q)) < 1e-6, MR.cells));
    iT = find(cellfun(@(c) c.wi == 2 && abs(mean([c.lo(1) c.hi(1)]) - D.d0_m(q)) < 1e-9 && ...
        abs(rad2deg(mean([c.lo(2) c.hi(2)])) - D.phi0_deg(q)) < 1e-6, MT.cells));
    assert(isscalar(iR) && isscalar(iT));
    tiles{q} = MR.cells{iR}; seedR(q) = 1000 + iR; seedT(q) = 1000 + iT - nClearT;
end
nets = {netT, netR}; names = {'teacher','res_32'};
jobs = {};
for q = 1:nt
    for a = 1:2
        sl = {'orig_teacher_seed', seedT(q); 'orig_res32_seed', seedR(q); ...
              'new_seed_1', 7100 + q; 'new_seed_2', 7200 + q; 'new_seed_3', 7300 + q};
        for s = 1:size(sl,1), jobs{end+1} = {q, a, sl{s,1}, sl{s,2}}; end %#ok<AGROW>
    end
end
% serial (light; runs next to the Task 1 pool)
res = cell(numel(jobs),1);
for jj = 1:numel(jobs)
    J = jobs{jj}; eoi = eo; eoi.seed = J{4};
    R = eval_cell(P, nets{J{2}}, tiles{J{1}}, eoi);
    % the falsifier witness theta (same seed as inside eval_cell)
    th = []; if R.fals_found || ~isnan(R.fals_rho)
        rng(eoi.seed + 1); [ctrl, ~] = make_ctrl(nets{J{2}});
        F = falsify_cell(P, ctrl, tiles{J{1}}, eoi.fo); th = F.theta;
    end
    res{jj} = struct('R', R, 'theta', th);
end
rows = {};
for jj = 1:numel(jobs)
    J = jobs{jj}; R = res{jj}.R; q = J{1};
    rows(end+1,:) = {D.d0_m(q), D.phi0_deg(q), names{J{2}}, J{3}, J{4}, R.mc_outage_rate, R.mc_min_rho, ...
        R.mc_prov_Tx + 0, R.mc_prov_Rx + 0, R.mc_prov_P + 0, R.fals_found, R.fals_rho, R.verdict, R.prov, ...
        R.mc_outage_rate == 0, R.mc_outage_rate == 0 && R.verdict == "Falsified"}; %#ok<AGROW>
end
TS = cell2table(rows, 'VariableNames', {'d0_m','phi0_deg','controller','seed_kind','seed','mc_outage_rate', ...
    'mc_min_rho','mc_n_Tx','mc_n_Rx','mc_n_P','fals_found','fals_min_rho','verdict','provenance','in_EVV','EVV_falsified'});
writetable(TS, fullfile(outdir,'seed_reruns.csv'));
% ---------------- (c) 5,000-run Monte Carlo ----------------
r5 = {};
for q = 1:nt
    for a = 1:2
        rng(8000 + q); [ctrl, ~] = make_ctrl(nets{a}); c = tiles{q};
        o = sim_closed_loop(P, mc_scen(P, c, 5000), ctrl, struct('T', c.T, 'Te', c.Te));
        k = sum(o.rho < -eo.tol);
        r5(end+1,:) = {D.d0_m(q), D.phi0_deg(q), names{a}, 5000, k, k/5000, min(o.rho), ...
            sum(o.firstProv(o.rho < -eo.tol) == 1), sum(o.firstProv(o.rho < -eo.tol) == 2), sum(o.firstProv(o.rho < -eo.tol) == 3)}; %#ok<AGROW>
    end
end
T5 = cell2table(r5, 'VariableNames', {'d0_m','phi0_deg','controller','n','n_outage','outage_rate','min_rho','n_Tx','n_Rx','n_P'});
writetable(T5, fullfile(outdir,'mc5000.csv'));
% ---------------- witness cross-check ----------------
wc = {};
for jj = 1:numel(jobs)
    J = jobs{jj}; th = res{jj}.theta; R = res{jj}.R;
    if isempty(th) || ~R.fals_found, continue; end
    c = tiles{J{1}}; other = 3 - J{2};
    rhoOwn = aux_replay(P, nets{J{2}}, c, th); rhoOther = aux_replay(P, nets{other}, c, th);
    [du, dr, satFrac] = aux_actdiff(P, nets{J{2}}, nets{3 - J{2}}, c, th);
    wc(end+1,:) = {D.d0_m(J{1}), D.phi0_deg(J{1}), names{J{2}}, J{3}, rhoOwn, names{other}, rhoOther, ...
        du(1), du(2), dr(1), dr(2), satFrac}; %#ok<AGROW>
end
TW = cell2table(wc, 'VariableNames', {'d0_m','phi0_deg','witness_of','seed_kind','rho_own','replayed_on','rho_other', ...
    'du_c_mean','du_c_max','dr_c_mean','dr_c_max','frac_steps_r_saturated'});
writetable(TW, fullfile(outdir,'witness_cross.csv'));
disp(TS); disp(T5); disp(TW);
end

function rho = aux_replay(P, net, c, th)
scen = aux_theta2scen(P, c, th); [ctrl, ~] = make_ctrl(net);
o = sim_closed_loop(P, scen, ctrl, struct('T', c.T, 'Te', c.Te)); rho = o.rho;
end

function [du, dr, satFrac] = aux_actdiff(P, netA, netB, c, th)
% drive with netA on the witness scenario; at every control step evaluate both laws on
% the same state estimate z (the witness noise is deterministic)
scen = aux_theta2scen(P, c, th); Z = [];
o = sim_closed_loop(P, scen, @(z,k,x) aux_rec(netA, z), struct('T', c.T, 'Te', c.Te, 'keep', true)); %#ok<NASGU>
nS = round(P.dt_ctrl/P.dt_sim); nC = round(c.T/P.dt_ctrl);
for k = 1:nC
    x = o.X(:,:,(k-1)*nS+1); n = scen.noise(k, x);
    d = x(1); phi = x(2); e = x(3); p = [d*cos(phi); d*sin(phi)] + n.dpos;
    phih = atan2(p(2), p(1)); eh = wrapToPi(e + phi - phih + n.dpsi);
    Z(:,k) = [norm(p); eh; x(4)+n.du; x(5)+n.dv; x(6)+n.dr; scen.chat]; %#ok<AGROW>
end
A = nn_forward(netA, Z); B = nn_forward(netB, Z);
du = [mean(abs(A(1,:)-B(1,:))), max(abs(A(1,:)-B(1,:)))];
dr = [mean(abs(A(2,:)-B(2,:))), max(abs(A(2,:)-B(2,:)))];
satFrac = mean(abs(B(2,:)) >= P.rc_max - 1e-9 | abs(A(2,:)) >= P.rc_max - 1e-9);
end

function [tau, iv] = aux_rec(net, z), tau = nn_forward(net, z); iv = false(1, size(z,2)); end

function scen = aux_theta2scen(P, c, TH)
% copy of falsify_cell/theta2scen (planar case)
N = size(TH,2);
scen.x0 = c.lo + (c.hi - c.lo).*TH(1:6,:);
scen.c  = c.c*(1 + c.crel*(2*TH(7,:)-1)); scen.chat = c.c*ones(1,N);
wm = c.w*TH(8,:); wa = 2*pi*TH(9,:); wo = 0.2*(2*TH(10,:)-1);
scen.wfun = @(t,x) aux_polarw([wm.*cos(wa+wo*t); wm.*sin(wa+wo*t)], x);
br = c.loc*TH(11,:); ba = 2*pi*TH(12,:); bo = 0.5*(2*TH(13,:)-1);
hb = c.epsPsi*(2*TH(14,:)-1); Tp = 1 + 39*TH(15,:); ph = 2*pi*TH(16,:);
vb = c.epsVel(:).*(2*TH(17:19,:)-1);
scen.noise = @(k,x) aux_noise(k, x, br, ba, bo, hb, Tp, ph, vb, P);
end

function n = aux_noise(k, x, br, ba, bo, hb, Tp, ph, vb, P)
t = (k-1)*P.dt_ctrl; s = sign(sin(2*pi*t./Tp + ph)); s(s==0) = 1;
ang = x(2,:) + ba + bo*t;
n.dpos = [s.*br.*cos(ang); s.*br.*sin(ang)];
n.dpsi = s.*hb; n.du = s.*vb(1,:); n.dv = s.*vb(2,:); n.dr = s.*vb(3,:); n.dz = 0*s;
end

function w = aux_polarw(W, x)
phi = x(2,:);
w = [W(1,:).*cos(phi) + W(2,:).*sin(phi); -W(1,:).*sin(phi) + W(2,:).*cos(phi)];
end
