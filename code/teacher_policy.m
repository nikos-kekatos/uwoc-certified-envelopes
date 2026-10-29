function cmd = teacher_policy(P, z)
% TEACHER_POLICY  Communication-aware guidance law (teacher + classical baseline).
%   z = [d_hat; e_hat; u; v; r; c_hat] (estimated inputs, columns = samples)
%   Output: surge-speed and yaw-rate COMMANDS [u_c; r_c] for the low-level loop.
%   Range: regulate to the standoff d_ref(c_hat) at which the nominal aligned margin
%   equals M_goal (clamped). Yaw: point at the receiver, r_c = -k_e e_hat.
d = z(1,:); e = z(2,:); c = z(6,:);
dref = standoff_range(P, c);
uc = min(max(P.k_d*(d - dref), -P.uc_max), P.uc_max);
rc = min(max(-P.k_e*e, -P.rc_max), P.rc_max);
cmd = [uc; rc];
end

function dref = standoff_range(P, c)
% solve margin_db(d,0,0,c) = M_goal by Newton (monotone in d), clamp
d = 3*ones(size(c));
for k = 1:40
    g  = margin_db(P, d, 0, 0, c) - P.M_goal;
    dg = -20./(d*log(10)) - (10/log(10))*c;
    d  = max(d - g./dg, 0.3);
end
dref = min(max(d, P.d_ref_min), P.d_ref_max);
end
