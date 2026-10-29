% DIAG_CHAIN_GROWTH  Lower bound on the true reachable spread of d and phi (simulation,
% not verification): cell centre, no noise, constant polar current of magnitude w
% (pure tangential +-w, pure radial +-w), widths at t = 4, 8, ..., 20 s.
P = setup_paths(); L = load(fullfile(P.results,'phase2','actor_res_32.mat')); net = L.net;
M = load(fullfile(P.results,'opmap','opmap_res_32.mat'));
ctrl = make_ctrl(net);
for i = diagCells
    c = M.cells{i}; W = c.w*[1 -1 0 0; 0 0 1 -1]; N = 4;
    scen.x0 = repmat((c.lo+c.hi)/2, 1, N); scen.c = c.c*ones(1,N); scen.chat = scen.c;
    scen.wfun = @(t,x) W;
    scen.noise = @(k,x) struct('dpos',zeros(2,N),'dpsi',zeros(1,N),'du',zeros(1,N),'dv',zeros(1,N),'dr',zeros(1,N),'dz',zeros(1,N));
    o = sim_closed_loop(P, scen, ctrl, struct('T',20,'keep',true));
    ts = 4:4:20; ix = round(ts/P.dt_sim)+1;
    dW = squeeze(max(o.X(1,:,ix),[],2) - min(o.X(1,:,ix),[],2))';
    pW = squeeze(max(o.X(2,:,ix),[],2) - min(o.X(2,:,ix),[],2))';
    fprintf('cell %d (%s d0=%g loc=%g w=%g): d spread %s m; phi spread %s rad; max|phi| at 20 s %.3f (FOV %.3f)\n', i, M.T.water(i), M.T.d0_m(i), M.T.loc_m(i), c.w, ...
        mat2str(dW,3), mat2str(pW,3), max(abs(o.X(2,:,end))), P.FOV_R);
end
