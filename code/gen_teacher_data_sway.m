function [Z, Y, src] = gen_teacher_data_sway(P, nUniform, nRollBatches, seed)
% GEN_TEACHER_DATA_SWAY  As gen_teacher_data, for the B3 sway teacher: 7 inputs
% (z plus phi_hat), 3 outputs. Uniform samples (phi_hat in +-40 deg, v in +-0.3 m/s) plus
% closed-loop rollouts of the sway teacher under the training bounds.
rng(seed);
U = @(lo,hi,n) lo + (hi-lo).*rand(1,n);
n = nUniform;
cU = [P.water.c(randi(3,1,n/2)).*(1+0.1*(2*rand(1,n/2)-1)), U(0.1,2.5,n/2)];
Zu = [U(0.75,12,n); U(-deg2rad(40),deg2rad(40),n); U(-0.3,0.3,n); U(-0.3,0.3,n); U(-0.3,0.3,n); cU; U(-deg2rad(40),deg2rad(40),n)];
global ZBUF_
Zr = {};
for b = 1:nRollBatches
    cfg.c  = P.water.c(randi(3));
    cfg.d0 = U(1.0, 9.0, 1);
    cfg.e0 = deg2rad(U(1, 20, 1));
    cfg.loc = U(0.05, P.loc_train, 1);
    cfg.w   = U(0, P.w_train, 1);
    cfg.phi0 = [-1 1]*deg2rad(25);
    cfg.dhalf = min(0.5, cfg.d0 - 0.75);
    s = make_scen(P, 200, cfg);
    ZBUF_ = {};
    sim_closed_loop(P, s, @recorder, struct('passPhiHat', true));
    Zr{end+1} = [ZBUF_{:}]; %#ok<AGROW>
end
Zr = [Zr{:}];
Z = [Zu, Zr];
Y = teacher_sway_policy(P, Z);
src = [zeros(1,size(Zu,2)), ones(1,size(Zr,2))];
    function [tau, iv] = recorder(z, ~, ~, ph)
        zz = [z; ph]; ZBUF_{end+1} = zz;
        tau = teacher_sway_policy(P, zz); iv = false(1,size(z,2));
    end
end
