% REPLAY_SIDEWAYS_WITNESS  Independent replay of every witness in
% results/diag70/sideways_cells.csv from its recorded (rounded) parameters: checks the
% declared bounds explicitly and re-simulates one trajectory with sim_closed_loop.
P = setup_paths(); L = load(fullfile(P.results,'phase2','actor_res_32.mat')); net = L.net;
M = load(fullfile(P.results,'opmap','opmap_res_32.mat')); ctrl = make_ctrl(net);
T = readtable(fullfile(P.results,'diag70','sideways_cells.csv'), 'TextType','string');
T = T(T.found_any == 1, :);
fid = fopen(fullfile(P.results,'diag70','witness_replay.txt'), 'w');
for q = 1:height(T)
    c = M.cells{T.cell(q)};
    x0 = eval(T.w_x0(q))'; vb = eval(T.w_vb(q))';
    dl = deg2rad(T.w_delta_deg(q)); sd = T.w_side(q); md = T.w_mode(q);
    lb = T.w_lb(q); la = deg2rad(T.w_lang_deg(q)); hb = T.w_hb(q);
    inBox = all(x0 >= c.lo - 1e-4 & x0 <= c.hi + 1e-4);
    okB = inBox && abs(lb) <= 1 && abs(hb) <= 1 && all(abs(vb) <= 1) && abs(dl) <= deg2rad(30) + 1e-9;
    x0 = min(max(x0, c.lo), c.hi);
    scen.x0 = x0; scen.c = 1.1*c.c; scen.chat = c.c;
    if md == "track"
        scen.wfun = @(t,x) [c.w*sin(dl); c.w*sd*cos(dl)];
    else
        Wx = c.w*sin(dl); Wy = c.w*sd*cos(dl);
        scen.wfun = @(t,x) [Wx*cos(x(2)) + Wy*sin(x(2)); -Wx*sin(x(2)) + Wy*cos(x(2))];
    end
    scen.noise = @(k,x) struct('dpos', c.loc*lb*[cos(x(2)+pi/2+la); sin(x(2)+pi/2+la)], ...
        'dpsi', c.epsPsi*hb, 'du', c.epsVel(1)*vb(1), 'dv', c.epsVel(2)*vb(2), 'dr', c.epsVel(3)*vb(3), 'dz', 0);
    o = sim_closed_loop(P, scen, ctrl, struct('T', 20, 'keep', true));
    [pm, ip] = max(abs(o.X(2,1,:)));
    wn = norm(scen.wfun(0, x0));
    s = sprintf(['cell %d (%s d0=%g loc=%g w=%g) mode %s: bounds ok %d, |w| = %.4f (w0 %.4f), |dpos| = %.3f (loc %.3f), ' ...
        'rho %.3f deg, first violation %s at %.2f s, max|phi| %.4f rad at %.2f s (FOV %.4f)\n'], ...
        T.cell(q), T.water(q), T.d0_m(q), T.loc_m(q), T.w_mps(q), md, okB, wn, c.w, abs(lb)*c.loc, c.loc, ...
        o.rho, string(o.firstProv), o.firstOut, pm, o.t(ip), P.FOV_R);
    fprintf('%s', s); fprintf(fid, '%s', s);
end
fclose(fid);
