function V6 = vehicle6dof(P)
% VEHICLE6DOF  BlueROV2 Heavy 6-DOF parameters (von Benzon et al. 2022, Table A1)
% for the 6-DOF falsification model. r_g = 0, r_b = (0,0,-0.01) m (CB above CG).
v = P.veh;
V6.M_RB = diag([v.m v.m v.m v.I]);
V6.M_A  = diag(v.Ma);
V6.Dl = v.Dl(:); V6.Dq = v.Dq(:);
V6.W = v.m*v.g; V6.B = v.rho*v.g*v.vol;
V6.rg = v.rg; V6.rb = v.rb;
V6.tauMax = v.tauMax(:);
V6.kz = P.heave.kz; V6.kw = P.heave.kw; V6.Ku = P.Ku; V6.Kv = P.Kv; V6.Kr = P.Kr;
V6.att = P.att;                 % roll/pitch hold PD (ASSUMED gains)
V6.att0 = [deg2rad(2); deg2rad(2)];   % initial |roll|, |pitch| bounds (rad), ASSUMED
V6.attRate = deg2rad(1);              % initial |p|, |q| bound (rad/s), ASSUMED
end
