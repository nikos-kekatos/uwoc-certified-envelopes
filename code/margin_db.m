function M = margin_db(P, d, e, inc, c)
% MARGIN_DB  Link margin [dB] = 10 log10(P_r / P_min), single source of the channel
% formula (MODEL.md). Lambertian source (order m, half-power angle Phi_half) and
% concentrator receiver (gain n^2/sin^2 Psi_C inside the FOV) as in N'Doye et al.
% 2021 (Eqs. 1-4), Beer-Lambert extinction exp(-c d), Tx/Rx efficiencies:
%   P_r = eta_t eta_r Pt (m+1)/(2 pi d^2) cos^m(e) * Ar g cos(inc) * exp(-c d)
% d: Tx-Rx distance, e: angle boresight-LOS, inc: incidence at Rx, c: extinction.
% Decreasing in d, |e|, |inc| (< pi/2) and c. FOV gating is a SEPARATE predicate.
M = P.K_dB - 20*log10(d) - (10/log(10)).*c.*d + P.m_lamb*10*log10(max(cos(e),1e-12)) ...
    + 10*log10(max(cos(inc),1e-12));
end
