% RUN_PHASE1_ACE  Link budget table + computed ACE regions (distance x pointing
% error) per water type, with a CORA reachable tube and Monte Carlo trajectories
% of the selected actor overlaid (candidate for Fig. 2). Constants PROVISIONAL.
P = setup_paths();
if ~exist('actorTag','var'), actorTag = 'res_32'; end
outdir = fullfile(P.results,'phase1'); if ~exist(outdir,'dir'), mkdir(outdir); end
L = load(fullfile(P.results,'phase2',['actor_' actorTag '.mat']));

% ---- link budget table (aligned, phi = 0) ----
dd = [1 2 3 4 5 6 8 10];
rows = {};
for wi = 1:3
    for d = dd
        c = P.water.c(wi);
        rows(end+1,:) = {P.water.name{wi}, c, d, link_margin(P,d,0,0,c), ...
            link_margin(P,d,0,0,c*(1+P.c_rel_unc)), link_margin(P,d,0,deg2rad(10),c)}; %#ok<SAGROW>
    end
end
T = cell2table(rows,'VariableNames',{'water','c_per_m','d_m','M_aligned_dB','M_aligned_cplus10_dB','M_e10deg_dB'});
writetable(T, fullfile(outdir,'link_budget.csv'));
% range at which M = 0 and M = 6 (aligned, nominal c)
rr = {};
for wi = 1:3
    c = P.water.c(wi);
    f0 = @(d) link_margin(P,d,0,0,c);
    rr(end+1,:) = {P.water.name{wi}, fzero(f0,[0.3 60]), fzero(@(d) f0(d)-P.M_robust,[0.3 60]), ...
        fzero(@(d) link_margin(P,d,0,0,c*(1+P.c_rel_unc)),[0.3 60])}; %#ok<SAGROW>
end
Rr = cell2table(rr,'VariableNames',{'water','d_outage_m','d_robust_m','d_outage_cplus10_m'});
writetable(Rr, fullfile(outdir,'ace_ranges.csv')); disp(Rr)

% ---- reach tubes + MC for one cell per water (d0 = half the aligned power range) ----
d0s = zeros(1,3);
for wi = 1:3, d0s(wi) = max(1, round(fzero(@(d) link_margin(P,d,0,0,P.water.c(wi)), [0.3 60]))/2*2/2); end
eo = default_eo(); ro = eo.ro; ro.storeBoxes = true;
tube = cell(1,3); mc = cell(1,3); rres = cell(1,3); locTube = 0.1; wTube = 0.025;
for wi = 1:3
    cellc = make_cell(P, wi, d0s(wi), deg2rad(5), locTube, wTube);
    r = reach_cell(P, L.net, cellc, ro); rres{wi} = r; tube{wi} = r.boxes;
    rng(7); s = mc_scen(P, cellc, 30);
    o = sim_closed_loop(P, s, @(z,k,x) deal(nn_forward(L.net,z), false(1,30)), struct('keep',true));
    mc{wi} = o;
    fprintf('%s d0=%g: reach status=%s maint=%d Mlow=%.2f dB (%.1fs)\n', P.water.name{wi}, d0s(wi), r.status, r.maint, r.Mlow, r.runtime);
end
save(fullfile(outdir,'ace_tubes.mat'),'tube','rres','d0s');

% ---- region grids for plotting (figures are drawn by make_figures.py) ----
dg = linspace(0.5, 16, 400); eg = linspace(0, 20, 300);
[Dg, Eg] = meshgrid(dg, eg);
cls = zeros(3, numel(eg), numel(dg)); Mplus = cls;
for wi = 1:3
    c = P.water.c(wi);
    [M, okTx] = link_margin(P, Dg, 0, deg2rad(Eg), c);
    k = 3*ones(size(M)); k(okTx & M >= 0) = 2; k(okTx & M >= P.M_robust) = 1;
    cls(wi,:,:) = k; Mplus(wi,:,:) = link_margin(P, Dg, 0, deg2rad(Eg), c*(1+P.c_rel_unc));
end
mcX = cellfun(@(o) o.X, mc, 'uni', 0); maint = cellfun(@(r) r.maint, rres); Mlow = cellfun(@(r) r.Mlow, rres);
save(fullfile(outdir,'ace_plotdata.mat'), 'dg','eg','cls','Mplus','tube','mcX','maint','Mlow','d0s','locTube','wTube','-v7');
