function S = slowcur_sideways(P, ctrl, c, nR)
% SLOWCUR_SIDEWAYS  Structured sideways adversary of falsify_sideways.m restricted to the
% scenarios admissible in every regime of campaign E: a CONSTANT world-frame current of
% magnitude exactly w0 (on the disk, rate 0), perpendicular to the line of sight at t = 0
% on either side, rotated by delta in [-30, 30] deg. Other bounds at their worst corners as
% in falsify_sideways (x0 at box corners, localisation bias perpendicular to the LOS,
% heading and DVL/gyro biases at +-bound, true c = 1.1 c_nom). Simulation, not verification.
%   S.min_rho, S.n_viol, S.n_scen, S.w_tOut, S.w_prov, S.nf_min_rho (noise-free part)
if nargin < 4, nR = 3000; end
lo = c.lo; hi = c.hi; mid = (lo+hi)/2;
[dI, pI, eI, uI, vI] = ndgrid([1 2], [1 2], [1 2 3], [1 2], [1 2]);
X0 = zeros(6, numel(dI));
dv = [lo(1) hi(1)]; pv = [lo(2) hi(2)]; ev = [lo(3) mid(3) hi(3)]; uv = [lo(4) hi(4)];
X0(1,:) = dv(dI(:)); X0(2,:) = pv(pI(:)); X0(3,:) = ev(eI(:)); X0(4,:) = uv(uI(:));
vs = [-1 1]; X0(5,:) = vs(vI(:))*hi(5); X0(6,:) = vs(vI(:))*hi(6);
side = [-1 1]; dl = deg2rad([-30 -15 0 15 30]); nb = [-1 0 1];
[sI, dlI, xI, lbI, hbI, vbI] = ndgrid(1:2, 1:5, 1:size(X0,2), 1:3, 1:3, 1:3);
G.side = side(sI(:))'; G.delta = dl(dlI(:)); G.x0 = X0(:, xI(:)); G.lb = nb(lbI(:));
G.lang = zeros(1,numel(sI)); G.hb = nb(hbI(:)); G.vb = repmat(nb(vbI(:)), 3, 1);
G.side = G.side(:)';
Q.side = 2*(rand(1,nR) > 0.5) - 1; Q.delta = deg2rad(30)*(2*rand(1,nR)-1);
Q.x0 = lo + (hi-lo).*rand(6,nR); sn = rand(6,nR) < 0.5; B = lo + (hi-lo).*round(rand(6,nR));
Q.x0(sn) = B(sn);
Q.lb = snapr(2*rand(1,nR)-1); Q.lang = deg2rad(60)*(2*rand(1,nR)-1);
Q.hb = snapr(2*rand(1,nR)-1); Q.vb = snapr(2*rand(3,nR)-1);
A = catp(G, Q);
[rho, prov, tOut] = runbatch(P, c, ctrl, A);
for rr = 1:2
    [~, ord] = sort(rho); E = subp(A, repelem(ord(1:20), 50)); nE = numel(E.side);
    E.delta = min(max(E.delta + deg2rad(5)*randn(1,nE), -deg2rad(30)), deg2rad(30));
    E.x0 = min(max(E.x0 + 0.1*(hi-lo).*randn(6,nE), lo), hi);
    E.lb = min(max(E.lb + 0.2*randn(1,nE), -1), 1); E.lang = min(max(E.lang + deg2rad(10)*randn(1,nE), -deg2rad(60)), deg2rad(60));
    E.hb = min(max(E.hb + 0.2*randn(1,nE), -1), 1); E.vb = min(max(E.vb + 0.2*randn(3,nE), -1), 1);
    [rE, pE, tE] = runbatch(P, c, ctrl, E);
    A = catp(A, E); rho = [rho rE]; prov = [prov pE]; tOut = [tOut tE]; %#ok<AGROW>
end
nf = G.lb == 0 & G.hb == 0 & G.vb(1,:) == 0;
bad = rho < -0.01;
[S.min_rho, b] = min(rho); S.n_viol = nnz(bad); S.n_scen = numel(rho);
S.w_prov = prov(b); S.w_tOut = tOut(b); S.found = any(bad);
S.nf_min_rho = min(rho(find(nf)));   %#ok<FNDSB>  (grid part only)
end

function [rho, prov, tOut] = runbatch(P, c, ctrl, S)
n = numel(S.side); rho = inf(1,n); prov = zeros(1,n); tOut = nan(1,n); bs = 6000;
for a = 1:bs:n
    j = a:min(n, a+bs-1); s = subp(S, j); N = numel(j);
    scen.x0 = s.x0; scen.c = 1.1*c.c*ones(1,N); scen.chat = c.c*ones(1,N);
    Wx = c.w*sin(s.delta); Wy = c.w*s.side.*cos(s.delta);          % constant, world frame
    scen.wfun = @(t,x) [Wx.*cos(x(2,:)) + Wy.*sin(x(2,:)); -Wx.*sin(x(2,:)) + Wy.*cos(x(2,:))];
    scen.noise = @(k,x) noisef(x, s, c, N);
    o = sim_closed_loop(P, scen, ctrl, struct('T', c.T));
    rho(j) = o.rho; prov(j) = o.firstProv; tOut(j) = o.firstOut;
end
end

function n = noisef(x, s, c, N)
a = x(2,:) + pi/2 + s.lang;
n.dpos = [c.loc*s.lb.*cos(a); c.loc*s.lb.*sin(a)];
n.dpsi = c.epsPsi*s.hb;
n.du = c.epsVel(1)*s.vb(1,:); n.dv = c.epsVel(2)*s.vb(2,:); n.dr = c.epsVel(3)*s.vb(3,:);
n.dz = zeros(1,N);
end
function v = snapr(v), sn = rand(size(v)) < 0.5; v(sn) = sign(v(sn)); v(v == 0) = 1; end
function s = subp(S, j), f = fieldnames(S); s = struct(); for k = 1:numel(f), s.(f{k}) = S.(f{k})(:, j); end, end
function s = catp(A, B), f = fieldnames(A); s = struct(); for k = 1:numel(f), s.(f{k}) = [A.(f{k}), B.(f{k})]; end, end
