% RUN_LADDER  Abstraction ladder 2D -> 3D (reduced) -> 6-DOF.
% Input: the 2D operating-map cells (results/opmap). For every 2D cell and each
% vertical-uncertainty level, build the matched 3-D cell (same planar bounds plus
% depth offset, pitch trim, vertical current, depth-estimate error, Rx tilt):
%   3-D : CORA reachability + Monte Carlo + falsifier (Certified/Falsified/Inconclusive)
%   6-DOF: Monte Carlo + falsifier only (simulation model; no 6-DOF certificate)
% Reports P(2D Certified AND 3D Falsified), P(2D Certified AND 3D not Certified),
% P(2D Certified AND 6-DOF Falsified), P(3D Certified AND 6-DOF Falsified), and the
% mechanism of each 6-DOF witness (which single switch-off removes it).
P = setup_paths();
if ~exist('actorTag','var'), actorTag = 'res_32'; end
L = load(fullfile(P.results,'phase2',['actor_' actorTag '.mat']));
G = load(fullfile(P.results,'opmap',['opmap_' actorTag '.mat']));
V6 = vehicle6dof(P);
lv = P.ladder.levels;                       % struct array (name, zhalf, th0, wv, locz, alphaR)
eo = default_eo(); eo.precheck = true; eo.checkCertified = true; eo.estFals = false; eo.maxDepth = 0;
fo = struct('pop',100,'iters',6,'elite',10,'tol',0.01);
sel = find(G.T.verdict_maint == "Certified");
outdir = fullfile(P.results,'ladder'); if ~exist(outdir,'dir'), mkdir(outdir); end
get_pool(10);
pctRunOnAll(sprintf('addpath(''%s''); addpath(genpath(''%s''));', P.code, P.cora));
% derivatives for the 3-D system once on the client
c0 = to3d(G.cells{sel(1)}, lv(1)); c0.T = P.dt_ctrl; reach_cell(P, L.net, c0, eo.ro);
rows = {};
for li = 1:numel(lv)
    n = numel(sel); v3 = strings(n,1); p3 = strings(n,1); mc3 = nan(n,1); f6 = false(n,1);
    p6 = zeros(n,1); mc6 = nan(n,1); mechs = strings(n,1); t3 = nan(n,1); roll6 = nan(n,1); pitch6 = nan(n,1);
    cellsS = G.cells(sel); lvi = lv(li);
    parfor i = 1:n
        c3 = to3d(cellsS{i}, lvi);
        eoi = eo; eoi.seed = 4000 + i + 100*li;
        R3 = eval_cell(P, L.net, c3, eoi);
        v3(i) = R3.verdict; p3(i) = R3.prov; mc3(i) = R3.mc_outage_rate; t3(i) = R3.reach.runtime;
        rng(9000 + i + 100*li);
        F6 = falsify6_cell(P, V6, L.net, c3, fo, 200);
        f6(i) = F6.found; p6(i) = F6.prov; mc6(i) = F6.mc_rate; roll6(i) = F6.maxRoll; pitch6(i) = F6.maxPitch;
        if F6.found
            ms = {'pitch','roll','rxtilt','vcurrent','depth','coupling','buoyancy'}; hit = {};
            for m = 1:numel(ms)
                rng(9000 + i + 100*li);
                Fm = falsify6_cell(P, V6, L.net, c3, fo, 200, struct(ms{m}, true));
                if ~Fm.found, hit{end+1} = ms{m}; end %#ok<AGROW>
            end
            if isempty(hit), mechs(i) = "combined"; else, mechs(i) = strjoin(hit, '+'); end
        end
    end
    for i = 1:n
        r = G.T(sel(i),:);
        rows(end+1,:) = {lvi.name, r.water, r.d0_m, r.loc_m, r.w_mps, "Certified", v3(i), p3(i), mc3(i), t3(i), ...
            f6(i), p6(i), mc6(i), mechs(i), rad2deg(roll6(i)), rad2deg(pitch6(i))}; %#ok<SAGROW>
    end
    fprintf('%s: 2D-cert %d | 3D Certified %d, Falsified %d | 6-DOF falsified %d\n', lvi.name, n, ...
        sum(v3=="Certified"), sum(v3=="Falsified"), sum(f6));
end
T = cell2table(rows, 'VariableNames', {'level','water','d0_m','loc_m','w_mps','verdict_2d','verdict_3d', ...
    'prov_3d','mc3d_outage','reach3d_time_s','falsified_6dof','prov_6dof','mc6dof_outage','mechanism_6dof', ...
    'max_roll_deg','max_pitch_deg'});
writetable(T, fullfile(outdir, ['ladder_' actorTag '.csv'])); save(fullfile(outdir, ['ladder_' actorTag '.mat']), 'T', 'lv', 'V6');
S = groupsummary(T, {'level','water'}, @(x) mean(x), {'falsified_6dof'});
writetable(S, fullfile(outdir, ['ladder_summary_' actorTag '.csv']));

function c3 = to3d(c, lv)
c3 = c; c3.model = '3d';
c3.lo = [c.lo; -lv.zhalf; 0; -lv.th0]; c3.hi = [c.hi; lv.zhalf; 0; lv.th0];
c3.wv = lv.wv; c3.locz = lv.locz; c3.alphaR = lv.alphaR; c3.epsAtt = deg2rad([1;1]);
end
