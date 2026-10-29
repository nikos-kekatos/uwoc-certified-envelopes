function y = nn_forward(net, z)
% NN_FORWARD  Numeric forward pass of the deployed actor (columns = samples).
%   net.W{i}, net.b{i}: affine layers with ReLU between them (normalisation
%   already folded into W{1}, b{1}; output scaling folded into W{end}).
%   net.sat: actuator limits, output = sat(core(z)) (exactly what CORA verifies).
h = z;
L = numel(net.W);
for i = 1:L
    h = net.W{i}*h + net.b{i};
    if i < L, h = max(h,0); end
end
if isfield(net,'K') && ~isempty(net.K), h = h + net.K*z + net.kb; end
y = min(max(h, -net.sat), net.sat);
end
