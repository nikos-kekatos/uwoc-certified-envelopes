% REPLAY_SLOWCUR_WITNESS  Reproduce and check a witness found by the regime falsifier of
% campaign E (run_slowcur.m), e.g. cell 95 under R0. Workspace: rwJob (job index in the
% regime table), rwReg ('R0'|'R1'). Re-runs falsify_cell with the campaign seed
% rng(7500 + q), checks every declared bound of the witness explicitly, replays it with the
% simulation step of the campaign and with a 4x finer step, and writes
% results/slowcur/witness_<reg>_cell<cell>.txt.
if ~exist('rwReg','var'), rwReg = 'R0'; end
P = setup_paths(); maxNumCompThreads(1);
L = load(fullfile(P.results,'phase2','actor_res_32.mat')); net = L.net; ctrl = make_ctrl(net);
S = slowcur_cells(P); M = S.M;
T = readtable(fullfile(P.results,'slowcur',['slowcur_' rwReg '.csv']), 'TextType','string');
q = find(T.job == rwJob); i = T.cell(q);
c = M.cells{i}; c.curModel = 'rate'; rf = struct('R0',0,'R1',pi/20); c.rho = rf.(rwReg)*c.w;
fo = struct('pop',200,'iters',25,'elite',20,'tol',0.01);
rng(7500 + q); F = falsify_cell(P, ctrl, c, fo);
th = F.theta; o6 = 0;
fid = fopen(fullfile(P.results,'slowcur',sprintf('witness_%s_cell%d.txt', rwReg, i)), 'w');
pr = @(varargin) fprintf(fid, varargin{:});
pr('Campaign E witness, regime %s, cell %d (%s, d0 = %g m, loc = %g m, w0 = %g m/s), job %d, seed rng(%d)\n', ...
    rwReg, i, M.T.water(i), M.T.d0_m(i), c.loc, c.w, rwJob, 7500 + q);
pr('falsify_cell: found %d, rho %.4f, first predicate %d (1 Tx, 2 Rx, 3 P), first violation %.2f s\n', F.found, F.rho, F.prov, F.tOut);
% ---- explicit bound checks (parameter map of falsify_cell/theta2scen and cur_rate_wfun) ----
x0 = c.lo + (c.hi - c.lo).*th(1:6);
cTrue = c.c*(1 + c.crel*(2*th(7)-1));
[wf, info] = cur_rate_wfun(c, [th(8:10); th(20:21)], 'fals');
br = c.loc*th(11); hb = c.epsPsi*(2*th(14)-1); vb = c.epsVel(:).*(2*th(17:19)-1);
tt = 0:0.01:c.T; W = zeros(2, numel(tt));
for k = 1:numel(tt), W(:,k) = wf(tt(k), zeros(6,1)); end        % phi = 0: polar = world frame
rate = max(abs(diff(W,1,2)),[],'all')/0.01;
pr('x0 = %s (inside the cell box: %d)\n', mat2str(x0', 4), all(x0 >= c.lo - 1e-12 & x0 <= c.hi + 1e-12));
pr('true c = %.4f (nominal %.4f, bound +-%g %%)\n', cTrue, c.c, 100*c.crel);
pr('current: m0 = %.4f m/s (w0 %.4f), direction %.1f deg, max |W| = %.4f, max |dW_i/dt| = %.2e (rho %.2e), constant: %d\n', ...
    info.m0, c.w, rad2deg(mod(info.a0, 2*pi)), max(vecnorm(W)), rate, c.rho, max(abs(W - W(:,1)),[],'all') < 1e-12);
pr('localisation bias |dpos| = %.4f m (bound %.4f), heading bias %.3f deg (bound %.3f), velocity biases %s (bounds %s)\n', ...
    br, c.loc, rad2deg(hb), rad2deg(c.epsPsi), mat2str(vb', 3), mat2str(c.epsVel', 3));
pr('square-wave period %.2f s, bias direction offset %.1f deg, rotation %.3f rad/s\n', 1 + 39*th(15), rad2deg(2*pi*th(12)), 0.5*(2*th(13)-1));
% ---- replay: campaign step and 4x finer step ----
rng(1); sc = struct();
sc.x0 = x0; sc.c = cTrue; sc.chat = c.c; sc.wfun = wf;
ang0 = 2*pi*th(12); bo = 0.5*(2*th(13)-1); Tp = 1 + 39*th(15); ph = 2*pi*th(16);
sc.noise = @(k,x) aux_noise(k, x, br, ang0, bo, hb, Tp, ph, vb, P);
o1 = sim_closed_loop(P, sc, ctrl, struct('T', c.T, 'keep', true));
P2 = P; P2.dt_sim = P.dt_sim/4;
o2 = sim_closed_loop(P2, sc, ctrl, struct('T', c.T));
pr('replay (dt_sim %.4f s): rho %.4f, first predicate %d, first violation %.2f s\n', P.dt_sim, o1.rho, o1.firstProv, o1.firstOut);
pr('replay (dt_sim %.4f s): rho %.4f, first predicate %d, first violation %.2f s\n', P2.dt_sim, o2.rho, o2.firstProv, o2.firstOut);
pr('max |e(t)| = %.3f deg (Tx half-angle %.1f), max |phi(t)| = %.3f deg (FOV %.1f)\n', ...
    rad2deg(max(abs(o1.X(3,:,:)),[],'all')), rad2deg(P.Theta_T), rad2deg(max(abs(o1.X(2,:,:)),[],'all')), rad2deg(P.FOV_R));
pr('admissible under the reference box model as well: a constant world current of magnitude <= w0 has polar components in the disk, inside [-w0, w0]^2\n');
fclose(fid);
type(fullfile(P.results,'slowcur',sprintf('witness_%s_cell%d.txt', rwReg, i)));

function n = aux_noise(k, x, br, ba, bo, hb, Tp, ph, vb, P)
% same family as falsify_cell/noisefun (square-wave biases, bias direction relative to the LOS)
t = (k-1)*P.dt_ctrl;
s = sign(sin(2*pi*t./Tp + ph)); s(s==0) = 1;
ang = x(2,:) + ba + bo*t;
n.dpos = [s.*br.*cos(ang); s.*br.*sin(ang)];
n.dpsi = s.*hb; n.du = s.*vb(1,:); n.dv = s.*vb(2,:); n.dr = s.*vb(3,:); n.dz = 0;
end
