% FALSIFY_SIDEWAYS  Structured worst-case sideways-current adversary (simulation, not
% verification) on the 70 hero-map cells still Inconclusive after A2 + chaining, and,
% as a soundness check, on the 32 Certified cells. Planar rung, actor res_32.
%
% Declared bounds respected (MODEL.md Sec. 4, mc_scen.m, reach_cell.m):
%   current magnitude exactly w0 (on the disk |w| <= w0; the CORA box [-w,w]^2 is larger);
%   localisation error |dpos| <= loc (disk), heading |dpsi| <= 1 deg, DVL/gyro biases
%   within +-(0.02, 0.02, 0.01); x0 inside the cell box; true c = 1.1 c_nom (c enters only
%   the power predicate, where M decreases monotonically in c, so +10 % is the worst corner).
% Current modes (world frame; LOS at phi = 0 is the +x axis, its perpendicular +-y):
%   const  : constant world-frame current, direction = side * perpendicular rotated by delta;
%   track  : constant polar components (w_r, w_t) = w0 (sin delta, side cos delta), i.e. the
%            current stays perpendicular to the moving LOS. Its world direction rotates at
%            the bearing rate (|phi'| < 0.03 rad/s here), inside the falsifier's rotating
%            family (|rate| <= 0.2 rad/s) and inside the CORA box (any time variation);
%   switch : constant world-frame current that reverses once at ts (magnitude w0). This
%            is admissible for the CORA model (box, arbitrary time variation), not for the
%            "slowly varying" Monte Carlo family; it is reported separately.
% Stage 1: grid. Stage 2: random search in the same structured family. Stage 3: two
% rounds of Gaussian local refinement around the 20 lowest-robustness scenarios.
% Also a noise-free pass (all estimation errors zero) for the drift budget (Check 2).
% Optional workspace variables: fsSubset (indices into the 102-cell list), fsTag.
if ~exist('fsTag','var'), fsTag = ''; end
P = setup_paths(); L = load(fullfile(P.results,'phase2','actor_res_32.mat')); net = L.net;
M = load(fullfile(P.results,'opmap','opmap_res_32.mat'));
A2 = load(fullfile(P.results,'a2','a2_inconclusive.mat'));
sel = find(M.T.verdict_maint == "Inconclusive");
inc = sel(A2.T.final_T20 == "Inconclusive");
cer = [find(M.T.verdict_maint == "Certified"); sel(A2.T.final_T20 == "Certified(pass2)")];
grp = [repmat("inconclusive70", numel(inc), 1); repmat("certified32", numel(cer), 1)];
idx = [inc; cer];
if exist('fsSubset','var'), idx = idx(fsSubset); grp = grp(fsSubset); end
nCell = numel(idx);
ctrl = make_ctrl(net);
outdir = fullfile(P.results,'diag70'); if ~exist(outdir,'dir'), mkdir(outdir); end
nR = 6000;                         % stage-2 random samples per cell
modeNames = ["const","track","switch"];

R = struct([]); t0all = tic;
for ic = 1:nCell
    tc = tic; i = idx(ic); c = M.cells{i};
    rng(9100 + i);
    % ---------- stage 1 grid ----------
    lo = c.lo; hi = c.hi; mid = (lo+hi)/2;
    [dI, pI, eI, uI, vI] = ndgrid([1 2], [1 2], [1 2 3], [1 2], [1 2]);
    X0 = zeros(6, numel(dI));
    dv = [lo(1) hi(1)]; pv = [lo(2) hi(2)]; ev = [lo(3) mid(3) hi(3)]; uv = [lo(4) hi(4)];
    X0(1,:) = dv(dI(:)); X0(2,:) = pv(pI(:)); X0(3,:) = ev(eI(:)); X0(4,:) = uv(uI(:));
    vs = [-1 1]; X0(5,:) = vs(vI(:))*hi(5); X0(6,:) = vs(vI(:))*hi(6);
    modeV = [1 2 3 3 3]; tsV = [inf inf 5 10 15];
    side = [-1 1]; dl = deg2rad([-30 -15 0 15 30]);
    nb = [-1 0 1];
    [mI, sI, dlI, xI, lbI, hbI, vbI] = ndgrid(1:5, 1:2, 1:5, 1:size(X0,2), 1:3, 1:3, 1:3);
    G = struct();
    G.mode = modeV(mI(:)); G.ts = tsV(mI(:)); G.side = side(sI(:)); G.delta = dl(dlI(:));
    G.x0 = X0(:, xI(:)); G.lb = nb(lbI(:)); G.lang = zeros(1,numel(mI)); G.hb = nb(hbI(:));
    G.vb = repmat(nb(vbI(:)), 3, 1);
    % ---------- stage 2 random ----------
    Q = struct();
    Q.mode = randi(3,1,nR); Q.ts = 2 + 16*rand(1,nR); Q.ts(Q.mode ~= 3) = inf;
    Q.side = 2*(rand(1,nR) > 0.5) - 1; Q.delta = deg2rad(30)*(2*rand(1,nR)-1);
    Q.x0 = lo + (hi-lo).*rand(6,nR); sn = rand(6,nR) < 0.5; B = lo + (hi-lo).*round(rand(6,nR));
    Q.x0(sn) = B(sn);
    Q.lb = snapr(2*rand(1,nR)-1); Q.lang = deg2rad(60)*(2*rand(1,nR)-1);
    Q.hb = snapr(2*rand(1,nR)-1); Q.vb = snapr(2*rand(3,nR)-1);
    S = catp(G, Q); nS = numel(S.mode);
    % ---------- noise-free pass (drift budget) ----------
    NF = G; keepNF = G.lb == 0 & G.hb == 0 & G.vb(1,:) == 0;
    NF = subp(NF, keepNF);
    % ---------- simulate ----------
    [rhoS, provS, tOutS, phiMaxS] = runbatch(P, c, ctrl, S, 6000);
    % ---------- stage 3: two rounds of local refinement around the 20 best ----------
    for rr = 1:2
        [~, ord] = sort(rhoS); E = subp(S, repelem(ord(1:20), 100)); nE = numel(E.mode);
        E.delta = min(max(E.delta + deg2rad(5)*randn(1,nE), -deg2rad(30)), deg2rad(30));
        E.x0 = min(max(E.x0 + 0.1*(hi-lo).*randn(6,nE), lo), hi);
        E.lb = min(max(E.lb + 0.2*randn(1,nE), -1), 1); E.lang = min(max(E.lang + deg2rad(10)*randn(1,nE), -deg2rad(60)), deg2rad(60));
        E.hb = min(max(E.hb + 0.2*randn(1,nE), -1), 1); E.vb = min(max(E.vb + 0.2*randn(3,nE), -1), 1);
        sw = E.mode == 3; E.ts(sw) = min(max(E.ts(sw) + 2*randn(1,nnz(sw)), 1), 19);
        [rE, pE, tE, fE] = runbatch(P, c, ctrl, E, 6000);
        S = catp(S, E); rhoS = [rhoS rE]; provS = [provS pE]; tOutS = [tOutS tE]; phiMaxS = [phiMaxS fE]; %#ok<AGROW>
    end
    nS = numel(S.mode);
    [rhoN, provN, tOutN, phiMaxN, rxMinN] = runbatch(P, c, ctrl, NF, 6000);
    bad = rhoS < -0.01;
    r = struct();
    r.cell = i; r.group = grp(ic); r.water = string(M.T.water(i)); r.d0_m = M.T.d0_m(i);
    r.loc_m = M.T.loc_m(i); r.w_mps = M.T.w_mps(i);
    r.n_scen = nS; r.n_viol = nnz(bad);
    for m = 1:3
        r.(sprintf('found_%s', modeNames(m))) = any(bad & S.mode == m);
    end
    r.found_strict = any(bad & S.mode ~= 3);      % const or track only
    r.found_any = any(bad);
    [r.min_rho, b] = min(rhoS);
    % reported witness: earliest violation among const/track witnesses if any, else any
    cand = find(bad & S.mode ~= 3); if isempty(cand), cand = find(bad); end
    if ~isempty(cand), [~, k] = min(tOutS(cand)); b = cand(k); end
    r.w_mode = modeNames(S.mode(b)); r.w_ts = S.ts(b); r.w_side = S.side(b);
    r.w_delta_deg = rad2deg(S.delta(b)); r.w_rho = rhoS(b);
    r.w_prov = provS(b); r.w_tOut = tOutS(b);
    r.w_x0 = mat2str(S.x0(:,b)', 4); r.w_lb = S.lb(b); r.w_lang_deg = rad2deg(S.lang(b));
    r.w_hb = S.hb(b); r.w_vb = mat2str(S.vb(:,b)', 3);
    r.n_viol_Tx = nnz(bad & provS == 1); r.n_viol_Rx = nnz(bad & provS == 2); r.n_viol_P = nnz(bad & provS == 3);
    r.adv_phimax_rad = max(phiMaxS);
    r.nf_phimax_rad = max(phiMaxN); r.nf_rxmin_deg = min(rxMinN);
    r.nf_min_rho = min(rhoN); r.nf_found = any(rhoN < -0.01);
    r.runtime_s = toc(tc);
    if isempty(R), R = r; else, R(end+1) = r; end %#ok<SAGROW>
    fprintf('[fs] %3d/%d cell %3d %-14s %s d0=%g loc=%g w=%g : viol %d/%d (strict %d) rho %.3f prov %d t %.2f | nf phimax %.3f | %.1f s\n', ...
        ic, nCell, i, grp(ic), r.water, r.d0_m, r.loc_m, r.w_mps, r.n_viol, nS, r.found_strict, r.min_rho, r.w_prov, r.w_tOut, r.nf_phimax_rad, r.runtime_s);
end
T = struct2table(R);
T.soundness_violation = T.found_any & T.group == "certified32";
writetable(T, fullfile(outdir, ['sideways_cells' fsTag '.csv']));
wall = toc(t0all);
save(fullfile(outdir, ['sideways' fsTag '.mat']), 'T', 'wall');
fprintf('[fs] done, wall %.0f s. Inconclusive70 falsified: %d (strict %d). Certified32 violations: %d\n', ...
    wall, nnz(T.found_any & T.group=="inconclusive70"), nnz(T.found_strict & T.group=="inconclusive70"), nnz(T.soundness_violation));

% ======================================================================
function [rho, prov, tOut, phiMax, rxMin] = runbatch(P, c, ctrl, S, bs)
n = numel(S.mode); rho = inf(1,n); prov = zeros(1,n); tOut = nan(1,n); phiMax = zeros(1,n); rxMin = inf(1,n);
for a = 1:bs:n
    j = a:min(n, a+bs-1); s = subp(S, j); N = numel(j);
    scen.x0 = s.x0; scen.c = 1.1*c.c*ones(1,N); scen.chat = c.c*ones(1,N);
    scen.wfun = @(t,x) curr(t, x, s, c.w);
    scen.noise = @(k,x) noisef(x, s, c, N);
    o = sim_closed_loop(P, scen, ctrl, struct('T', 20, 'keep', true));
    rho(j) = o.rho; prov(j) = o.firstProv; tOut(j) = o.firstOut;
    ph = abs(squeeze(o.X(2,:,:))); if N == 1, ph = ph(:)'; end
    phiMax(j) = max(ph, [], 2)';
    rxMin(j) = rad2deg(P.FOV_R - phiMax(j));
end
end

function w = curr(t, x, s, w0)
% polar components [w_r; w_t] of the adversarial current at time t
N = numel(s.mode); phi = x(2,:);
sg = ones(1,N); sg(t >= s.ts) = -1;                 % switch mode: reverse at ts
Wx = w0*sin(s.delta).*sg; Wy = w0*s.side.*cos(s.delta).*sg;   % world frame
w = [Wx.*cos(phi) + Wy.*sin(phi); -Wx.*sin(phi) + Wy.*cos(phi)];
tr = s.mode == 2;                                   % LOS-tracking: constant polar comps
w(:,tr) = [w0*sin(s.delta(tr)); w0*s.side(tr).*cos(s.delta(tr))];
end

function n = noisef(x, s, c, N)
phi = x(2,:); a = phi + pi/2 + s.lang;              % "bearing side" = perpendicular to LOS
n.dpos = [c.loc*s.lb.*cos(a); c.loc*s.lb.*sin(a)];
n.dpsi = c.epsPsi*s.hb;
n.du = c.epsVel(1)*s.vb(1,:); n.dv = c.epsVel(2)*s.vb(2,:); n.dr = c.epsVel(3)*s.vb(3,:);
n.dz = zeros(1,N);
end

function v = snapr(v)
sn = rand(size(v)) < 0.5; v(sn) = sign(v(sn)); v(v == 0) = 1;
end

function s = subp(S, j)
f = fieldnames(S); s = struct();
for k = 1:numel(f), s.(f{k}) = S.(f{k})(:, j); end
end

function s = catp(A, B)
f = fieldnames(A); s = struct();
for k = 1:numel(f), s.(f{k}) = [A.(f{k}), B.(f{k})]; end
end
