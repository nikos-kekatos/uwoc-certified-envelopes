% RUN_OPERATING_MAP  Hero figure data: for each water type and two
% separations (near = 0.3, far = 0.7 of the aligned power range at nominal c), a
% 7 x 7 grid of localisation error x current bound. Each cell: Certified /
% Falsified / Inconclusive, Monte Carlo outage rate (apparent success = 0 of N),
% and provenance (dominant ACE term). |e0| <= 5 deg, other bounds from MODEL.md.
P = setup_paths();
if ~exist('actorTag','var'), actorTag = 'res_32'; end
L = load(fullfile(P.results,'phase2',['actor_' actorTag '.mat']));
locs = [0.05 0.1 0.2 0.3 0.5 0.75 1.0];
curs = [0 0.025 0.05 0.075 0.1 0.15 0.2];
fr   = [0.3 0.7];
eo = default_eo(); eo.precheck = true; eo.maxDepth = 1;
cells = {}; meta = [];
for wi = 1:3
    dout = fzero(@(d) link_margin(P,d,0,0,P.water.c(wi)), [0.3 80]);
    for k = 1:2
        d0 = max(1.0, round(2*fr(k)*dout)/2);
        for loc = locs
            for w = curs
                cells{end+1} = make_cell(P, wi, d0, deg2rad(5), loc, w); %#ok<SAGROW>
                meta(end+1,:) = [wi, k, d0, loc, w]; %#ok<SAGROW>
            end
        end
    end
end
outdir = fullfile(P.results,'opmap'); if ~exist(outdir,'dir'), mkdir(outdir); end
t0 = tic;
[Rs, T] = run_cells(P, L.net, cells, eo, 10);
T.range_class = meta(:,2); wall = toc(t0);
save(fullfile(outdir, ['opmap_' actorTag '.mat']), 'Rs', 'T', 'cells', 'eo', 'wall', 'locs', 'curs', 'fr');
writetable(T, fullfile(outdir, ['opmap_' actorTag '.csv']));
fprintf('wall %.1f s\n', wall); disp(groupcounts(T, {'water','verdict_maint'}));
