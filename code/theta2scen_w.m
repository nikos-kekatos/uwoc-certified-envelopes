function scen = theta2scen_w(P, c, TH)
% THETA2SCEN_W  Standalone copy of falsify_cell>theta2scen (2026-10-18) so that a
% witness parameter vector theta can be re-simulated outside the falsifier.

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
