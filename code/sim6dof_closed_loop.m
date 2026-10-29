function out = sim6dof_closed_loop(P, V6, scen, net)
% SIM6DOF_CLOSED_LOOP  6-DOF Fossen simulation of the BlueROV2 Heavy (von Benzon et
% al. 2022) -- falsification only, NOT verified.
%   eta = [x y z phi theta psi] (NED, receiver at origin, z down); nu_r = [u v w p q r]
%   relative to the water; irrotational current V_c (world, incl. vertical):
%     eta_dot = J(eta) nu_r + [V_c; 0]
%     M nu_r_dot + C(nu_r) nu_r + D(nu_r) nu_r + g(eta) = tau      (Fossen 2021)
%   M = M_RB + M_A diagonal (r_g = 0), so C(nu)nu = [n2 x a ; n1 x a + n2 x b],
%   a = M11 n1, b = M22 n2 (generic skew form), including the Munk moment.
% Low-level control (documented interface of the planar actor):
%   surge/yaw-rate commands [u_c; r_c] <- planar actor (horizontal estimates, ZOH);
%   forces X = Ku(u_c-u), Y = -Kv v, N = Kr(r_c-r) from the continuous low-level loop
%   heave force Z                    <- PD depth hold on the estimated relative depth
%   roll/pitch moments K, M          <- PD attitude hold on the ESTIMATED roll/pitch
%                                      (attitude noise |d_att| <= scen bound)
%   inner loops run in continuous time (as in the 2-D/3-D rungs) on estimates held
%   over the control period; outputs saturated at the vehicle maxima.
% Optics: boresight = body x-axis pitched by a static mount offset scen.mount;
%   Rx normal tilted by scen.alphaR (2xN: about y and z). ACE in 3-D, same
%   predicates and margin_db as the lower rungs.
N = size(scen.x0,2); T = P.T;
nC = round(T/P.dt_ctrl); nS = round(P.dt_ctrl/P.dt_sim); h = P.dt_sim;
Md = diag(V6.M_RB + V6.M_A); Md = Md(:);
noC = isfield(V6,'noC') && V6.noC;
x = scen.x0;
rho = inf(1,N); fp = zeros(1,N); Mmin = inf(1,N); maxRoll = zeros(1,N); maxPitch = zeros(1,N);
for k = 1:nC
    n = scen.noise(k);
    pxy = x(1:2,:) + n.dpos(1:2,:);
    dh  = sqrt(sum(pxy.^2,1)); phih = atan2(pxy(2,:), pxy(1,:));
    ehat = wrapToPi(x(6,:) + n.dpsi - phih - pi);
    z = [dh; ehat; x(7,:)+n.du; x(8,:)+n.dv; x(12,:)+n.dr; scen.chat];
    tau2 = nn_forward(net, z);
    cmd = tau2;     % [u_c; r_c] held; all low-level loops run in continuous time
    nz = n.dpos(3,:); na = n.datt;   % estimate errors held over the control period
    for s = 1:nS
        t = (k-1)*P.dt_ctrl + (s-1)*h;
        f = @(xx,tt) dyn(V6, Md, noC, xx, lowlevel(V6, xx, cmd, nz, na), scen.Vc(tt));
        k1 = f(x,t); k2 = f(x+h/2*k1,t+h/2); k3 = f(x+h/2*k2,t+h/2); k4 = f(x+h*k3,t+h);
        x = x + h/6*(k1+2*k2+2*k3+k4);
        [r3, Mg] = ace3(P, x, scen.c, scen.alphaR, scen.mount);
        [rmin, which] = min(r3, [], 1);
        nv = fp == 0 & rmin < 0; fp(nv) = which(nv);
        rho = min(rho, rmin); Mmin = min(Mmin, Mg);
        maxRoll = max(maxRoll, abs(x(4,:))); maxPitch = max(maxPitch, abs(x(5,:)));
    end
end
out.rho = rho; out.firstProv = fp; out.Mmin = Mmin; out.xT = x;
out.maxRoll = maxRoll; out.maxPitch = maxPitch;
end

function y = sat(y, m), y = min(max(y, -m), m); end

function t = lowlevel(V6, x, cmd, nz, na)
% continuous inner loops (as in the 2-D/3-D rungs): surge/yaw velocity tracking,
% sway hold, depth hold on the estimated depth, roll/pitch hold on estimated attitude
t = [V6.Ku*(cmd(1,:) - x(7,:));
     -V6.Kv*x(8,:);
     -V6.kz*(x(3,:) + nz) - V6.kw*x(9,:);
     -V6.att.kp(1)*(x(4,:) + na(1,:)) - V6.att.kd(1)*x(10,:);
     -V6.att.kp(2)*(x(5,:) + na(2,:)) - V6.att.kd(2)*x(11,:);
     V6.Kr*(cmd(2,:) - x(12,:))];
t = min(max(t, -V6.tauMax), V6.tauMax);
end

function dx = dyn(V6, Md, noC, x, tau, Vc)
ph = x(4,:); th = x(5,:); ps = x(6,:); nu = x(7:12,:);
cph = cos(ph); sph = sin(ph); cth = cos(th); sth = sin(th); cps = cos(ps); sps = sin(ps);
u = nu(1,:); v = nu(2,:); w = nu(3,:); p = nu(4,:); q = nu(5,:); r = nu(6,:);
% kinematics J(eta) nu (ZYX Euler angles)
xd = cps.*cth.*u + (-sps.*cph + cps.*sth.*sph).*v + (sps.*sph + cps.*cph.*sth).*w;
yd = sps.*cth.*u + (cps.*cph + sph.*sth.*sps).*v + (-cps.*sph + sth.*sps.*cph).*w;
zd = -sth.*u + cth.*sph.*v + cth.*cph.*w;
phd = p + sph.*sth./cth.*q + cph.*sth./cth.*r;
thd = cph.*q - sph.*r;
psd = sph./cth.*q + cph./cth.*r;
% Coriolis/centripetal (diagonal M)
if noC
    Cn = zeros(6, size(x,2));
else
    n1 = nu(1:3,:); n2 = nu(4:6,:);
    a = Md(1:3).*n1; b = Md(4:6).*n2;
    Cn = [cross(n2, a, 1); cross(n1, a, 1) + cross(n2, b, 1)];
end
Dn = V6.Dl.*nu + V6.Dq.*abs(nu).*nu;
W = V6.W; B = V6.B; rg = V6.rg; rb = V6.rb;
g = [ (W-B).*sth;
     -(W-B).*cth.*sph;
     -(W-B).*cth.*cph;
     -(rg(2)*W - rb(2)*B).*cth.*cph + (rg(3)*W - rb(3)*B).*cth.*sph;
      (rg(3)*W - rb(3)*B).*sth + (rg(1)*W - rb(1)*B).*cth.*cph;
     -(rg(1)*W - rb(1)*B).*cth.*sph - (rg(2)*W - rb(2)*B).*sth];
nud = (tau - Cn - Dn - g)./Md;
dx = [xd + Vc(1,:); yd + Vc(2,:); zd + Vc(3,:); phd; thd; psd; nud];
end

function [r3, M] = ace3(P, x, c, alphaR, mount)
% 3-D ACE robustness [Tx deg; Rx deg; margin dB] (simulation; acos is fine here)
ph = x(4,:); th = x(5,:); ps = x(6,:);
cph = cos(ph); sph = sin(ph); cth = cos(th); sth = sin(th); cps = cos(ps); sps = sin(ps);
bb = [cos(mount); zeros(size(mount)); -sin(mount)];               % body-frame boresight
b = [cps.*cth.*bb(1,:) + (-sps.*cph + cps.*sth.*sph).*bb(2,:) + (sps.*sph + cps.*cph.*sth).*bb(3,:);
     sps.*cth.*bb(1,:) + (cps.*cph + sph.*sth.*sps).*bb(2,:) + (-cps.*sph + sth.*sps.*cph).*bb(3,:);
     -sth.*bb(1,:) + cth.*sph.*bb(2,:) + cth.*cph.*bb(3,:)];
p = x(1:3,:); d3 = sqrt(sum(p.^2,1)); l = -p./d3;
ay = alphaR(1,:); az = alphaR(2,:);
nR = [cos(ay).*cos(az); cos(ay).*sin(az); -sin(ay)];
ce = min(max(sum(b.*l,1),-1),1); ci = min(max(sum(nR.*(-l),1),-1),1);
e3 = acos(ce); inc = acos(ci);
M = margin_db(P, d3, e3, inc, c);
r3 = [rad2deg(P.Theta_T - e3); rad2deg(P.FOV_R - inc); M];
end
