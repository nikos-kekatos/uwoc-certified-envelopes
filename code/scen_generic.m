function scen = scen_generic(P, G)
% SCEN_GENERIC  Scenario from per-trajectory parameter arrays G (all columns = trajectories),
% so subsets can be taken by column indexing (subset_G). Fields of G:
%   x0 (6xN), c, chat (1xN)
%   current (world frame): w(t) = A [cos(a1+o1 t); sin(a1+o1 t)] for t < ts,
%                                 B [cos(a2+o2 t); sin(a2+o2 t)] for t >= ts
%     -> A, a1, o1, B, a2, o2, ts (1xN)
%   estimation errors per control step k (time t = (k-1) dt):
%     sign-switching biases (as the falsifier): br, ba (rel. to LOS), bo, hb, Tp, phs, vb (3xN)
%     random in-bound errors: locR (disk radius), epsPsiR, epsVelR (3xN)
%     localisation spikes: pS (probability per step), sMin, sMax (m)
scen.x0 = G.x0; scen.c = G.c; scen.chat = G.chat; scen.G = G;
scen.wfun = @(t,x) aux_polar(aux_w(G, t), x);
scen.noise = @(k,x) aux_noise(P, G, k, x);
end

function W = aux_w(G, t)
before = t < G.ts;
W = [G.A.*cos(G.a1+G.o1*t); G.A.*sin(G.a1+G.o1*t)].*before + ...
    [G.B.*cos(G.a2+G.o2*t); G.B.*sin(G.a2+G.o2*t)].*(~before);
end

function w = aux_polar(W, x)
phi = x(2,:);
w = [W(1,:).*cos(phi) + W(2,:).*sin(phi); -W(1,:).*sin(phi) + W(2,:).*cos(phi)];
end

function n = aux_noise(P, G, k, x)
N = size(x,2); t = (k-1)*P.dt_ctrl;
s = sign(sin(2*pi*t./G.Tp + G.phs)); s(s==0) = 1;
ang = x(2,:) + G.ba + G.bo*t;
dpos = [s.*G.br.*cos(ang); s.*G.br.*sin(ang)];
a = 2*pi*rand(1,N); rr = G.locR.*sqrt(rand(1,N));
dpos = dpos + [rr.*cos(a); rr.*sin(a)];
spk = rand(1,N) < G.pS; a2 = 2*pi*rand(1,N); m2 = G.sMin + (G.sMax - G.sMin).*rand(1,N);
dpos = dpos + spk.*[m2.*cos(a2); m2.*sin(a2)];
n.dpos = dpos;
n.dpsi = s.*G.hb + G.epsPsiR.*(2*rand(1,N)-1);
n.du = s.*G.vb(1,:) + G.epsVelR(1,:).*(2*rand(1,N)-1);
n.dv = s.*G.vb(2,:) + G.epsVelR(2,:).*(2*rand(1,N)-1);
n.dr = s.*G.vb(3,:) + G.epsVelR(3,:).*(2*rand(1,N)-1);
end
