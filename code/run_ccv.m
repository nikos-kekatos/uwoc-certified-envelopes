% RUN_CCV  Certified Communication Volume (CCV) vs empirical viable volume (EVV)
% per water type.
%   Tiles of start positions around the receiver: planar (d0, phi0) or 3-D (d0, phi0, z0).
%   CCV = sum of tile measures whose verdict is Certified (CORA).
%   EVV = sum of tile measures with zero outages in nMC Monte Carlo runs
%         ("apparent success"); EVV - CCV is the over-estimation by sampling.
%   The Falsified part of EVV is a concrete over-estimation (outage trajectories exist).
% Inputs (workspace): ccvModel ('2d'|'3d'), ccvLocs (localisation bounds), ccvTag.
P = setup_paths();
if exist('Pover','var') && ~isempty(Pover), P = Pover(P); end   % B1 parameter variants
if ~exist('actorTag','var'), actorTag = 'res_32'; end
if ~exist('ccvModel','var'), ccvModel = '2d'; end
if ~exist('ccvLocs','var'), ccvLocs = P.ccv.locs; end
if ~exist('ccvTag','var'), ccvTag = ccvModel; end
if strcmp(actorTag,'teacher'), L = struct('net', []); else, L = load(fullfile(P.results,'phase2',['actor_' actorTag '.mat'])); end
if ~exist('ccvWaters','var'), ccvWaters = 1:3; end
dE = P.ccv.dEdges; pE = deg2rad(P.ccv.phiEdges); zE = P.ccv.zEdges;
eo = default_eo(); eo.nMC = P.ccv.nMC; eo.maxDepth = 1; eo.checkCertified = false;
eo.estFals = false; eo.precheck = true; eo.fo.iters = 8;
if exist('ccvNoReach','var') && ccvNoReach, eo.noReach = true; end   % empirical-only (baseline)
if exist('ccvRo','var') && ~isempty(ccvRo), eo.ro = ccvRo; end   % reach-option override (B3 sway actor)
if exist('ccvSkipW','var') && ccvSkipW, eo.skipReachIfWitness = true; end   % no reach on MC-falsified tiles (verdict unchanged)
cells = {}; meas = []; meta = [];
for loc = ccvLocs
 for wi = ccvWaters
  for i = 1:numel(dE)-1
   for j = 1:numel(pE)-1
    base = make_cell(P, wi, (dE(i)+dE(i+1))/2, deg2rad(P.ccv.e0), loc, P.ccv.w);
    base.lo(1) = dE(i); base.hi(1) = dE(i+1); base.lo(2) = pE(j); base.hi(2) = pE(j+1);
    if exist('ccvLocModel','var'), base.locModel = ccvLocModel; end
    if exist('ccvCurModel','var'), base.curModel = ccvCurModel; end   % campaign C: current disk enclosure
    if exist('ccvRhoFac','var'), base.rho = ccvRhoFac*base.w; end      % campaign E: rate bound rho = fac*w0 (curModel 'rate')
    if exist('ccvRateReset','var'), base.rateReset = ccvRateReset; end % campaign E: re-enclosure policy
    a2 = 0.5*(dE(i+1)^2 - dE(i)^2)*(pE(j+1)-pE(j));          % m^2 (annular sector)
    if strcmp(ccvModel,'2d')
        cells{end+1} = base; meas(end+1) = a2; meta(end+1,:) = [loc wi 0]; %#ok<SAGROW>
    else
        for kz = 1:numel(zE)-1
            c = base; c.model = '3d';
            c.lo = [base.lo; zE(kz); 0; -P.ccv.th0]; c.hi = [base.hi; zE(kz+1); 0; P.ccv.th0];
            c.wv = P.ccv.wv; c.locz = P.ccv.locz; c.alphaR = P.ccv.alphaR;
            cells{end+1} = c; meas(end+1) = a2*(zE(kz+1)-zE(kz)); meta(end+1,:) = [loc wi mean(zE(kz:kz+1))]; %#ok<SAGROW>
        end
    end
   end
  end
 end
end
outdir = fullfile(P.results,'ccv'); if exist('ccvOutDir','var'), outdir = ccvOutDir; end
if ~exist(outdir,'dir'), mkdir(outdir); end
t0 = tic;
if strcmp(actorTag,'teacher')                 % classical law: one exact PWL net per water
    Ts = {}; Rs = {}; wiC = cellfun(@(c) c.wi, cells);
    for wi = unique(wiC)
        m = find(wiC == wi);
        [Rw, Tw] = run_cells(P, teacher_net(P, wi), cells(m), eo, 10); Ts{end+1} = Tw; Rs = [Rs; Rw]; %#ok<AGROW>
    end
    T = vertcat(Ts{:}); ord = cell2mat(arrayfun(@(wi) find(wiC == wi), unique(wiC), 'uni', 0)); meas = meas(ord); meta = meta(ord,:); cells = cells(ord);
else
    [Rs, T] = run_cells(P, L.net, cells, eo, 10);
end
wall = toc(t0);
T.measure = meas(:); T.z0_m = meta(:,3);
save(fullfile(outdir, ['ccv_' ccvTag '_' actorTag '.mat']), 'Rs', 'T', 'cells', 'eo', 'wall');
writetable(T, fullfile(outdir, ['ccv_' ccvTag '_' actorTag '.csv']));
% summary
rows = {};
for loc = ccvLocs
    for wi = ccvWaters
        m = T.loc_m == loc & T.water == P.water.name{wi};
        ccv = sum(T.measure(m & T.verdict_maint == "Certified"));
        evv = sum(T.measure(m & T.mc_outage_rate == 0));
        evvF = sum(T.measure(m & T.mc_outage_rate == 0 & T.verdict_maint == "Falsified"));
        evvI = sum(T.measure(m & T.mc_outage_rate == 0 & T.verdict_maint == "Inconclusive"));
        rows(end+1,:) = {ccvModel, loc, P.water.name{wi}, ccv, evv, evvF, evvI, sum(T.measure(m)), ...
            1 - ccv/max(evv,eps), sum(T.reach_time_s(m))}; %#ok<SAGROW>
    end
end
S = cell2table(rows, 'VariableNames', {'model','loc_m','water','CCV','EVV','EVV_falsified','EVV_inconclusive', ...
    'tiled','overestimation_frac','reach_cpu_s'});
writetable(S, fullfile(outdir, ['ccv_summary_' ccvTag '_' actorTag '.csv']));
fprintf('wall %.1f s\n', wall); disp(S)
