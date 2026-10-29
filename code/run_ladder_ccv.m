% RUN_LADDER_CCV  Abstraction ladder on the 3-D CCV tiling:
% for every 3-D tile (water, d-bin, phi-bin, z-layer)
%   2D verdict : planar CORA verdict of the same (d, phi) tile (2-D CCV run)
%   3D verdict : CORA verdict on the 3-D reduced model (3-D CCV run)
%   6-DOF      : Monte Carlo + cross-entropy falsification on the BlueROV2 6-DOF model
%                (same declared bounds + roll/pitch attitude noise and initial attitude)
% Reports P(2D Certified AND 6-DOF Falsified), P(3D Certified AND 6-DOF Falsified),
% P(2D Certified AND 3D Falsified / not Certified) with Wilson 95 % intervals, the
% mechanism of each 6-DOF witness (single switch-off attribution), and the CCV and
% empirical viable volume (EVV, 6-DOF Monte Carlo with zero outages) per rung.
P = setup_paths();
if ~exist('actorTag','var'), actorTag = 'res_32'; end
if ~exist('ladderLoc','var'), ladderLoc = 0.1; end
L  = load(fullfile(P.results,'phase2',['actor_' actorTag '.mat']));
C2 = load(fullfile(P.results,'ccv',['ccv_2d_' actorTag '.mat']));
C3 = load(fullfile(P.results,'ccv',['ccv_3d_' actorTag '.mat']));
V6 = vehicle6dof(P);
fo = struct('pop',100,'iters',8,'elite',10,'tol',0.01);
epsAtt = deg2rad([1; 1]);                       % roll/pitch estimate noise (ASSUMED)
T3 = C3.T; m3 = T3.loc_m == ladderLoc;
idx3 = find(m3); n = numel(idx3);
% planar verdict of each 3-D tile
v2 = strings(n,1); mc2 = nan(n,1);
T2 = C2.T;
for i = 1:n
    r = T3(idx3(i),:);
    j = find(T2.loc_m == ladderLoc & T2.water == r.water & abs(T2.d0_m - r.d0_m) < 1e-9 & abs(T2.phi0_deg - r.phi0_deg) < 1e-6);
    v2(i) = T2.verdict_maint(j(1)); mc2(i) = T2.mc_outage_rate(j(1));
end
v3 = T3.verdict_maint(idx3);
live = ~startsWith(T3.reach_status(idx3), "skipped");
cellsS = C3.cells(idx3);
f6 = false(n,1); rho6 = nan(n,1); p6 = zeros(n,1); mc6 = nan(n,1); mech = strings(n,1);
roll6 = nan(n,1); pitch6 = nan(n,1);
get_pool(10);
pctRunOnAll(sprintf('addpath(''%s'');', P.code));
need = live | v2 == "Certified" | v3 == "Certified";
t0 = tic;
parfor i = 1:n
    if ~need(i), continue; end
    c3 = cellsS{i}; c3.epsAtt = epsAtt;
    rng(7000 + i);
    doCEM = (v2(i) == "Certified") || (v3(i) == "Certified");
    fo_i = fo; if ~doCEM, fo_i.iters = 0; end          % Monte Carlo only elsewhere (EVV)
    F = falsify6_cell(P, V6, L.net, c3, fo_i, 200);
    f6(i) = F.found; rho6(i) = F.rho; p6(i) = F.prov; mc6(i) = F.mc_rate;
    roll6(i) = F.maxRoll; pitch6(i) = F.maxPitch;
    if F.found && doCEM
        ms = {'pitch','roll','rxtilt','vcurrent','depth','coupling','buoyancy'}; hit = {};
        for k = 1:numel(ms)
            rng(7000 + i);
            Fm = falsify6_cell(P, V6, L.net, c3, fo, 200, struct(ms{k}, true));
            if ~Fm.found, hit{end+1} = ms{k}; end %#ok<AGROW>
        end
        if isempty(hit), mech(i) = "combined"; else, mech(i) = strjoin(hit, '+'); end
    end
end
wall = toc(t0);
nm = ["", "Tx", "Rx", "P"];
R = table(T3.water(idx3), T3.d0_m(idx3), T3.phi0_deg(idx3), T3.z0_m(idx3), T3.measure(idx3), ...
    v2, mc2, v3, T3.mc_outage_rate(idx3), T3.provenance(idx3), f6, rho6, nm(p6+1)', mc6, mech, ...
    rad2deg(roll6), rad2deg(pitch6), ...
    'VariableNames', {'water','d0_m','phi0_deg','z0_m','volume_m3','verdict_2d','mc2d_outage','verdict_3d', ...
    'mc3d_outage','prov_3d','falsified_6dof','min_rho_6dof','prov_6dof','mc6dof_outage','mechanism_6dof', ...
    'max_roll_deg','max_pitch_deg'});
outdir = fullfile(P.results,'ladder'); if ~exist(outdir,'dir'), mkdir(outdir); end
writetable(R, fullfile(outdir, ['ladder_ccv_' actorTag '.csv']));
save(fullfile(outdir, ['ladder_ccv_' actorTag '.mat']), 'R', 'fo', 'epsAtt', 'wall', 'V6');
fprintf('ladder wall %.1f s, %d tiles\n', wall, n);
