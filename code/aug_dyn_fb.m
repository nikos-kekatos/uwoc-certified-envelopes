function dx = aug_dyn_fb(x, w)
% AUG_DYN_FB  CORA model with the sway-capable fallback: states
% [d;phi;e;u;v;r;u_c;r_c;v_c] (commands held, ZOH), inputs [w_r;w_t;f_u;f_v;f_r];
% same polynomial damping surrogate as aug_dyn but with the envelope P.qXfb.
persistent P
if isempty(P), P = uwoc_params(); P.qX = P.qXfb; P.qErr = P.qpoly.err*P.qX.^2.*P.qDq; end
d = x(1); e = x(3); u = x(4); v = x(5); r = x(6); uc = x(7); rc = x(8); vc = x(9);
ce = cos(e); se = sin(e);
phidot = (-u*se - v*ce + w(2))/d;
dx = [-u*ce + v*se + w(1);
      phidot;
      r - phidot;
      (P.Ku*(uc - u) + P.m22*v*r - P.d11*u - qdamp_model(P,u,1) + w(3))/P.m11;
      (P.Kv*(vc - v) - P.m11*u*r - P.d22*v - qdamp_model(P,v,2) + w(4))/P.m22;
      (P.Kr*(rc - r) - (P.m22-P.m11)*u*v - P.d33*r - qdamp_model(P,r,3) + w(5))/P.m33;
      0; 0; 0];
end
