function R = chain_cell(P, net, cellc, co)
% CHAIN_CELL  Chained short-window certification of one planar operating cell
% (method and soundness argument: results/chain/METHOD.md).
%
%   co.H        window length [s] (multiple of P.dt_ctrl)
%   co.Tgoal    horizon to certify [s] (default P.T = 20)
%   co.setType  'box' (interval hull) or 'par' (order-1 PCA parallelotope)
%   co.margin   relative inflation of each re-start set (default 0.05)
%   co.maxWin   max number of windows (>= ceil(Tgoal/H); extra windows only try closure)
%   co.ro       reach options (as reach_cell)
%
% A_0 = initial box; window k: reach from A_k over [0,H] (ACE + envelope checked on
% every time-interval set) -> end set E_k; A_{k+1} = inflate(simp(E_k)).
%   cert20  : windows 0..N-1 OK with N*H >= Tgoal
%   certInf : additionally E_k inside some A_j (j <= k): certified for every horizon
% Only the planar 6-state model with a 6-input actor is supported.
if ~isfield(co,'Tgoal'), co.Tgoal = P.T; end
if ~isfield(co,'setType'), co.setType = 'box'; end
if ~isfield(co,'margin'), co.margin = 0.05; end
nW = round(co.Tgoal/co.H);
if ~isfield(co,'maxWin'), co.maxWin = nW; end
ro = co.ro; if ~isfield(ro,'tmax'), ro.tmax = 900; end
if ~isfield(cellc,'crel'), cellc.crel = P.c_rel_unc; end
if ~isfield(cellc,'epsVel'), cellc.epsVel = [P.eps_u; P.eps_v; P.eps_r]; end
assert(abs(co.H/P.dt_ctrl - round(co.H/P.dt_ctrl)) < 1e-9, 'H must be a multiple of dt_ctrl');
assert(numel(cellc.lo) == 6 && ~(isfield(net,'nIn') && net.nIn ~= 6), 'planar res-actor only');
t0 = tic;

% ---- CORA system (same as reach_cell, planar branch) ----
sys = nonlinearSys(['uwoc2d_v2_' P.dampModel], @aug_dyn, 8, 5);
if strcmp(P.dampModel,'bilinear'), uc = P.qD(1:3)'/2; ur = P.qD(1:3)'/2; else, uc = zeros(3,1); ur = P.qErr(1:3)'; end
params.U = zonotope([0;0; uc], diag([cellc.w; cellc.w; ur]));
params.tStart = 0; params.tFinal = P.dt_ctrl;
nOut = numel(net.sat);
params.R0 = polyZonotope(interval([cellc.lo; zeros(nOut,1)], [cellc.hi; zeros(nOut,1)]));
options.timeStep = ro.timeStep; options.taylorTerms = ro.taylorTerms;
options.zonotopeOrder = ro.zonotopeOrder; options.alg = 'lin'; options.tensorOrder = 2;
[params, options] = validateOptions(sys, params, options, 'FunctionName', 'reach');
derivatives(sys, options);
for i = 1:(options.taylorTerms+1), options.factor(i) = options.timeStep^i/factorial(i); end
evo = struct('nn', struct('poly_method', ro.polyMethod));
evo = nnHelper.validateNNoptions(evo);
evo.nn.add_approx_error_to_GI = true;
C = ctrl_sets(net);
env = struct('sys',sys,'params',params,'options',options,'evo',evo,'C',C, ...
    'chi', cellc.c*(1+cellc.crel), 'nP', round(co.H/P.dt_ctrl));

% ---- chain ----
A = {struct('type','box','c',(cellc.lo+cellc.hi)/2,'G',diag((cellc.hi-cellc.lo)/2))};
R = struct('status','ok','reason','','cert20',false,'certInf',false,'closeK',nan,'closeJ',nan, ...
    'nWinOK',0,'tCert',0,'Mlow',inf,'provFirst','','tFail',nan,'runtime',nan, ...
    'winTime',zeros(1,0),'winWidth',zeros(0,6),'startWidth',zeros(0,6),'contOK',true, ...
    'close5K',nan,'close5J',nan,'phiEnd',zeros(0,2));
for k = 1:co.maxWin
    if toc(t0) > ro.tmax, R.status = 'timeout'; break; end
    W = aux_window(P, env, cellc, A{k}, ro.tmax - toc(t0));
    R.winTime(end+1) = W.runtime; R.Mlow = min(R.Mlow, W.Mlow);
    R.startWidth(end+1,:) = 2*sum(abs(A{k}.G),2)';
    if ~strcmp(W.status,'ok')
        R.status = W.status; R.provFirst = W.provFirst; R.tFail = (k-1)*co.H + W.tFail;
        break;
    end
    R.nWinOK = k; R.tCert = k*co.H;
    Ib = interval(W.E); R.winWidth(end+1,:) = (supremum(Ib)-infimum(Ib))';
    R.phiEnd(end+1,:) = [infimum(Ib(2)), supremum(Ib(2))];
    % diagnostic only (not a certificate): closure of the non-bearing part [d e u v r]
    if isnan(R.close5K)
        for j = k:-1:1
            if strcmp(A{j}.type,'box')
                lo5 = A{j}.c - sum(abs(A{j}.G),2); hi5 = A{j}.c + sum(abs(A{j}.G),2); q = [1 3 4 5 6];
                if all(infimum(Ib(q)) >= lo5(q)) && all(supremum(Ib(q)) <= hi5(q)), R.close5K = k; R.close5J = j; break; end
            end
        end
    end
    % closure: E_k inside an earlier (or the current) start set
    for j = k:-1:1
        if aux_inside(W.E, A{j}), R.certInf = true; R.closeK = k; R.closeJ = j; break; end
    end
    if R.certInf, break; end
    if R.tCert >= co.Tgoal - 1e-9 && k >= co.maxWin, break; end
    A{k+1} = aux_simplify(W.E, co.setType, co.margin);
    if ~aux_inside(W.E, A{k+1}), R.contOK = false; R.status = 'containment'; break; end  % must not happen
end
R.cert20 = R.tCert >= co.Tgoal - 1e-9 || R.certInf;
if R.cert20, R.reason = ''; else, R.reason = R.status; end
R.runtime = toc(t0);
end

% =========================================================================
function W = aux_window(P, env, cellc, A, tleft)
% one window of env.nP control periods from the start set A (dependent factors)
tw = tic;
W = struct('status','ok','E',[],'Mlow',inf,'provFirst','','tFail',nan,'runtime',nan);
n = size(A.G,2);
X = polyZonotope(A.c, A.G, [], eye(n), (1:n)');
Sel = [1 0 0 0 0 0; 0 0 1 0 0 0; 0 0 0 1 0 0; 0 0 0 0 1 0; 0 0 0 0 0 1; 0 0 0 0 0 0];
params = env.params; options = env.options; tk = 0;
try
    for k = 1:env.nP
        if toc(tw) > tleft, W.status = 'timeout'; W.tFail = (k-1)*P.dt_ctrl; break; end
        tk = (k-1)*P.dt_ctrl;
        X  = aux_gi2dep(X);
        Ib = interval(X); dlo = infimum(Ib); dlo = dlo(1);
        if dlo <= 0.2, W.status = 'explosion'; W.tFail = tk; break; end
        rn = [cellc.loc; cellc.epsPsi + asin(min(cellc.loc/dlo,1)); cellc.epsVel(:)];
        Dn = [diag(rn); zeros(1,numel(rn))]; cz = [0;0;0;0;0;cellc.c];
        nf = size(Dn,2); idmax = max([X.id; 0]);
        Z  = polyZonotope(Sel*X.c + cz, [Sel*X.G, Dn], [], blkdiag(X.E, eye(nf)), [X.id; idmax+(1:nf)']);
        U  = nn_set_eval(env.C, Z, env.evo);
        params.R0 = aux_stack(X, U); params.tStart = tk; params.tFinal = tk + P.dt_ctrl;
        [Rti, Rtp] = aux_reach(env.sys, params, options);
        bad = false;
        for j = 1:numel(Rti)
            I6 = interval(project(Rti{j}, 1:6)); lo = infimum(I6); hi = supremum(I6);
            emax = max(abs(lo(3)),abs(hi(3))); pmax = max(abs(lo(2)),abs(hi(2)));
            pTx = emax > P.Theta_T; pRx = pmax > P.FOV_R;
            if lo(1) <= 0 || pmax >= pi/2, Ml = -inf; else, Ml = link_margin(P, hi(1), pmax, emax, env.chi); end
            pP = Ml < 0; W.Mlow = min(W.Mlow, Ml);
            if pTx || pRx || pP
                nm = {'Tx','Rx','P'}; W.provFirst = strjoin(nm([pTx pRx pP]), '+');
                W.status = 'ace'; W.tFail = tk + (j-1)*options.timeStep; bad = true; break;
            end
            rr = max(abs([lo(4:6) hi(4:6)]),[],2)';
            if any(rr > P.qX(1:3)), W.status = 'model-range'; W.tFail = tk + (j-1)*options.timeStep; bad = true; break; end
        end
        if bad, break; end
        X = project(Rtp, 1:6);
    end
catch ME
    W.status = 'explosion'; W.provFirst = ME.identifier; W.tFail = tk;   % start of the failing period
end
if strcmp(W.status,'ok'), W.E = X; end
W.runtime = toc(tw);
end

function A = aux_simplify(E, typ, m)
% outer enclosure of the end set E (box hull or order-1 PCA parallelotope), inflated
switch typ
    case 'box'
        I = interval(E); c = center(I); r = rad(I);
        A = struct('type','box','c',c,'G',diag(r*(1+m) + 1e-9));
    case 'par'
        Z = reduce(zonotope(E), 'pca', 1);
        G = generators(Z); c = center(Z);
        if size(G,2) < 6 || rcond(G) < 1e-10      % degenerate: fall back to box
            A = aux_simplify(E, 'box', m); return;
        end
        A = struct('type','par','c',c,'G',G*(1+m));
end
end

function ok = aux_inside(E, A)
% sufficient test E (polyZonotope) inside A = {c + G a, |a|_inf <= 1}
Et = (A.G \ eye(size(A.G,1))) * (E + (-A.c));
I = interval(Et);
ok = all(infimum(I) >= -1) && all(supremum(I) <= 1);
end

function X = aux_gi2dep(X)
if ~isempty(X.GI)
    n = size(X.GI,2); idmax = max([X.id;0]);
    X = polyZonotope(X.c, [X.G, X.GI], [], blkdiag(X.E, eye(n)), [X.id; idmax+(1:n)']);
end
end

function R0 = aux_stack(X, U)
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
    if numel(Rnext.ti) > 1, error('uwoc:split','CORA split the set; not supported here'); end
    Rti{i} = Rnext.ti{1};
end
Rtp = Rnext.tp{1}.set;
end
