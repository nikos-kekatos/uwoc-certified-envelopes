function [wfun, info] = cur_rate_wfun(cellc, TH, kind)
% CUR_RATE_WFUN  Current paths of the rate-bounded current model (campaign E).
% Every path satisfies, for all t in [0, T]:
%   |W(t)| <= w0                     (declared magnitude bound, the disk)
%   |dW_x/dt|, |dW_y/dt| <= rho      (declared rate bound, rho = cellc.rho)
% so it is admissible for the CORA model of reach_cell with curModel = 'rate'.
%   TH   : 5 x N parameters in [0, 1]
%          1 magnitude m0, 2 direction a0, 3 rotation rate, 4 reversal time, 5 magnitude ramp
%   kind : 'mc' (m0 = w0 sqrt(TH1), uniform on the disk) or 'fals' (m0 = w0 TH1)
% Path: W(t) = m(t) [cos a(t); sin a(t)] with
%   m(t) = clamp(m0 + mdot t, 0, w0),  |mdot| <= rho*(2 TH5 - 1) (signed)
%   a(t) = a0 + om t (t < ts), a0 + om ts - om (t - ts) (t >= ts),  ts = 20 TH4 (TH4 = 1: none)
%   |om| <= (rho - |mdot|)/w0,
% hence |dW_i/dt| <= |mdot| + m(t)|om| <= |mdot| + (rho - |mdot|) = rho.
% rho = 0 gives a constant world-frame current (quasi-static regime R0).
% Returns polar components [w_r; w_t] (map of polarw in mc_scen).
w0 = cellc.w; rho = cellc.rho; N = size(TH,2);
if strcmp(kind,'mc'), m0 = w0*sqrt(TH(1,:)); else, m0 = w0*TH(1,:); end
a0 = 2*pi*TH(2,:);
mdot = rho*(2*TH(5,:) - 1);
if w0 > 0, omax = (rho - abs(mdot))/w0; else, omax = zeros(1,N); end
om = omax.*(2*TH(3,:) - 1);
ts = 20*TH(4,:); ts(TH(4,:) >= 1) = inf;
info = struct('m0',m0,'a0',a0,'mdot',mdot,'om',om,'ts',ts);
wfun = @(t,x) aux_polar(t, x, m0, a0, mdot, om, ts, w0);
end

function w = aux_polar(t, x, m0, a0, mdot, om, ts, w0)
m = min(max(m0 + mdot*t, 0), w0);
tt = min(t, ts);
a = a0 + om.*tt - om.*max(t - ts, 0);
Wx = m.*cos(a); Wy = m.*sin(a);
phi = x(2,:);
w = [Wx.*cos(phi) + Wy.*sin(phi); -Wx.*sin(phi) + Wy.*cos(phi)];
end
