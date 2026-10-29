function res = reach_cell(P, net, cellc, ro)
% REACH_CELL  Sound closed-loop reachability (CORA) of the NN-controlled planar
% AUV for one operating cell, checked against the ACE outage set.
%
%   net   : actor struct (train_actor / fallback_net), input z=[d;e;u;v;r;c_hat]
%   cellc : struct with fields
%           lo, hi   (6x1) initial box for [d;phi;e;u;v;r]
%           c        nominal extinction (controller input c_hat = c)
%           crel     relative uncertainty of the true c (default P.c_rel_unc)
%           loc      localisation error bound [m] (per control step)
%           epsPsi   heading error bound [rad]
%           w        current bound [m/s]  (w_r, w_t in [-w, w], time-varying)
%           T        horizon [s];  Te establishment deadline [s]
%   ro    : reach options (timeStep, zonotopeOrder, taylorTerms, tmax, polyMethod)
%
% Measurement noise: at each control step the NN input is z = S x + n with
%   |n_d| <= loc, |n_e| <= epsPsi + asin(min(loc/d_lo,1)), |n_u|,|n_v|,|n_r| <= eps,
% added as NEW independent factors of the polynomial zonotope (sound for any
% noise sequence inside the bounds). The current enters as a time-varying
% bounded input of the continuous-time plant.
%
% Properties (all w.r.t. the over-approximation R):
%   maint : G[0,T] ACE_O          (R(t) inside ACE_O for all t)
%   est   : exists t* <= Te with R([t*,T]) inside ACE_O (establish, then maintain)
%   robust: G[0,T] ACE_robust     (margin >= M_robust and geometry OK)
% Outcome per property: true = CERTIFIED; false = not certified (the cell is then
% Falsified only if a concrete trajectory is found elsewhere, else Inconclusive).

t0 = tic;
if ~isfield(cellc,'crel'), cellc.crel = P.c_rel_unc; end
if ~isfield(cellc,'Te'), cellc.Te = 5; end
if ~isfield(cellc,'epsVel'), cellc.epsVel = [P.eps_u; P.eps_v; P.eps_r]; end
if ~isfield(ro,'trace'), ro.trace = false; end
if ~isfield(ro,'tmax'), ro.tmax = 600; end
chi = cellc.c*(1+cellc.crel);
nC  = round(cellc.T/P.dt_ctrl);

res = struct('status','ok','maint',false,'est',false,'robust',false, ...
    'Mlow',inf,'possTx',false,'possRx',false,'possP',false, ...
    'tFirstViol',nan,'provFirst','', 'tReached',0,'runtime',nan, ...
    'width_e_final',nan,'width_d_final',nan,'width_phi_final',nan, ...
    'lastBad',-inf,'nSteps',0,'boxes',zeros(0,9));

% ---- system and options (derivatives are generated once and cached by CORA) ----
if ~isfield(cellc,'model'), cellc.model = '2d'; end
is3 = strcmp(cellc.model,'3d');
nX = numel(cellc.lo);                       % 6 (planar) or 9 (3-D reduced)
% optional (campaign E): current as states (w_r, w_t) = polar components of the world
% current W, with bounded world rate |dW_i/dt| <= cellc.rho (rho = 0: constant current).
% The initial current ranges over the octagon enclosing the disk |w| <= w0. After every
% control period the carried current set is tested against the octagon; if it may leave it
% (or always, with cellc.rateReset = 'always'), the current coordinates are replaced by fresh
% independent factors spanning the octagon (sound: the true current lies in the disk).
% See results/slowcur/METHOD.md. Default (field absent) unchanged.
isRate = isfield(cellc,'curModel') && strcmp(cellc.curModel,'rate') && ~is3 && ~(isfield(net,'nIn') && net.nIn == 7);
if isRate
    nX = nX + 2; res.nReset = 0;
    % states (w_r, w_t) = polar components of W (aug_dyn_rate); rate input nu = R(phi) mu lies
    % in the disk of radius sqrt(2) rho, enclosed by the octagon of inradius sqrt(2) rho
    sys = nonlinearSys(['uwoc2d_ratep_' P.dampModel], @aug_dyn_rate, 10, 5);
    if strcmp(P.dampModel,'bilinear'), uc = P.qD(1:3)'/2; ur = P.qD(1:3)'/2; else, uc = zeros(3,1); ur = P.qErr(1:3)'; end
    thO = (0:3)*pi/4; GwO = cellc.w*tan(pi/8)*[cos(thO); sin(thO)];   % octagon generators
    if cellc.rho > 0, Gnu = sqrt(2)*cellc.rho*tan(pi/8)*[cos(thO); sin(thO)]; else, Gnu = zeros(2,1); end
    params.U = zonotope([0;0; uc], blkdiag(Gnu, diag(ur)));
    nO = [cos(thO); sin(thO)];                                         % octagon edge normals: |nO_j'W| <= w0
    rTol = 0; if isfield(cellc,'rateResetTol'), rTol = cellc.rateResetTol; end
    rAlways = isfield(cellc,'rateReset') && strcmp(cellc.rateReset,'always');
elseif is3
    sys = nonlinearSys(['uwoc3d_v2_' P.dampModel], @aug_dyn3, 11, 8);
    if strcmp(P.dampModel,'bilinear'), uc = P.qD(:)/2; ur = P.qD(:)/2; else, uc = zeros(4,1); ur = P.qErr(:); end
    params.U = zonotope([0;0;0;0; uc], diag([cellc.w; cellc.w; cellc.wv; cellc.locz; ur]));
elseif isfield(net,'nIn') && net.nIn == 7
    % sway-capable fallback: 3 commands, own damping envelope P.qXfb
    sys = nonlinearSys('uwoc2d_v2_fb', @aug_dyn_fb, 9, 5);
    qE = P.qpoly.err*P.qXfb.^2.*P.qDq;
    params.U = zonotope(zeros(5,1), diag([cellc.w; cellc.w; qE(1:3)']));
else
    sys = nonlinearSys(['uwoc2d_v2_' P.dampModel], @aug_dyn, 8, 5);
    if strcmp(P.dampModel,'bilinear'), uc = P.qD(1:3)'/2; ur = P.qD(1:3)'/2; else, uc = zeros(3,1); ur = P.qErr(1:3)'; end
    params.U = zonotope([0;0; uc], diag([cellc.w; cellc.w; ur]));
end
% optional (campaign C): enclose the current disk |w| <= w0 (polar components w_r, w_t)
% by an octagonal zonotope (4 generators of length w0 tan(pi/8); the octagon contains the
% disk) instead of the box [-w0, w0]^2 (default 'box', so old results are reproducible)
if isfield(cellc,'curModel') && strcmp(cellc.curModel,'disk') && ~is3 && cellc.w > 0
    Gu = params.U.G; Gu = Gu(:, ~any(Gu(1:2,:) ~= 0, 1));
    th = (0:3)*pi/4; Gw = cellc.w*tan(pi/8)*[cos(th); sin(th)];
    params.U = zonotope(params.U.c, [[Gw; zeros(size(Gu,1)-2, 4)], Gu]);
end
params.tStart = 0; params.tFinal = P.dt_ctrl;
nOut = numel(net.sat);
params.R0 = polyZonotope(interval([cellc.lo; zeros(nX-numel(cellc.lo)+nOut,1)], [cellc.hi; zeros(nX-numel(cellc.lo)+nOut,1)]));
options.timeStep = ro.timeStep;
options.taylorTerms = ro.taylorTerms;
options.zonotopeOrder = ro.zonotopeOrder;
options.alg = getfield_def(ro,'alg','lin');
options.tensorOrder = getfield_def(ro,'tensorOrder',2);
if strcmp(options.alg,'poly'), options.polyZono = struct('maxDepGenOrder',50,'maxPolyZonoRatio',0.05,'restructureTechnique','reducePca'); options.errorOrder = 10; options.intermediateOrder = 50; end
[params, options] = validateOptions(sys, params, options, 'FunctionName', 'reach');
derivatives(sys, options);
for i = 1:(options.taylorTerms+1), options.factor(i) = options.timeStep^i/factorial(i); end
evo = struct('nn', struct('poly_method', ro.polyMethod));
evo = nnHelper.validateNNoptions(evo);
evo.nn.add_approx_error_to_GI = true;

X = polyZonotope(interval(cellc.lo, cellc.hi));
if isRate
    % initial set: cell box x octagon (W0 independent of the box), dependent factors
    hw = (cellc.hi - cellc.lo)/2; G0 = diag(hw); G0 = G0(:, hw > 0);
    if cellc.w > 0, Gx = blkdiag(G0, GwO); else, Gx = [G0; zeros(2, size(G0,2))]; end
    X = polyZonotope([(cellc.lo + cellc.hi)/2; 0; 0], Gx);
end
C = ctrl_sets(net);
Sel = [[1 0 0 0 0 0; 0 0 1 0 0 0; 0 0 0 1 0 0; 0 0 0 0 1 0; 0 0 0 0 0 1; 0 0 0 0 0 0], zeros(6, nX-6)];
use7 = isfield(net,'nIn') && net.nIn == 7;
if use7, Sel = [Sel; 0 1 0 0 0 0 zeros(1, nX-6)]; end   % bearing estimate for the sway fallback
lastBad = -inf;     % end time of the last time-interval set that may leave ACE_O
try
for k = 1:nC
    if toc(t0) > ro.tmax, res.status = 'timeout'; break; end
    tk = (k-1)*P.dt_ctrl;
    X  = aux_gi2dep(X);
    Ib = interval(X); dlo = infimum(Ib); dlo = dlo(1);
    if dlo <= 0.2, res.status = 'explosion'; break; end
    rn = [cellc.loc; cellc.epsPsi + asin(min(cellc.loc/dlo,1)); cellc.epsVel(:)];
    % NN input set z = Sel x + [0..;c_hat] + noise (noise = fresh dependent factors)
    if use7
        rn = [rn; asin(min(cellc.loc/dlo,1))];                 % bearing-estimate error
        Dn = [diag(rn(1:5)), zeros(5,1); zeros(1,6); zeros(1,5), rn(6)];
        cz = [0;0;0;0;0;cellc.c;0];
    else
        Dn = [diag(rn); zeros(1,numel(rn))]; cz = [0;0;0;0;0;cellc.c];
    end
    if isfield(cellc,'locModel') && strcmp(cellc.locModel,'disk') && ~use7
        % position error in a disk |delta| <= loc, enclosed by an octagonal zonotope
        % (4 generators of length loc*tan(pi/8)); range error = delta_r + [0, loc^2/(2(d-loc))],
        % bearing error = s*delta_t with s in [s_min, s_max] (atan(x) <= x; atan(x)/x >= atan(x0)/x0)
        dhi = supremum(Ib); dhi = dhi(1); L0 = cellc.loc; dl = max(dlo - L0, 0.2);
        smax = 1/dl; x0 = L0/(dhi + L0); smin = (atan(x0)/x0)/(dhi + L0); sc = (smax+smin)/2;
        th = (0:3)*pi/4; a = L0*tan(pi/8); Go = a*[cos(th); sin(th)];
        epsD = L0^2/(2*dl); epsE = L0*(smax - smin)/2;
        Gn = zeros(6, 4+3+3);
        Gn(1,1:4) = Go(1,:); Gn(2,1:4) = sc*Go(2,:);       % coupled radial / bearing parts
        Gn(1,5) = epsD/2; Gn(2,6) = epsE; Gn(2,7) = cellc.epsPsi;
        Gn(3,8) = cellc.epsVel(1); Gn(4,9) = cellc.epsVel(2); Gn(5,10) = cellc.epsVel(3);
        Dn = Gn; cz = cz + [epsD/2; zeros(5,1)];
        rn = zeros(size(Gn,2),1);                              % (only its length is used below)
    end
    nf  = size(Dn,2); idmax = max([X.id; 0]);
    Zc  = Sel*X.c + cz;
    ZG  = [Sel*X.G, Dn];
    ZE  = blkdiag(X.E, eye(nf));
    Z   = polyZonotope(Zc, ZG, [], ZE, [X.id; idmax+(1:nf)']);
    U   = nn_set_eval(C, Z, evo);
    R0  = aux_stack(X, U);
    % plant reachability over [tk, tk+dt] with tau held constant
    params.R0 = R0; params.tStart = tk; params.tFinal = tk + P.dt_ctrl;
    [Rti, Rtp] = aux_reach(sys, params, options);
    % ---- check the ACE on every time-interval set ----
    for j = 1:numel(Rti)
        if is3
            I  = interval(project(Rti{j}, 1:9));
            [pTx, pRx, Ml] = ace_box3(P, I, chi, cellc.alphaR);
            lo = infimum(I); hi = supremum(I); lo = lo(1:3); hi = hi(1:3);
        else
        I  = interval(project(Rti{j}, 1:3));
        lo = infimum(I); hi = supremum(I);
        emax = max(abs(lo(3)),abs(hi(3))); pmax = max(abs(lo(2)),abs(hi(2)));
        dmax = hi(1);
        pTx = emax > P.Theta_T; pRx = pmax > P.FOV_R;
        if lo(1) <= 0 || pmax >= pi/2
            Ml = -inf;
        else
            Ml = link_margin(P, dmax, pmax, emax, chi);
        end
        end
        pP = Ml < 0;
        res.Mlow = min(res.Mlow, Ml);
        if isfield(ro,'storeBoxes') && ro.storeBoxes, res.boxes(end+1,:) = [tk+[j-1 j]*options.timeStep, lo', hi', Ml]; end
        tint = tk + [j-1, j]*options.timeStep;
        if pTx || pRx || pP
            if isnan(res.tFirstViol)
                res.tFirstViol = tint(1);
                nm = {'Tx','Rx','P'}; res.provFirst = strjoin(nm([pTx pRx pP]), '+');
            end
            lastBad = tint(2);
        end
        if tint(1) <= cellc.T
            res.possTx = res.possTx || pTx; res.possRx = res.possRx || pRx; res.possP = res.possP || pP;
        end
        if Ml < P.M_robust || pTx || pRx, res.robustBad = true; end
    end
    X = project(Rtp, 1:nX);
    % validity of the damping-coefficient model: |u|,|v|,|r| (and |wz|) within P.qX
    rgx = zeros(1, 3 + (nX == 9));
    for jj = 1:numel(Rti)
        Ir = interval(project(Rti{jj}, 1:nX)); ilo = infimum(Ir); ihi = supremum(Ir);
        rr = max(abs([ilo(4:6) ihi(4:6)]),[],2)';
        if nX == 9, rr(4) = max(abs([ilo(8) ihi(8)])); end
        rgx = max(rgx, rr);
    end
    if use7, qXc = P.qXfb; else, qXc = P.qX; end
    if any(rgx > qXc(1:numel(rgx))), res.status = 'model-range'; break; end
    if isRate && cellc.w > 0 && (cellc.rho > 0 || rAlways)
        % magnitude bound: if the carried current set may leave the octagon, re-enclose it by
        % the octagon with fresh independent factors (the x part and its factors are kept).
        % rAlways (cellc.rateReset = 'always'): re-enclose after every period (also sound).
        Wp = project(X, 7:8); out = rAlways;
        for jn = 1:4
            In = interval(nO(:,jn)'*Wp);
            out = out || supremum(In) > cellc.w*(1+rTol) || infimum(In) < -cellc.w*(1+rTol);
        end
        if out
            Xc = X.c; Xc(7:8) = 0; XG = X.G; XG(7:8,:) = 0;
            if isempty(X.GI), XGI = zeros(nX,0); else, XGI = X.GI; XGI(7:8,:) = 0; end
            XGI = [XGI, [zeros(6,4); GwO]];
            X = polyZonotope(Xc, XG, XGI, X.E, X.id);
            res.nReset = res.nReset + 1;
        end
    end
    if ro.trace, Ib2 = interval(X); res.trace(k,:) = [tk+P.dt_ctrl, (supremum(Ib2)-infimum(Ib2))', size(X.G,2), toc(t0)]; end
    res.tReached = tk + P.dt_ctrl; res.nSteps = k;
    % early exit: both properties already impossible to certify
    if lastBad > cellc.Te, res.status = 'violated'; break; end
end
catch ME
    res.status = ['error:' ME.identifier];
    res.errmsg = ME.message;
end
res.lastBad = lastBad;
complete = res.tReached >= cellc.T - 1e-9;
res.maint  = complete && isinf(lastBad) && strcmp(res.status,'ok');
res.est    = complete && lastBad <= cellc.Te && lastBad < cellc.T && strcmp(res.status,'ok');
res.robust = res.maint && ~isfield(res,'robustBad');
try
    Ib = interval(X); w = supremum(Ib) - infimum(Ib);
    res.width_d_final = w(1); res.width_phi_final = w(2); res.width_e_final = w(3);
catch
end
res.runtime = toc(t0);
end

% -------------------------------------------------------------------------
function X = aux_gi2dep(X)
% turn independent generators into dependent factors (keeps correlation with
% the NN output in the next stacking step)
if ~isempty(X.GI)
    n = size(X.GI,2); idmax = max([X.id;0]);
    X = polyZonotope(X.c, [X.G, X.GI], [], blkdiag(X.E, eye(n)), [X.id; idmax+(1:n)']);
end
end

function R0 = aux_stack(X, U)
% stack state set X (no GI) and NN output U, merging factor ids
ids = unique([X.id; U.id]);
G = blkdiag(X.G, U.G);
E = zeros(numel(ids), size(G,2));
[~, lx] = ismember(X.id, ids); [~, lu] = ismember(U.id, ids);
E(lx, 1:size(X.E,2)) = X.E;
E(lu, size(X.E,2)+1:end) = U.E;
GI = [zeros(size(X.c,1), size(U.GI,2)); U.GI];
R0 = polyZonotope([X.c; U.c], G, GI, E, ids);
end

function [Rti, Rtp] = aux_reach(sys, params, options)
% initReach/post loop (as in CORA neurNetContrSys/reach, aux_reachability)
tVec = params.tStart:options.timeStep:params.tFinal;
if abs(tVec(end) - params.tFinal) > 1e-12, tVec(end+1) = params.tFinal; end
Rti = cell(numel(tVec)-1,1);
params.uTrans = center(params.U);
for i = 1:numel(tVec)-1
    options.timeStep = tVec(i+1) - tVec(i);
    if i == 1
        [Rnext, options] = initReach(sys, params.R0, params, options);
        Rnext.ti{1} = reduce(Rnext.ti{1}, options.reductionTechnique, options.zonotopeOrder);
        Rnext.tp{1}.set = reduce(Rnext.tp{1}.set, options.reductionTechnique, options.zonotopeOrder);
    else
        [Rnext, options] = post(sys, Rnext, params, options);
    end
    if numel(Rnext.ti) > 1
        error('uwoc:split','CORA split the set; not supported here');
    end
    Rti{i} = Rnext.ti{1};
end
Rtp = Rnext.tp{1}.set;
end

function v = getfield_def(s, f, d)
if isfield(s, f), v = s.(f); else, v = d; end
end
