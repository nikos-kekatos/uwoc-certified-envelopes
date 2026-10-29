% RUN_WITNESS_POWER  A Tx-first witness marks loss of the
% specified tracking envelope; does it also fail the physical criteria (Rx FOV, power/BER)
% within the horizon? Re-finds each hidden-failure witness and re-simulates it, recording
% which predicates are violated at any time in [0, T]. Sets:
%   A  27 first-pass hidden-failure cells (Falsified, MC outage 0) of the operating map
%   B  the a2 stronger-falsifier cell (clear, 3 m, 0.75 m, 0.05 m/s)
%   C  3 sideways-adversary witnesses (results/diag70/sideways_cells.csv, found_any == 1)
%   D  constant-current witness, cell 95 under R0 (campaign E)
% Output: results/witness_power/witness_power.csv (+ .mat)
P = setup_paths(); L = load(fullfile(P.results,'phase2','actor_res_32.mat')); net = L.net; ctrl = make_ctrl(net);
M = load(fullfile(P.results,'opmap','opmap_res_32.mat'));
outdir = fullfile(P.results,'witness_power'); if ~exist(outdir,'dir'), mkdir(outdir); end
rows = {}; names = {'Tx','Rx','P'};
simw = @(c, scen) sim_closed_loop(P, scen, ctrl, struct('T', c.T, 'Te', c.Te));
% ---- A: first-pass hidden-failure cells
idxA = find(M.T.verdict_maint == "Falsified" & M.T.mc_outage_rate == 0);
fprintf('Set A: %d cells\n', numel(idxA));
fo = default_eo().fo; fo2 = struct('pop',200,'iters',25,'elite',20,'tol',0.01);
for i = idxA'
    c = M.cells{i}; rng(1000 + i); F = falsify_cell(P, ctrl, c, fo);
    if ~F.found, rng(5000 + i); F = falsify_cell(P, ctrl, c, fo2); end
    if F.found, o = simw(c, theta2scen_w(P, c, F.theta)); else, o = struct('violTx',NaN,'violRx',NaN,'violP',NaN,'Mmin',NaN,'firstOut',NaN,'rho',NaN); end
    rows = addrow(rows, 'A_firstpass', i, c, M, o, F);
    fprintf('A cell %3d %-8s d0=%g loc=%g w=%g: found %d prov %s violTx %d violRx %d violP %d Mmin %.2f\n', i, M.T.water(i), M.T.d0_m(i), c.loc, c.w, F.found, string(F.prov), o.violTx, o.violRx, o.violP, o.Mmin);
end
% ---- B: a2 stronger-falsifier cell
iB = find(M.T.water == "clear" & abs(M.T.d0_m-3)<1e-9 & abs(M.T.loc_m-0.75)<1e-9 & abs(M.T.w_mps-0.05)<1e-9);
if ~isempty(iB)
    c = M.cells{iB}; F = struct('found',false);
    for s = 1:4, rng(5000 + iB + 100*(s-1)); F = falsify_cell(P, ctrl, c, fo2); if F.found, break; end; end
    if F.found, o = simw(c, theta2scen_w(P, c, F.theta)); else, o = struct('violTx',NaN,'violRx',NaN,'violP',NaN,'Mmin',NaN,'firstOut',NaN,'rho',NaN); end
    rows = addrow(rows, 'B_a2', iB, c, M, o, F);
end
% ---- C: sideways witnesses (reconstruction as in replay_sideways_witness.m)
S = readtable(fullfile(P.results,'diag70','sideways_cells.csv'), 'TextType','string'); S = S(S.found_any == 1, :);
for q = 1:height(S)
    c = M.cells{S.cell(q)}; x0 = eval(S.w_x0(q))'; vb = eval(S.w_vb(q))';
    dl = deg2rad(S.w_delta_deg(q)); sd = S.w_side(q); md = S.w_mode(q); lb = S.w_lb(q); la = deg2rad(S.w_lang_deg(q)); hb = S.w_hb(q);
    x0 = min(max(x0, c.lo), c.hi);
    scen = struct('x0', x0, 'c', 1.1*c.c, 'chat', c.c);
    if md == "track", scen.wfun = @(t,x) [c.w*sin(dl); c.w*sd*cos(dl)];
    else, Wx = c.w*sin(dl); Wy = c.w*sd*cos(dl); scen.wfun = @(t,x) [Wx*cos(x(2)) + Wy*sin(x(2)); -Wx*sin(x(2)) + Wy*cos(x(2))]; end
    scen.noise = @(k,x) struct('dpos', c.loc*lb*[cos(x(2)+pi/2+la); sin(x(2)+pi/2+la)], 'dpsi', c.epsPsi*hb, 'du', c.epsVel(1)*vb(1), 'dv', c.epsVel(2)*vb(2), 'dr', c.epsVel(3)*vb(3), 'dz', 0);
    o = simw(c, scen); F = struct('found', true, 'rho', o.rho, 'prov', o.firstProv);
    rows = addrow(rows, 'C_sideways', S.cell(q), c, M, o, F);
end
% ---- D: constant-current witness, cell 95 under R0
TR = readtable(fullfile(P.results,'slowcur','slowcur_R0.csv'), 'TextType','string');
q = find(TR.cell == 95, 1);
if ~isempty(q)
    c = M.cells{95}; c.curModel = 'rate'; c.rho = 0;
    rng(7500 + q); F = falsify_cell(P, ctrl, c, fo2);
    if F.found, o = simw(c, theta2scen_w(P, c, F.theta)); else, o = struct('violTx',NaN,'violRx',NaN,'violP',NaN,'Mmin',NaN,'firstOut',NaN,'rho',NaN); end
    rows = addrow(rows, 'D_slowcur_R0', 95, c, M, o, F);
end
T = cell2table(rows, 'VariableNames', {'set','cell','water','d0_m','loc_m','w_mps','found','fals_rho','first_prov','violTx','violRx','violP','Mmin_dB','firstOut_s','sim_rho'});
writetable(T, fullfile(outdir,'witness_power.csv')); save(fullfile(outdir,'witness_power.mat'), 'T');
f = T(T.found == 1, :);
fprintf('\nWitnesses re-found: %d of %d\n', height(f), height(T));
fprintf('Tx-first: %d, of which also violate P within T: %d, also violate Rx: %d, violate neither (envelope-only): %d\n', ...
    sum(f.first_prov=="Tx"), sum(f.first_prov=="Tx" & f.violP==1), sum(f.first_prov=="Tx" & f.violRx==1), sum(f.first_prov=="Tx" & f.violP==0 & f.violRx==0));
fprintf('Any physical criterion (Rx or P) violated: %d of %d; power violated: %d\n', sum(f.violRx==1 | f.violP==1), height(f), sum(f.violP==1));

function rows = addrow(rows, setname, i, c, M, o, F)
pv = '';
if isfield(F,'prov') && F.prov > 0
    nm = {'Tx','Rx','P'}; pv = nm{F.prov};
end
rows(end+1,:) = {setname, i, M.T.water(i), M.T.d0_m(i), c.loc, c.w, F.found, F.rho, pv, ...
    o.violTx, o.violRx, o.violP, o.Mmin, o.firstOut, o.rho}; %#ok<AGROW>
end
