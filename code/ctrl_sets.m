function C = ctrl_sets(net)
% CTRL_SETS  CORA objects for set evaluation of an actor (or fallback) struct.
L = numel(net.W); layers = {};
for i = 1:L-1
    layers{end+1} = nnLinearLayer(net.W{i}, net.b{i}); %#ok<AGROW>
    layers{end+1} = nnReLULayer(); %#ok<AGROW>
end
layers{end+1} = nnLinearLayer(net.W{L}, net.b{L});
C.core = neuralNetwork(layers');
s = net.sat(:); m = numel(s);
C.sat = neuralNetwork({nnLinearLayer([eye(m); eye(m)], [s; -s]); nnReLULayer(); ...
                       nnLinearLayer([eye(m), -eye(m)], -s)});
if isfield(net,'K') && ~isempty(net.K), C.K = net.K; C.kb = net.kb;
else, C.K = zeros(m, size(net.W{1},2)); C.kb = zeros(m,1); end
end
