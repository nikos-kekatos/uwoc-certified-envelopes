function net = fallback_sway(P, wi)
% FALLBACK_SWAY  Sway-capable shield fallback (S1), an exact piecewise-linear network on
% z7 = [d_hat; e_hat; u; v; r; c_hat; phi_hat] for water type wi:
%   u_c = sat(k_d (d_hat - d_ref(c)))     hold the standoff range
%   r_c = sat(-k_e e_hat)                  keep the Tx cone on the receiver
%   v_c = sat(k_phi phi_hat)               sway to cancel lateral drift / hold bearing
% (positive sway moves the vehicle towards decreasing phi when it faces the receiver).
dref = aux_dref(P, P.water.c(wi));
W = zeros(3,7);
W(1,1) = P.fbs.k_d;   b1 = -P.fbs.k_d*dref;
W(2,2) = -P.fbs.k_e;
W(3,7) = P.fbs.k_phi;
net.W = {W}; net.b = {[b1; 0; 0]}; net.sat = [P.uc_max; P.rc_max; P.vc_max];
net.nIn = 7; net.name = sprintf('fallback_sway_%s', P.water.name{wi});
end

function d = aux_dref(P, c)
d = 3;
for k = 1:40
    g = margin_db(P, d, 0, 0, c) - P.M_goal; dg = -20/(d*log(10)) - (10/log(10))*c;
    d = max(d - g/dg, 0.3);
end
d = min(max(d, P.d_ref_min), P.d_ref_max);
end
