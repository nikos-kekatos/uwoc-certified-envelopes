function [net, info] = train_actor(P, H, Z, Y, seed, epochs, arch, wts, sat)
% TRAIN_ACTOR  Supervised imitation of the teacher by a 2-hidden-layer ReLU MLP.
%   Z 6xN inputs [d;e;u;v;r;c], Y 2xN teacher outputs (saturated torques).
%   Returns net (normalisation and output scaling folded in) for nn_forward /
%   cora_net. Deep Learning Toolbox trainnet, Adam, MSE on scaled targets.
if nargin < 5, seed = 1; end
if nargin < 6, epochs = 60; end
if nargin < 7, arch = 'mlp'; end
if nargin < 8, wts = []; end
if nargin < 9 || isempty(sat), sat = [P.tau_u_max; P.tau_r_max]; end   % 3 outputs (B3): [u_c; r_c; v_c] limits
nIn = size(Z,1); nOut = size(Y,1);
% arch 'res': tau = sat(K z + kb + MLP(z)); K,kb fitted by least squares on the
% unsaturated teacher samples, the MLP learns the residual.
K = zeros(nOut,nIn); kb = zeros(nOut,1);
if strcmp(arch,'res')
    ys0 = sat(:);
    for j = 1:nOut
        m = abs(Y(j,:)) < 0.98*ys0(j);
        A = [Z(:,m)', ones(nnz(m),1)];
        th = A \ Y(j,m)';
        K(j,:) = th(1:nIn)'; kb(j) = th(nIn+1);
    end
    Y = Y - (K*Z + kb);
end
if ~isempty(wts)   % sample weights via replication (integer weights)
    rep = repelem(1:size(Z,2), wts); Z = Z(:,rep); Y = Y(:,rep);
end
rng(seed);
mu = mean(Z,2); sg = std(Z,0,2); sg(sg==0) = 1;
ys = max(std(Y,0,2), 1e-6);            % target scaling (not the actuator limits)
Zn = ((Z - mu)./sg)'; Yn = (Y./ys)';
layers = [featureInputLayer(nIn,'Normalization','none'); fullyConnectedLayer(H); reluLayer; ...
          fullyConnectedLayer(H); reluLayer; fullyConnectedLayer(nOut)];
nb = ceil(size(Zn,1)/1024);
opts = trainingOptions('adam', 'MaxEpochs', epochs, 'MiniBatchSize', 1024, ...
    'InitialLearnRate', 3e-3, 'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropPeriod', round(epochs/3), 'LearnRateDropFactor', 0.3, ...
    'Shuffle', 'every-epoch', 'Verbose', false, 'ExecutionEnvironment', 'cpu', ...
    'L2Regularization', 1e-5);
t0 = tic;
dl = trainnet(Zn, Yn, dlnetwork(layers), 'mse', opts);
info.trainTime = toc(t0); info.iters = nb*epochs;
% extract weights and fold normalisation / scaling
Lr = dl.Learnables;
getW = @(name) double(extractdata(Lr.Value{strcmp(Lr.Layer,name) & strcmp(Lr.Parameter,'Weights')}));
getB = @(name) double(extractdata(Lr.Value{strcmp(Lr.Layer,name) & strcmp(Lr.Parameter,'Bias')}));
fc = unique(Lr.Layer,'stable');
W1 = getW(fc{1}); b1 = getB(fc{1});
W2 = getW(fc{2}); b2 = getB(fc{2});
W3 = getW(fc{3}); b3 = getB(fc{3});
net.W = {W1./sg', W2, ys.*W3};
net.b = {b1 - W1*(mu./sg), b2, ys.*b3};
net.sat = sat(:); net.H = H; net.mu = mu; net.sg = sg;
net.K = K; net.kb = kb; net.arch = arch;
end
