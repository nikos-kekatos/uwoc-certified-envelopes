function dx = aug_dyn_rate(x, w)
% AUG_DYN_RATE  CORA model of the planar closed loop with the current as STATES
% (campaign E, slowly varying current). States
%   x = [d; phi; e; u; v; r; w_r; w_t; u_c; r_c]
% where (w_r, w_t) are the polar components of the current (radial, tangential to the
% line of sight), i.e. the world-frame current W rotated by the bearing:
%   w_r = Wx cos(phi) + Wy sin(phi),  w_t = -Wx sin(phi) + Wy cos(phi)   (polarw in mc_scen).
% With dW/dt = mu (world frame), differentiation gives
%   dw_r/dt =  phi' w_t + nu_r,   dw_t/dt = -phi' w_r + nu_t,   nu = R(phi) mu,
% so a constant world current (mu = 0) is a rotation of (w_r, w_t) at the bearing rate.
% Inputs w = [nu_r; nu_t; du; dv; dr]: nu ranges over an octagon that contains the rotated
% rate box R(phi)[-rho, rho]^2 for every phi (nu = 0 for the quasi-static regime), and the
% damping-surrogate force errors du, dv, dr (as in aug_dyn.m).
% Writing the current in polar form keeps the plant affine in (w_r, w_t); the only new
% nonlinearity is phi'*w, whose interval width is small (|phi'| < 0.1 rad/s).
persistent P
if isempty(P), P = uwoc_params(); end
d = x(1); e = x(3); u = x(4); v = x(5); r = x(6);
wr = x(7); wt = x(8); tu = x(9); tr = x(10);
ce = cos(e); se = sin(e);
phidot = (-u*se - v*ce + wt)/d;
dx = [-u*ce + v*se + wr;
      phidot;
      r - phidot;
      (P.Ku*(tu - u) + P.m22*v*r - P.d11*u - dmp(P,u,1,w(3)))/P.m11;
      (-P.Kv*v - P.m11*u*r - P.d22*v - dmp(P,v,2,w(4)))/P.m22;
      (P.Kr*(tr - r) - (P.m22-P.m11)*u*v - P.d33*r - dmp(P,r,3,w(5)))/P.m33;
      phidot*wt + w(1);
      -phidot*wr + w(2);
      0;
      0];
end

function f = dmp(P, x, k, wi)
if strcmp(P.dampModel, 'bilinear'), f = wi*x; else, f = qdamp_model(P, x, k) - wi; end
end
