function net = fallback_net(P)
% FALLBACK_NET  Shield fallback "slow down and turn towards the receiver" as an exact
% piecewise-linear network on z = [d;e;u;v;r;c]: u_c = 0, r_c = sat(-fb_k_e e_hat).
L = zeros(2,6); L(2,2) = -P.fb_k_e;
net.W = {L}; net.b = {zeros(2,1)}; net.sat = [P.uc_max; P.rc_max];
net.name = 'fallback';
end
