function dx = aug_dyn3(x, w)
% AUG_DYN3  CORA model, 3-D reduced rung: states [d;phi;e;u;v;r;z;wz;th0;u_c;r_c]
%   z: Tx depth relative to Rx (NED, + = deeper), wz: heave velocity, th0: static
%   pitch offset of the optical boresight w.r.t. the (level, attitude-held) body. Inputs w = [w_r; w_t; w_v; dz; du; dv; dr; dw]:
%   horizontal and vertical current, depth-estimate error of the PD depth hold
%   (continuous inner loop), and uncertain quadratic-damping coefficients in [0, qX].
persistent P
if isempty(P), P = uwoc_params(); end
d = x(1); e = x(3); u = x(4); v = x(5); r = x(6); z = x(7); wz = x(8); th = x(9);
tu = x(10); tr = x(11); H = P.heave;
uh = u; ce = cos(e); se = sin(e);   % body level (attitude held); th0 tilts only the boresight
phidot = (-uh*se - v*ce + w(2))/d;
dx = [-uh*ce + v*se + w(1);
      phidot;
      r - phidot;
      (P.Ku*(tu - u) + P.m22*v*r - P.d11*u - dmp(P,u,1,w(5)))/P.m11;
      (-P.Kv*v - P.m11*u*r - P.d22*v - dmp(P,v,2,w(6)))/P.m22;
      (P.Kr*(tr - r) - (P.m22-P.m11)*u*v - P.d33*r - dmp(P,r,3,w(7)))/P.m33;
      wz + w(3);
      (-H.kz*(z + w(4)) - H.kw*wz - H.d*wz - dmp(P,wz,4,w(8)))/H.m;
      0;
      0;
      0];
end

function f = dmp(P, x, k, wi)
% quadratic damping force in the CORA model: input wi is a force error (poly3)
% or an uncertain damping coefficient (bilinear)
if strcmp(P.dampModel, 'bilinear'), f = wi*x; else, f = qdamp_model(P, x, k) - wi; end
end
