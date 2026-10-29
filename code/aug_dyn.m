function dx = aug_dyn(x, w)
% AUG_DYN  CORA model of the planar closed loop: states [d;phi;e;u;v;r;u_c;r_c]
% (actor commands held over the control period, low-level velocity loop inside),
% inputs w = [w_r; w_t; du; dv; dr]: current, and the uncertain quadratic-damping
% coefficients du = q11|u| in [0, q11 X_u] etc. (exact while |x| <= X, asserted).
persistent P
if isempty(P), P = uwoc_params(); end
d = x(1); e = x(3); u = x(4); v = x(5); r = x(6); tu = x(7); tr = x(8);
ce = cos(e); se = sin(e);
phidot = (-u*se - v*ce + w(2))/d;
dx = [-u*ce + v*se + w(1);
      phidot;
      r - phidot;
      (P.Ku*(tu - u) + P.m22*v*r - P.d11*u - dmp(P,u,1,w(3)))/P.m11;
      (-P.Kv*v - P.m11*u*r - P.d22*v - dmp(P,v,2,w(4)))/P.m22;
      (P.Kr*(tr - r) - (P.m22-P.m11)*u*v - P.d33*r - dmp(P,r,3,w(5)))/P.m33;
      0;
      0];
end

function f = dmp(P, x, k, wi)
% quadratic damping force in the CORA model: input wi is a force error (poly3)
% or an uncertain damping coefficient (bilinear)
if strcmp(P.dampModel, 'bilinear'), f = wi*x; else, f = qdamp_model(P, x, k) - wi; end
end
