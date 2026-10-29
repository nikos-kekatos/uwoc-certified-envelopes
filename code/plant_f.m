function dx = plant_f(P, x, cmd, w)
% PLANT_F  TRUE planar plant: BlueROV2 3-DOF Fossen model (surge, sway, yaw) with the
% low-level velocity loop, in receiver-centred polar coordinates (simulation).
%   x = [d; phi; e; u; v; r], cmd = [u_c; r_c] or [u_c; r_c; v_c], w = [w_r; w_t]
%   m11 u' = Ku (u_c - u) + m22 v r - (d11 + q11|u|) u
%   m22 v' = Kv (v_c - v) - m11 u r - (d22 + q22|v|) v   (v_c = 0: sway hold)
%   m33 r' = Kr (r_c - r) - (m22-m11) u v - (d33 + q33|r|) r
d = x(1,:); e = x(3,:); u = x(4,:); v = x(5,:); r = x(6,:);
if size(cmd,1) >= 3, vc = cmd(3,:); else, vc = 0; end
ce = cos(e); se = sin(e);
phidot = (-u.*se - v.*ce + w(2,:))./d;
dx = [-u.*ce + v.*se + w(1,:);
      phidot;
      r - phidot;
      (P.Ku*(cmd(1,:) - u) + P.m22*v.*r - (P.d11 + P.q11*abs(u)).*u)/P.m11;
      (P.Kv*(vc - v) - P.m11*u.*r - (P.d22 + P.q22*abs(v)).*v)/P.m22;
      (P.Kr*(cmd(2,:) - r) - (P.m22-P.m11)*u.*v - (P.d33 + P.q33*abs(r)).*r)/P.m33];
end
