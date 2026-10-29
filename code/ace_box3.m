function [pTx, pRx, Ml] = ace_box3(P, I, chi, alphaR)
% ACE_BOX3  Sound check of the 3-D ACE over a box I of [d;phi;e;u;v;r;z;wz;th0]
% by interval arithmetic (CORA interval class). Receiver tilt |alpha| <= alphaR.
%   cos e3  = (cos th cos e + zeta sin th) / sqrt(1+zeta^2),  zeta = z/d  (Tx boresight vs LOS)
%   cos inc = (cos phi cos a - zeta sin a) / sqrt(1+zeta^2)               (Rx normal vs light)
% pTx/pRx = predicate MAY be violated; Ml = sound lower bound of the margin
% (margin is decreasing in d3, c, e3 and inc).
lo = infimum(I); hi = supremum(I);
d = interval(lo(1),hi(1)); ph = interval(lo(2),hi(2)); e = interval(lo(3),hi(3));
z = interval(lo(7),hi(7)); th = interval(lo(9),hi(9)); a = interval(-alphaR, alphaR);
if lo(1) <= 0, pTx = true; pRx = true; Ml = -inf; return; end
d3 = sqrt(d.^2 + z.^2);
zeta = z./d;                                   % removes the d-dependency problem
den = sqrt(1 + zeta.^2);
ce3 = (cos(th).*cos(e) + zeta.*sin(th))./den;
ci  = (cos(ph).*cos(a) - zeta.*sin(a))./den;
ce3lo = max(min(infimum(ce3),1),-1); cilo = min(infimum(ci),1);
pTx = ce3lo < cos(P.Theta_T);
pRx = cilo < cos(P.FOV_R);
if cilo <= 0
    Ml = -inf;
else
    Ml = margin_db(P, supremum(d3), acos(ce3lo), acos(cilo), chi);
end
end
