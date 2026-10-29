% RUN_CONSISTENCY_CHECK  Rung consistency: on every 3-D-Certified tile (3-D CCV run),
% falsify on the 6-DOF simulator (a) as in the ladder and (b) with every 6-DOF-only
% effect switched off (attitude noise and initial attitude, Coriolis/Munk coupling,
% net buoyancy). (b) must give no witness if the 6-DOF simulator agrees with the
% reduced 3-D model where they overlap.
P = uwoc_params(); L = load(fullfile(P.results,'phase2','actor_res_32.mat')); V6 = vehicle6dof(P);
C3 = load(fullfile(P.results,'ccv','ccv_3d_res_32.mat')); T = C3.T;
fo = struct('pop',100,'iters',8,'elite',10,'tol',0.01);
idx = find(T.verdict_maint == "Certified"); n = numel(idx);
full = false(n,1); reduced = false(n,1); rhoR = nan(n,1);
for k = 1:n
    c3 = C3.cells{idx(k)}; c3.epsAtt = deg2rad([1;1]); rng(k);
    F = falsify6_cell(P, V6, L.net, c3, fo, 200); full(k) = F.found;
    z = c3; z.epsAtt = [0;0]; V0 = V6; V0.att0 = [0;0]; V0.attRate = 0; V0.noC = true; V0.B = V0.W; rng(k);
    F0 = falsify6_cell(P, V0, L.net, z, fo, 200); reduced(k) = F0.found; rhoR(k) = F0.rho;
end
R = table(T.water(idx), T.d0_m(idx), T.phi0_deg(idx), T.z0_m(idx), full, reduced, rhoR, ...
    'VariableNames', {'water','d0_m','phi0_deg','z0_m','falsified_6dof_full','falsified_6dof_reduced','min_rho_reduced'});
writetable(R, fullfile(P.results,'ladder','consistency_check.csv'));
fprintf('3-D certified tiles %d: 6-DOF falsified %d (full), %d (6-DOF-only effects off)\n', n, sum(full), sum(reduced));
