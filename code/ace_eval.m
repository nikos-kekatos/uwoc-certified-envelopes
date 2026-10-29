function [M, okTx, okRx, r3] = ace_eval(P, x, c, aR)
% ACE_EVAL  ACE in the planar (6 states) or 3-D reduced (9 states) geometry (simulation)
if size(x,1) == 9
    d = x(1,:); ph = x(2,:); e = x(3,:); z = x(7,:); th = x(9,:);
    zeta = z./d; den = sqrt(1+zeta.^2); d3 = d.*den;
    ce3 = (cos(th).*cos(e) + zeta.*sin(th))./den;
    ci  = (cos(ph).*cos(aR) - zeta.*sin(aR))./den;
    e3 = acos(min(max(ce3,-1),1)); inc = acos(min(max(ci,-1),1));
    M = margin_db(P, d3, e3, inc, c);
else
    e3 = abs(x(3,:)); inc = abs(x(2,:));
    M = margin_db(P, x(1,:), e3, inc, c);
end
okTx = e3 <= P.Theta_T; okRx = inc <= P.FOV_R;
r3 = [rad2deg(P.Theta_T - e3); rad2deg(P.FOV_R - inc); M];
end

