function scen = make_scen(P, N, cfg)
% MAKE_SCEN  Random scenarios inside a declared cell (for Monte Carlo).
%   cfg.c      nominal extinction (table value); true c ~ U[(1-u)c,(1+u)c]
%   cfg.d0     nominal initial range (cell d0 +- P.cell.d_half)
%   cfg.e0     initial pointing-error bound (|e0| <= cfg.e0)
%   cfg.loc    localisation error bound [m] (per-step error, |dpos| <= loc)
%   cfg.w      current bound [m/s] (|w| <= w), world-frame, slowly varying
%   cfg.epsPsi heading error bound (default P.eps_psi)
%   cfg.phi0   (optional) [lo hi] initial bearing interval
% All samples lie inside the same bounds that the reachability analysis uses.
if ~isfield(cfg,'epsPsi'), cfg.epsPsi = P.eps_psi; end
if ~isfield(cfg,'phi0'), cfg.phi0 = [-1 1]*P.cell.phi_half; end
if ~isfield(cfg,'dhalf'), cfg.dhalf = P.cell.d_half; end
if ~isfield(cfg,'e0lo'), cfg.e0lo = -cfg.e0; end
U = @(lo,hi) lo + (hi-lo).*rand(1,N);
scen.x0 = [U(cfg.d0-cfg.dhalf, cfg.d0+cfg.dhalf);
           U(cfg.phi0(1), cfg.phi0(2));
           U(cfg.e0lo, cfg.e0);
           U(P.cell.u0(1), P.cell.u0(2));
           U(-P.cell.v_half, P.cell.v_half);
           U(-P.cell.r_half, P.cell.r_half)];
scen.c    = cfg.c*(1 + P.c_rel_unc*(2*rand(1,N)-1));
scen.chat = cfg.c*ones(1,N);
% current: world-frame w(t) = w0 + w1 sin(om t + ph), |w0|+|w1| <= w
a0 = 2*pi*rand(1,N); a1 = 2*pi*rand(1,N);
r0 = cfg.w*sqrt(rand(1,N)); r1 = (cfg.w - r0).*rand(1,N);
om = 2*pi/30*(0.5+rand(1,N)); ph = 2*pi*rand(1,N);
W0 = [r0.*cos(a0); r0.*sin(a0)]; W1 = [r1.*cos(a1); r1.*sin(a1)];
scen.wfun = @(t,x) polarw(W0 + W1.*sin(om*t+ph), x);
% estimation errors: per-step uniform in the declared bounds
loc = cfg.loc; ep = cfg.epsPsi;
scen.noise = @(k,x) struct('dpos', diskU(loc,N), 'dpsi', ep*(2*rand(1,N)-1), ...
    'du', P.eps_u*(2*rand(1,N)-1), 'dv', P.eps_v*(2*rand(1,N)-1), 'dr', P.eps_r*(2*rand(1,N)-1));
scen.cfg = cfg;
end

function w = polarw(W, x)
phi = x(2,:);
w = [W(1,:).*cos(phi) + W(2,:).*sin(phi); -W(1,:).*sin(phi) + W(2,:).*cos(phi)];
end

function p = diskU(r, N)
a = 2*pi*rand(1,N); rr = r*sqrt(rand(1,N));
p = [rr.*cos(a); rr.*sin(a)];
end
