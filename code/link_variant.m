function P = link_variant(P, knob, val)
% LINK_VARIANT  One-at-a-time hardware variant of the calibrated link (B1). Recomputes all
% derived quantities (Lambertian order, concentrator gain, background-limited P_min, K).
%   'Phi_half' [deg]  Tx half-power semi-angle (also the Tx-cone predicate)
%   'FOV'      [deg]  concentrator FOV half-angle (also the Rx-FOV predicate; changes the
%                     concentrator gain and the background light)
%   'Pmin_dB'  [dB]   receiver sensitivity offset relative to the BER-derived P_min
%   'Pt'       [W]    transmit power
switch knob
    case 'Phi_half', P.Phi_half = deg2rad(val);
    case 'FOV',      P.Psi_C = deg2rad(val);
    case 'Pt',       P.Pt = val;
    case 'Pmin_dB'   % handled after P_min is recomputed
    otherwise, error('unknown knob %s', knob);
end
P.m_lamb = -log(2)/log(cos(P.Phi_half)); P.gconc = P.n_conc^2/sin(P.Psi_C)^2;
P.Theta_T = P.Phi_half; P.FOV_R = P.Psi_C;
q = 1.602176634e-19; kB = 1.380649e-23; Qf = sqrt(2)*erfcinv(2*P.BER);
Pb = P.Es*P.tsurf*P.dlambda*P.Ar*P.gconc*exp(-P.water.a(1)*(1-P.c_rel_unc)*P.z_op);
sigma0 = sqrt(4*kB*P.Te*P.Bn/P.RL + 2*q*P.Resp*Pb*P.Bn + 2*q*P.Idark*P.Bn);
P.Pmin = (Qf/P.Resp)*(sigma0 + q*Qf*P.Bn);
if strcmp(knob,'Pmin_dB'), P.Pmin = P.Pmin*10^(val/10); end
P.K_dB = 10*log10(P.eta_t*P.eta_r*P.Pt*(P.m_lamb+1)/(2*pi)*P.Ar*P.gconc/P.Pmin);
P.variant = sprintf('%s=%g', knob, val);
end
