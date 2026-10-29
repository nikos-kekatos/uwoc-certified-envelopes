function [M, okTx, okRx] = link_margin(P, d, phi, e, c)
% LINK_MARGIN  Link margin [dB] and SEPARATE geometric predicates (vectorised).
%   Planar geometry, receiver at origin with normal n_R = [1 0].
%   Tx at p = d[cos phi, sin phi], boresight b_T = [cos psi, sin psi],
%   LOS l = -p/|p|, pointing error e = wrap(psi - phi - pi).
%     Tx-cone predicate : b_T . l      = cos(e)   >= cos(Theta_T)
%     Rx-FOV  predicate : n_R . (-l)   = cos(phi) >= cos(FOV_R)
%   Power (far-field Gaussian beam, Beer-Lambert extinction):
%     P_r = eta Pt exp(-c d) * 2 A_R cos(phi) / (pi (d theta)^2) * exp(-2 e^2/theta^2)
%   M = 10 log10(P_r/P_min). M is finite everywhere (no zero-power encoding);
%   outage = ~okTx | ~okRx | M < 0.
M = margin_db(P, d, e, phi, c);
okTx = cos(e)   >= cos(P.Theta_T);
okRx = cos(phi) >= cos(P.FOV_R);
end
