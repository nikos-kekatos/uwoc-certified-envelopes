function [ok, info] = shield_check(P, S, z, tau0, sh)
% SHIELD_CHECK  Short-horizon reachability check used by the runtime shield.
%   From the ESTIMATE z = [d;e;u;v;r;c] and the declared error bounds, build the
%   set of possible true states; apply the proposed action tau0 for one control
%   period, then the fallback network (S = ctrl_sets(fallback_net)) for the rest
%   of the horizon sh.H, under currents |w| <= sh.w (box) and per-step noise.
%   ok = true iff every time-interval set stays inside ACE_O (c up to (1+crel)c).
%   Uses the same sound machinery as reach_cell. Guarantee is horizon-limited and
%   conditional on the declared bounds (sh.w, sh.loc); not a certificate beyond H.
t0 = tic;
loc = sh.loc; d = z(1); dlo = max(d - loc, 0.3);
eb = asin(min(loc/dlo,1));
% true state box: bearing phi is not measured directly; it is estimated from the
% position estimate as phi_hat with |phi - phi_hat| <= asin(loc/d)
rad = [loc; eb; eb + sh.epsPsi; sh.epsVel(:)];
xc  = [d; sh.phihat; z(2); z(3); z(4); z(5)];
X = polyZonotope(interval(xc - rad, xc + rad));
useSway = isfield(sh,'fbnet') && isfield(sh.fbnet,'nIn') && sh.fbnet.nIn == 7;
if useSway
    sys = sh.sysFb; options = sh.optionsFb; params = sh.paramsFb; S = ctrl_sets(sh.fbnet);
    tau0 = [tau0(:); 0];                               % proposed NN action, sway held
else
    sys = sh.sys; options = sh.options; params = sh.params;
end
chi = sh.c*(1+sh.crel);
Sel = [1 0 0 0 0 0; 0 0 1 0 0 0; 0 0 0 1 0 0; 0 0 0 0 1 0; 0 0 0 0 0 1; 0 0 0 0 0 0];
if useSway, Sel = [Sel; 0 1 0 0 0 0]; end
nC = round(sh.H/P.dt_ctrl); ok = true;
try
for k = 1:nC
    tk = (k-1)*P.dt_ctrl;
    if k == 1
        U = polyZonotope(tau0(:));                      % proposed action (a point)
    else
        X = aux_gi2dep(X);
        Ib = interval(X); lo = infimum(Ib);
        if lo(1) <= 0.3, ok = false; break; end
        rn = [loc; sh.epsPsi + asin(min(loc/lo(1),1)); sh.epsVel(:)];
        if useSway
            rn = [rn; asin(min(loc/lo(1),1))];
            Dn = [diag(rn(1:5)), zeros(5,1); zeros(1,6); zeros(1,5), rn(6)]; cz = [0;0;0;0;0;sh.c;0];
        else
            Dn = [diag(rn); zeros(1,numel(rn))]; cz = [0;0;0;0;0;sh.c];
        end
        nf = numel(rn); idmax = max([X.id; 0]);
        Z = polyZonotope(Sel*X.c + cz, [Sel*X.G, Dn], [], ...
            blkdiag(X.E, eye(nf)), [X.id; idmax+(1:nf)']);
        U = nn_set_eval(S, Z, sh.evo);
    end
    X = aux_gi2dep(X);
    params.R0 = aux_stack(X, U); params.tStart = tk; params.tFinal = tk + P.dt_ctrl;
    [Rti, Rtp] = aux_reach(sys, params, options);
    for j = 1:numel(Rti)
        I = interval(project(Rti{j}, 1:3)); a = infimum(I); b = supremum(I);
        emax = max(abs(a(3)),abs(b(3))); pmax = max(abs(a(2)),abs(b(2)));
        if emax > P.Theta_T || pmax > P.FOV_R || a(1) <= 0 || ...
                link_margin(P, b(1), min(pmax,pi/2-1e-6), emax, chi) < 0
            ok = false; break;
        end
    end
    if ~ok, break; end
    X = project(Rtp, 1:6);
end
catch
    ok = false;                                         % any failure => not certified
end
info.time = toc(t0);
end

function X = aux_gi2dep(X)
if isa(X,'polyZonotope') && ~isempty(X.GI)
    n = size(X.GI,2); idmax = max([X.id;0]);
    X = polyZonotope(X.c, [X.G, X.GI], [], blkdiag(X.E, eye(n)), [X.id; idmax+(1:n)']);
end
end

function R0 = aux_stack(X, U)
if isempty(U.id) || isempty(U.G)
    % constant input: stack point
    R0 = polyZonotope([X.c; U.c], [X.G; zeros(size(U.c,1), size(X.G,2))], ...
        [zeros(size(X.c,1), size(U.GI,2)); U.GI], X.E, X.id);
    return;
end
ids = unique([X.id; U.id]);
G = blkdiag(X.G, U.G);
E = zeros(numel(ids), size(G,2));
[~, lx] = ismember(X.id, ids); [~, lu] = ismember(U.id, ids);
E(lx, 1:size(X.E,2)) = X.E; E(lu, size(X.E,2)+1:end) = U.E;
GI = [zeros(size(X.c,1), size(U.GI,2)); U.GI];
R0 = polyZonotope([X.c; U.c], G, GI, E, ids);
end

function [Rti, Rtp] = aux_reach(sys, params, options)
tVec = params.tStart:options.timeStep:params.tFinal;
if abs(tVec(end) - params.tFinal) > 1e-12, tVec(end+1) = params.tFinal; end
Rti = cell(numel(tVec)-1,1); params.uTrans = center(params.U);
for i = 1:numel(tVec)-1
    options.timeStep = tVec(i+1) - tVec(i);
    if i == 1
        [Rnext, options] = initReach(sys, params.R0, params, options);
        Rnext.ti{1} = reduce(Rnext.ti{1}, options.reductionTechnique, options.zonotopeOrder);
        Rnext.tp{1}.set = reduce(Rnext.tp{1}.set, options.reductionTechnique, options.zonotopeOrder);
    else
        [Rnext, options] = post(sys, Rnext, params, options);
    end
    if numel(Rnext.ti) > 1, error('uwoc:split','split'); end
    Rti{i} = Rnext.ti{1};
end
Rtp = Rnext.tp{1}.set;
end
