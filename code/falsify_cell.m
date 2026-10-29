function F = falsify_cell(P, ctrl, cellc, fo)
% FALSIFY_CELL  Adversarial search (cross-entropy method) for a CONCRETE
% trajectory inside the declared bounds of the cell that leaves ACE_O.
%   ctrl : @(z,k,x) -> [tau, interv]
%   fo.objective : 'maint' (min robustness over [0,T]) or 'est' (over [Te,T])
% Parameters theta in [0,1]^19: initial state (6), c (1), current magnitude,
% direction and rotation rate (3), position-error bias radius, direction
% relative to the LOS and rotation (3), heading bias (1), square-wave switching
% period and phase of all biases (2), velocity biases (3).
% A cell is Falsified only if rho < -fo.tol (tolerance against RK4 error).
if ~isfield(fo,'pop'), fo.pop = 120; end
if ~isfield(fo,'iters'), fo.iters = 12; end
if ~isfield(fo,'elite'), fo.elite = 12; end
if ~isfield(fo,'tol'), fo.tol = 0.01; end
if ~isfield(fo,'objective'), fo.objective = 'maint'; end
if ~isfield(cellc,'crel'), cellc.crel = P.c_rel_unc; end
if ~isfield(cellc,'epsVel'), cellc.epsVel = [P.eps_u; P.eps_v; P.eps_r]; end
is3 = numel(cellc.lo) == 9;
isRate = isfield(cellc,'curModel') && strcmp(cellc.curModel,'rate') && ~is3;   % campaign E
np = 19 + 6*is3 + 2*isRate; mu = 0.5*ones(np,1); sd = 0.35*ones(np,1);
F = struct('found',false,'rho',inf,'theta',[],'prov',0,'tOut',nan,'nEval',0,'runtime',0);
t0 = tic;
for it = 1:fo.iters
    TH = min(max(mu + sd.*randn(np, fo.pop), 0), 1);
    snap = rand(np, fo.pop) < 0.25;                    % push some coords to bounds
    TH(snap) = round(TH(snap));
    scen = theta2scen(P, cellc, TH);
    o = sim_closed_loop(P, scen, ctrl, struct('T', cellc.T, 'Te', cellc.Te, 'passPhiHat', isfield(fo,'passPhiHat') && fo.passPhiHat));
    if strcmp(fo.objective,'est'), r = o.rhoLate; else, r = o.rho; end
    F.nEval = F.nEval + fo.pop;
    [rs, ord] = sort(r);
    if rs(1) < F.rho
        F.rho = rs(1); F.theta = TH(:,ord(1)); F.prov = o.firstProv(ord(1)); F.tOut = o.firstOut(ord(1));
        F.lastOut = o.lastOut(ord(1));
    end
    if F.rho < -fo.tol, F.found = true; break; end
    el = TH(:, ord(1:fo.elite));
    mu = mean(el,2); sd = max(std(el,0,2), 0.03);
end
F.runtime = toc(t0);
end

function scen = theta2scen(P, c, TH)
N = size(TH,2);
nx = numel(c.lo); is3 = nx == 9;
scen.x0 = c.lo + (c.hi - c.lo).*TH(1:nx,:);
o = nx - 6;   % offset of the remaining parameters for 3-D cells
scen.c  = c.c*(1 + c.crel*(2*TH(7+o,:)-1));
scen.chat = c.c*ones(1,N);
wm = c.w*TH(8+o,:); wa = 2*pi*TH(9+o,:); wo = 0.2*(2*TH(10+o,:)-1);
if is3
    wvv = c.wv*(2*TH(20+o,:)-1);
    scen.wfun = @(t,x) [polarw([wm.*cos(wa+wo*t); wm.*sin(wa+wo*t)], x); wvv];
    zb = c.locz*(2*TH(21+o,:)-1);
    scen.alphaR = c.alphaR*(2*TH(22+o,:)-1);
else
    scen.wfun = @(t,x) polarw([wm.*cos(wa+wo*t); wm.*sin(wa+wo*t)], x);
    zb = zeros(1,N);end
if isfield(c,'curModel') && strcmp(c.curModel,'rate') && ~is3
    % campaign E: rate-bounded current (magnitude, direction, rotation rate, reversal time,
    % magnitude ramp), every path admissible for the 'rate' model (cur_rate_wfun)
    scen.wfun = cur_rate_wfun(c, [TH(8:10,:); TH(end-1:end,:)], 'fals');
end
br = c.loc*TH(11+o,:); ba = 2*pi*TH(12+o,:); bo = 0.5*(2*TH(13+o,:)-1);
hb = c.epsPsi*(2*TH(14+o,:)-1);
Tp = 1 + 39*TH(15+o,:); ph = 2*pi*TH(16+o,:);
vb = c.epsVel(:).*(2*TH((17:19)+o,:)-1);
scen.noise = @(k,x) noisefun(k, x, br, ba, bo, hb, Tp, ph, vb, zb, P);
end

function n = noisefun(k, x, br, ba, bo, hb, Tp, ph, vb, zb, P)
t = (k-1)*P.dt_ctrl;
s = sign(sin(2*pi*t./Tp + ph)); s(s==0) = 1;
ang = x(2,:) + ba + bo*t;             % bias direction relative to the LOS
n.dpos = [s.*br.*cos(ang); s.*br.*sin(ang)];
n.dpsi = s.*hb; n.du = s.*vb(1,:); n.dv = s.*vb(2,:); n.dr = s.*vb(3,:); n.dz = s.*zb;
end

function w = polarw(W, x)
phi = x(2,:);
w = [W(1,:).*cos(phi) + W(2,:).*sin(phi); -W(1,:).*sin(phi) + W(2,:).*cos(phi)];
end
