function f = qdamp_model(P, x, k)
% QDAMP_MODEL  CORA-side model of the quadratic damping force q_k |x| x
% (P.dampModel = 'poly3' only; for 'bilinear' the coefficient is an input).
X = P.qX(k); t = x/X; c = P.qpoly.coef; f = 0;
for i = 1:numel(c), f = f + c(i)*t^(2*i-1); end
f = P.qDq(k)*X^2*f;
end
