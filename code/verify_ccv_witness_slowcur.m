% VERIFY_CCV_WITNESS_SLOWCUR  Client-side re-search and bound check of the CCV tiles that
% campaign E (R0) falsified while the reference left them Inconclusive. Cross-entropy
% falsifier in the R0 family (constant world current, |W| <= w0), seeds 1..5 until a witness
% is found; the witness is then replayed with a 4x finer simulation step.
% Output: results/slowcur/ccv_witness_check.txt
P = setup_paths(); maxNumCompThreads(2);
L = load(fullfile(P.results,'phase2','actor_res_32.mat')); net = L.net; ctrl = make_ctrl(net);
tiles = {1, 2.25, -15; 1, 2.25, 15; 2, 2.75, -15};          % water index, d0 centre, phi0 centre (deg)
fo = struct('pop',200,'iters',25,'elite',20,'tol',0.01);
fid = fopen(fullfile(P.results,'slowcur','ccv_witness_check.txt'),'w');
for k = 1:size(tiles,1)
    wi = tiles{k,1}; d0 = tiles{k,2}; p0 = tiles{k,3};
    c = make_cell(P, wi, d0, deg2rad(P.ccv.e0), 0.1, P.ccv.w);
    c.lo(1) = d0 - 0.25; c.hi(1) = d0 + 0.25; c.lo(2) = deg2rad(p0 - 5); c.hi(2) = deg2rad(p0 + 5);
    c.curModel = 'rate'; c.rho = 0;
    for s = 1:5
        rng(s); F = falsify_cell(P, ctrl, c, fo);
        if F.found, break; end
    end
    th = F.theta;
    [wf, info] = cur_rate_wfun(c, [th(8:10); th(20:21)], 'fals');
    x0 = c.lo + (c.hi - c.lo).*th(1:6);
    sc.x0 = x0; sc.c = c.c*(1 + c.crel*(2*th(7)-1)); sc.chat = c.c; sc.wfun = wf;
    br = c.loc*th(11); hb = c.epsPsi*(2*th(14)-1); vb = c.epsVel(:).*(2*th(17:19)-1);
    ba = 2*pi*th(12); bo = 0.5*(2*th(13)-1); Tp = 1 + 39*th(15); ph = 2*pi*th(16);
    sc.noise = @(kk,x) aux_noise(kk, x, br, ba, bo, hb, Tp, ph, vb, P);
    P2 = P; P2.dt_sim = P.dt_sim/4;
    o1 = sim_closed_loop(P, sc, ctrl, struct('T', c.T)); o2 = sim_closed_loop(P2, sc, ctrl, struct('T', c.T));
    fprintf(fid, '%s d0 %.2f phi0 %+g deg: seed %d, found %d, rho %.4f (replay %.4f, fine step %.4f), predicate %d at %.2f s; |W| = %.4f <= w0 %.3f constant; |dpos| %.3f <= %.2f; x0 in box %d; c/c_nom %.3f\n', ...
        P.water.name{wi}, d0, p0, s, F.found, F.rho, o1.rho, o2.rho, o1.firstProv, o1.firstOut, info.m0, c.w, br, c.loc, ...
        all(x0 >= c.lo & x0 <= c.hi), sc.c/c.c);
end
fclose(fid); type(fullfile(P.results,'slowcur','ccv_witness_check.txt'));

function n = aux_noise(k, x, br, ba, bo, hb, Tp, ph, vb, P)
t = (k-1)*P.dt_ctrl;
s = sign(sin(2*pi*t./Tp + ph)); s(s==0) = 1;
ang = x(2,:) + ba + bo*t;
n.dpos = [s.*br.*cos(ang); s.*br.*sin(ang)];
n.dpsi = s.*hb; n.du = s.*vb(1,:); n.dv = s.*vb(2,:); n.dr = s.*vb(3,:); n.dz = 0;
end
