function U = nn_set_eval(C, Z, evo)
% NN_SET_EVAL  Sound enclosure of the actor output over the polyZonotope Z.
%   C = struct from ctrl_sets(net): C.core (CORA net without saturation),
%   C.sat (CORA 2-layer ReLU saturation), C.K, C.kb (linear skip, exact).
%   Output U = sat(K Z + kb + core(Z)), dependencies on Z's factors kept.
Y = C.core.evaluate(Z, evo);
if any(C.K(:))
    L = C.K*Z + C.kb;                 % exact affine map
    Y = aux_sum(L, Y);
end
U = C.sat.evaluate(Y, evo);
end

function S = aux_sum(A, B)
% exact sum of two polyZonotopes defined over (subsets of) the same factors
ids = unique([A.id; B.id]);
EA = zeros(numel(ids), size(A.E,2)); EB = zeros(numel(ids), size(B.E,2));
[~,la] = ismember(A.id, ids); [~,lb] = ismember(B.id, ids);
EA(la,:) = A.E; EB(lb,:) = B.E;
GIa = A.GI; GIb = B.GI; n = size(A.c,1);
if isempty(GIa), GIa = zeros(n,0); end
if isempty(GIb), GIb = zeros(n,0); end
S = polyZonotope(A.c + B.c, [A.G, B.G], [GIa, GIb], [EA, EB], ids);
S = compact(S, 'all', eps);
end
