% EXPORT_ACTOR_JSON  Dump actor weights + 200 reference input/output pairs to JSON
% (consumed by export_onnx.py, which builds and checks the ONNX file).
P = uwoc_params();
if ~exist('actorTag','var'), actorTag = 'res_32'; end
L = load(fullfile(P.results,'phase2',['actor_' actorTag '.mat'])); n = L.net;
rng(3); Z = [0.75+11*rand(1,200); deg2rad(40)*(2*rand(1,200)-1); -0.3+0.6*rand(1,200); ...
    0.15*(2*rand(1,200)-1); 0.3*(2*rand(1,200)-1); P.water.c(randi(3,1,200))];
J = struct('W', {n.W}, 'b', {n.b}, 'K', n.K, 'kb', n.kb, 'sat', n.sat, 'Z', Z, 'Y', nn_forward(n, Z), 'tag', actorTag);
d = P.models; if ~exist(d,'dir'), mkdir(d); end
fid = fopen(fullfile(d, ['actor_' actorTag '.json']), 'w'); fprintf(fid, '%s', jsonencode(J)); fclose(fid);
