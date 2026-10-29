function F = falsify6_cell(P, V6, net, c3, fo, nMC, mech)
% FALSIFY6_CELL  Monte Carlo + cross-entropy falsification of a cell on the 6-DOF
% Fossen simulation model (rung 3). c3 is a 3-D cell (9-state box + wv, locz,
% alphaR); the 6-DOF model adds dynamic roll/pitch (passive, restoring), sway/heave
% coupling and an initial roll/pitch/rate state inside V6.att0 bounds.
% mech (struct, optional) switches ONE mechanism off for attribution:
%   pitch    : boresight mount offset th0, initial pitch, pitch-estimate noise
%   roll     : initial roll, roll-estimate noise
%   rxtilt   : receiver tilt
%   vcurrent : vertical current
%   depth    : initial depth offset and depth-estimate error
%   coupling : Coriolis/centripetal terms (incl. the Munk moment)
%   buoyancy : net buoyancy W - B (about 1 N for the published BlueROV2 data)
if nargin < 7, mech = struct(); end
if ~isfield(c3,'epsAtt'), c3.epsAtt = [0;0]; end
g = @(f) isfield(mech,f) && mech.(f);
if g('pitch'), c3.lo(9) = 0; c3.hi(9) = 0; V6.att0(2) = 0; c3.epsAtt(2) = 0; end
if g('roll'), V6.att0(1) = 0; c3.epsAtt(1) = 0; end
if g('rxtilt'), c3.alphaR = 0; end
if g('vcurrent'), c3.wv = 0; end
if g('depth'), c3.lo(7) = 0; c3.hi(7) = 0; c3.locz = 0; end
if g('coupling'), V6.noC = true; end
if g('buoyancy'), V6.B = V6.W; end          % neutral buoyancy (the 3-D rung assumes it)
F = struct('found',false,'rho',inf,'prov',0,'mc_rate',nan,'nEval',0,'maxRoll',nan,'maxPitch',nan);
o = sim6dof_closed_loop(P, V6, theta2scen6(P, V6, c3, rand(30, nMC)), net);
F.mc_rate = mean(o.rho < -fo.tol); F.nEval = nMC;
[F.rho, i] = min(o.rho); F.prov = o.firstProv(i); F.maxRoll = max(o.maxRoll); F.maxPitch = max(o.maxPitch);
if F.rho < -fo.tol, F.found = true; return; end
np = 30; mu = 0.5*ones(np,1); sd = 0.35*ones(np,1);
for it = 1:fo.iters
    TH = min(max(mu + sd.*randn(np, fo.pop), 0), 1);
    snap = rand(np, fo.pop) < 0.25; TH(snap) = round(TH(snap));
    o = sim6dof_closed_loop(P, V6, theta2scen6(P, V6, c3, TH), net);
    F.nEval = F.nEval + fo.pop;
    [rs, ord] = sort(o.rho);
    if rs(1) < F.rho, F.rho = rs(1); F.prov = o.firstProv(ord(1)); end
    if F.rho < -fo.tol, F.found = true; return; end
    el = TH(:, ord(1:fo.elite)); mu = mean(el,2); sd = max(std(el,0,2), 0.03);
end
end

function scen = theta2scen6(P, V6, c, TH)
N = size(TH,2);
x9 = c.lo + (c.hi - c.lo).*TH(1:9,:);              % d phi e u v r z wz th0
d = x9(1,:); ph = x9(2,:); e = x9(3,:);
psi = wrapToPi(e + ph + pi);
roll0 = V6.att0(1)*(2*TH(23,:)-1); p0 = V6.attRate*(2*TH(24,:)-1); q0 = V6.attRate*(2*TH(25,:)-1);
pitch0 = V6.att0(2)*(2*TH(28,:)-1);
eta0 = [d.*cos(ph); d.*sin(ph); x9(7,:); roll0; pitch0; psi];
scen.mount = x9(9,:);                 % static boresight pitch offset (= th0 of the 3-D rung)
nu0  = [x9(4,:); x9(5,:); x9(8,:); p0; q0; x9(6,:)];
scen.x0 = [eta0; nu0];
scen.c = c.c*(1 + c.crel*(2*TH(10,:)-1)); scen.chat = c.c*ones(1,N);
wm = c.w*TH(11,:); wa = 2*pi*TH(12,:); wo = 0.2*(2*TH(13,:)-1);
wv = c.wv*(2*TH(14,:)-1);
scen.Vc = @(t) [wm.*cos(wa+wo*t); wm.*sin(wa+wo*t); wv];
br = c.loc*TH(15,:); ba = 2*pi*TH(16,:); hb = c.epsPsi*(2*TH(17,:)-1);
Tp = 1 + 39*TH(18,:); phs = 2*pi*TH(19,:);
vb = c.epsVel(:).*(2*TH(20:22,:)-1);
zb = c.locz*(2*TH(26,:)-1);
scen.alphaR = [c.alphaR*(2*TH(27,:)-1); zeros(1,N)];
da = c.epsAtt(:).*(2*TH(29:30,:)-1);
scen.noise = @(k) noisefun(k, br, ba, hb, Tp, phs, vb, zb, da, P, scen.x0);
end

function n = noisefun(k, br, ba, hb, Tp, phs, vb, zb, da, P, x0)
t = (k-1)*P.dt_ctrl; s = sign(sin(2*pi*t./Tp + phs)); s(s==0) = 1;
ang = atan2(x0(2,:), x0(1,:)) + ba;     % bias direction (fixed in the world frame)
n.dpos = [s.*br.*cos(ang); s.*br.*sin(ang); s.*zb];
n.dpsi = s.*hb; n.du = s.*vb(1,:); n.dv = s.*vb(2,:); n.dr = s.*vb(3,:); n.datt = s.*da;
end

function V6 = decouple(V6)
% switch off rigid-body + added-mass Coriolis/centripetal coupling (incl. Munk moment)
V6.noC = true;
end
