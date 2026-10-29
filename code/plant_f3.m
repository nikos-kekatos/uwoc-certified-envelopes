function dx = plant_f3(P, x, tau, w)
% PLANT_F3  TRUE 3-D reduced plant (simulation twin of aug_dyn3, exact |x|).
%   x = [d;phi;e;u;v;r;z;wz;th0], tau = commands [u_c;r_c], w = [w_r;w_t;w_v;dz]
d = x(1,:); e = x(3,:); u = x(4,:); v = x(5,:); r = x(6,:); z = x(7,:); wz = x(8,:); th = x(9,:);
H = P.heave; uh = u; ce = cos(e); se = sin(e);   % body level; th0 = boresight mount offset
phidot = (-uh.*se - v.*ce + w(2,:))./d;
tz = -H.kz*(z + w(4,:)) - H.kw*wz;     % |tz| <= 60 N < 120 N limit in all declared cells
dx = [-uh.*ce + v.*se + w(1,:);
      phidot;
      r - phidot;
      (P.Ku*(tau(1,:) - u) + P.m22*v.*r - (P.d11 + P.q11*abs(u)).*u)/P.m11;
      (-P.Kv*v - P.m11*u.*r - (P.d22 + P.q22*abs(v)).*v)/P.m22;
      (P.Kr*(tau(2,:) - r) - (P.m22-P.m11)*u.*v - (P.d33 + P.q33*abs(r)).*r)/P.m33;
      wz + w(3,:);
      (tz - (H.d + H.q*abs(wz)).*wz)/H.m;
      zeros(1,size(x,2))];
end
