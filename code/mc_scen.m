function scen = mc_scen(P, cellc, N)
% MC_SCEN  Random scenarios inside a reachability cell (box lo/hi, bounds of cellc).
% Same declared bounds as reach_cell: |dpos|<=loc (disk), |dpsi|<=epsPsi,
% |w|<=w (disk, world frame, slowly varying), c in [1-crel,1+crel] c.
if ~isfield(cellc,'crel'), cellc.crel = P.c_rel_unc; end
if ~isfield(cellc,'epsVel'), cellc.epsVel = [P.eps_u; P.eps_v; P.eps_r]; end
nx = numel(cellc.lo); is3 = nx == 9;
scen.x0 = cellc.lo + (cellc.hi - cellc.lo).*rand(nx,N);
scen.c  = cellc.c*(1 + cellc.crel*(2*rand(1,N)-1));
scen.chat = cellc.c*ones(1,N);
a0 = 2*pi*rand(1,N); a1 = 2*pi*rand(1,N);
r0 = cellc.w*sqrt(rand(1,N)); r1 = (cellc.w - r0).*rand(1,N);
om = 2*pi/30*(0.5+rand(1,N)); ph = 2*pi*rand(1,N);
W0 = [r0.*cos(a0); r0.*sin(a0)]; W1 = [r1.*cos(a1); r1.*sin(a1)];
if is3
    wv = cellc.wv*(2*rand(1,N)-1);
    scen.wfun = @(t,x) [polarw(W0 + W1.*sin(om*t+ph), x); wv];
    scen.alphaR = cellc.alphaR*(2*rand(1,N)-1);
    lz = cellc.locz;
else
    scen.wfun = @(t,x) polarw(W0 + W1.*sin(om*t+ph), x);
    lz = 0;
end
loc = cellc.loc; ep = cellc.epsPsi; ev = cellc.epsVel;
scen.noise = @(k,x) struct('dpos', diskU(loc,N), 'dpsi', ep*(2*rand(1,N)-1), ...
    'du', ev(1)*(2*rand(1,N)-1), 'dv', ev(2)*(2*rand(1,N)-1), 'dr', ev(3)*(2*rand(1,N)-1), ...
    'dz', lz*(2*rand(1,N)-1));
% campaign E: rate-bounded current model (curModel = 'rate'): sample admissible paths
% |W| <= w0, |dW_i/dt| <= rho (cur_rate_wfun); extra draws only in this mode
if isfield(cellc,'curModel') && strcmp(cellc.curModel,'rate') && ~is3
    scen.wfun = cur_rate_wfun(cellc, rand(5,N), 'mc');
end
end
function w = polarw(W, x)
phi = x(2,:);
w = [W(1,:).*cos(phi) + W(2,:).*sin(phi); -W(1,:).*sin(phi) + W(2,:).*cos(phi)];
end
function p = diskU(r, N)
a = 2*pi*rand(1,N); rr = r*sqrt(rand(1,N));
p = [rr.*cos(a); rr.*sin(a)];
end
