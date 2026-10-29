function out = sim_closed_loop(P, scen, ctrl, opts)
% SIM_CLOSED_LOOP  Vectorised closed-loop simulation (N trajectories at once).
%   scen.x0      6xN initial states [d;phi;e;u;v;r]
%   scen.c       1xN true extinction coefficient
%   scen.chat    1xN controller's extinction estimate
%   scen.wfun    @(t,x) -> 2xN current in polar comps [w_r;w_t]  (true current)
%   scen.noise   @(k,x) -> struct with fields dpos (2xN, metres, world frame),
%                dpsi (1xN), du,dv,dr (1xN)   (estimation errors at step k)
%   ctrl         @(z,k,x) -> [tau (2xN), interv (1xN logical)]
%   opts.T (default P.T), opts.keep (store trajectories)
% Output: per-trajectory metrics (sampled every dt_sim; this is simulation,
% not verification).
if nargin < 4, opts = struct(); end
T    = getf(opts,'T',P.T);
keep = getf(opts,'keep',false);
N  = size(scen.x0,2);
nC = round(T/P.dt_ctrl); nS = round(P.dt_ctrl/P.dt_sim); h = P.dt_sim;
x  = scen.x0;
is3 = size(x,1) == 9;
if is3, fplant = @plant_f3; aR = scen.alphaR; else, fplant = @plant_f; aR = []; end
nT = nC*nS+1;
Mmin = inf(1,N); tOut = zeros(1,N); tRob = zeros(1,N); firstOut = nan(1,N);
violTx = false(1,N); violRx = false(1,N); violP = false(1,N);
rho = inf(1,N); firstProv = zeros(1,N); Te = getf(opts,'Te',inf); rhoLate = inf(1,N); lastOut = nan(1,N); tRec = nan(1,N);   % 1 Tx, 2 Rx, 3 Power (first violation)
effort = zeros(1,N); nInterv = zeros(1,N); tAlign = nan(1,N);
if keep, X = zeros(size(x,1),N,nT); X(:,:,1) = x; TAU = zeros(2,N,nC); MM = zeros(N,nT); end
[M,okTx,okRx,r3] = ace_eval(P, x, scen.c, aR);
[Mmin,tOut,tRob,firstOut,violTx,violRx,violP] = acc(M,okTx,okRx,0,Mmin,tOut,tRob,firstOut,violTx,violRx,violP,0,P);
[rho, firstProv] = robu(r3, rho, firstProv);
if keep, MM(:,1) = M'; end
idx = 1;
for k = 1:nC
    t0 = (k-1)*P.dt_ctrl;
    [z, phih, dzk] = estimate(x, scen, k);
    if getf(opts,'passExtra',false)
        ex = struct('phih', phih, 't', t0, ...
            'wmeas', scen.wfun(t0, x) + getf(opts,'wNoise',0.03)*(2*rand(2,N)-1));
        [tau, iv] = ctrl(z, k, x, ex);
    elseif getf(opts,'passPhiHat',false), [tau, iv] = ctrl(z, k, x, phih);
    else, [tau, iv] = ctrl(z, k, x); end
    nInterv = nInterv + iv;
    if keep, TAU(:,:,k) = tau; end
    for s = 1:nS
        t = t0 + (s-1)*h;
        wa = @(tt,xx) addz(scen.wfun(tt,xx), dzk, is3);
        k1 = fplant(P, x,          tau, wa(t,x));
        k2 = fplant(P, x+h/2*k1,   tau, wa(t+h/2,x+h/2*k1));
        k3 = fplant(P, x+h/2*k2,   tau, wa(t+h/2,x+h/2*k2));
        k4 = fplant(P, x+h*k3,     tau, wa(t+h,x+h*k3));
        x  = x + h/6*(k1+2*k2+2*k3+k4);
        idx = idx+1;
        [M,okTx,okRx,r3] = ace_eval(P, x, scen.c, aR);
        [Mmin,tOut,tRob,firstOut,violTx,violRx,violP] = acc(M,okTx,okRx,t+h,Mmin,tOut,tRob,firstOut,violTx,violRx,violP,h,P);
        [rho, firstProv] = robu(r3, rho, firstProv);
        rnow = min(r3,[],1);
        lastOut(rnow < 0) = t+h;
        rec = isfinite(firstOut) & isnan(tRec) & rnow >= 0;   % first return to ACE_O after outage
        tRec(rec) = t + h - firstOut(rec);
        if t+h >= Te, rhoLate = min(rhoLate, rnow); end
        effort = effort + h*((tau(1,:)/P.tau_u_max).^2 + (tau(2,:)/P.tau_r_max).^2);
        al = isnan(tAlign) & abs(x(3,:)) < deg2rad(2);
        tAlign(al) = t+h;
        if keep, X(:,:,idx) = x; MM(:,idx) = M'; end
    end
end
out.Mmin = Mmin; out.tOut = tOut; out.tRobust = tRob; out.firstOut = firstOut;
out.outage = isfinite(firstOut);
out.violTx = violTx; out.violRx = violRx; out.violP = violP;
out.effort = effort; out.nInterv = nInterv; out.nCtrl = nC; out.tAlign = tAlign;
out.T = T; out.xT = x; out.rho = rho; out.firstProv = firstProv; out.rhoLate = rhoLate; out.lastOut = lastOut; out.tRecover = tRec;
if keep, out.X = X; out.TAU = TAU; out.M = MM; out.t = (0:nT-1)*h; end
end

function [z, phih, dz] = estimate(x, scen, k)
n  = scen.noise(k, x);
if isfield(n,'dz'), dz = n.dz; else, dz = zeros(1,size(x,2)); end
d = x(1,:); phi = x(2,:); e = x(3,:);
p  = [d.*cos(phi); d.*sin(phi)];
ph = p + n.dpos;
dh = sqrt(sum(ph.^2,1));
phih = atan2(ph(2,:), ph(1,:));
eh = wrapToPi(e + phi - phih + n.dpsi);
z = [dh; eh; x(4,:)+n.du; x(5,:)+n.dv; x(6,:)+n.dr; scen.chat];
end

function [Mmin,tOut,tRob,firstOut,vTx,vRx,vP] = acc(M,okTx,okRx,t,Mmin,tOut,tRob,firstOut,vTx,vRx,vP,h,P)
out = ~okTx | ~okRx | M < 0;
Mg = M; Mg(~okTx | ~okRx) = -inf;           % margin only inside admissible geometry
Mmin = min(Mmin, M);
vTx = vTx | ~okTx; vRx = vRx | ~okRx; vP = vP | (M < 0);
firstOut(isnan(firstOut) & out) = t;
tOut = tOut + h*out;
tRob = tRob + h*(Mg >= P.M_robust);
end

function [rho, fp] = robu(r3, rho, fp)
% robustness (min of the three ACE_O margins: deg, deg, dB); <0 = outage
[rmin, which] = min(r3, [], 1);
newv = (fp == 0) & (rmin < 0);
fp(newv) = which(newv);
rho = min(rho, rmin);
end

function w = addz(w, dz, is3)
if is3, w = [w; dz]; end
end

function v = getf(s,f,d)
if isfield(s,f), v = s.(f); else, v = d; end
end
