function cmd = teacher_sway_policy(P, z)
% TEACHER_SWAY_POLICY  B3 extended teacher: the classical law (teacher_policy) plus a
% sway-speed command that holds the bearing and so counters lateral drift (Rx-FOV loss):
%   z = [d_hat; e_hat; u; v; r; c_hat; phi_hat]
%   u_c = sat(k_d (d_hat - d_ref(c_hat))),  r_c = sat(-k_e e_hat)   (as teacher_policy)
%   v_c = sat(k_phi phi_hat), |v_c| <= P.b3.vc_max                   (as fallback_sway)
% Smooth apart from the actuator saturations (no gating), output order [u_c; r_c; v_c].
cmd = [teacher_policy(P, z(1:6,:)); min(max(P.b3.k_phi*z(7,:), -P.b3.vc_max), P.b3.vc_max)];
end
