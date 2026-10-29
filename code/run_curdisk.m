% RUN_CURDISK  Campaign C: the declared current bound |w| <= w0 is a disk; reach_cell
% enclosed it by a box (magnitudes up to sqrt(2) w0). With cellc.curModel = 'disk' the
% disk is enclosed by an octagonal zonotope (4 generators of length w0 tan(pi/8), which
% contains the disk). Monte Carlo and the falsifier already sample inside the disk, so
% their results do not change (same seeds -> same draws).
% Cells:
%   - the 70 hero-map cells still Inconclusive at T = 20 s after A2 (a2_inconclusive.csv);
%     settings of the A2 pass that certified most (pass 2: zonotope order 200, splitting
%     depth 2); newly certified cells are attacked by the A2 strong falsifier (pop 200 x 25,
%     same seed rng(5000 + i), i = index among the 74 A2 cells) and must give no witness;
%   - the 32 Certified cells (29 hero map + 3 A2 pass 2) as a consistency check, same
%     settings; none may lose its certificate.
%   - (if time) planar CCV at loc 0.1 and 0.15 m, clear + coastal, |w| <= 0.025 m/s, with
%     the Sec. 5 settings (run_ccv), output under results/curdisk/.
% Output: results/curdisk/curdisk_cells.csv|mat, results/curdisk/ccv_curdisk_res_32.*
if ~exist('cdStage','var'), cdStage = {'cells','ccv'}; end
P = setup_paths(); L = load(fullfile(P.results,'phase2','actor_res_32.mat')); net = L.net;
od = fullfile(P.results,'curdisk'); if ~exist(od,'dir'), mkdir(od); end
diary(fullfile(P.results,'logs','curdisk.log'));
t00 = tic;
if any(strcmp(cdStage,'cells'))
    M = load(fullfile(P.results,'opmap','opmap_res_32.mat'));
    sel74 = find(M.T.verdict_maint == "Inconclusive");
    A2 = readtable(fullfile(P.results,'a2','a2_inconclusive.csv'), 'TextType', 'string');
    assert(height(A2) == numel(sel74));
    iUnres = find(A2.final_T20 == "Inconclusive");                       % 70
    iA2cert = find(startsWith(A2.final_T20, "Certified"));                % 3
    selCert = find(M.T.verdict_maint == "Certified");                     % 29
    jobs = [repmat("unresolved",numel(iUnres),1); repmat("certified_hero",numel(selCert),1); repmat("certified_a2",numel(iA2cert),1)];
    idxOp = [sel74(iUnres); selCert; sel74(iA2cert)];                     % index into opmap cells
    idxA2 = [iUnres; zeros(numel(selCert),1); iA2cert];                   % index among the 74 (falsifier seed)
    n = numel(idxOp); ro2 = default_eo().ro; ro2.zonotopeOrder = 200;
    fo = struct('pop',200,'iters',25,'elite',20,'tol',0.01);
    cellsS = M.cells(idxOp);
    get_pool(10); pctRunOnAll(sprintf('addpath(''%s''); addpath(genpath(''%s''));', P.code, P.cora));
    c0 = cellsS{1}; c0.T = P.dt_ctrl; c0.curModel = 'disk'; reach_cell(P, net, c0, ro2);
    st = strings(n,1); cert = false(n,1); Ml = nan(n,1); rt = zeros(n,1); lv = zeros(n,1);
    pTx = false(n,1); pRx = false(n,1); pP = false(n,1); ff = false(n,1); frho = nan(n,1);
    parfor q = 1:n
        c = cellsS{q}; c.curModel = 'disk';
        R = reach_refine(P, net, c, ro2, 2);
        st(q) = strjoin(unique(R.statuses),'|'); cert(q) = R.maint; Ml(q) = R.Mlow; rt(q) = R.runtime; lv(q) = R.nLeaves;
        pTx(q) = R.possTx; pRx(q) = R.possRx; pP(q) = R.possP;
        if R.maint && idxA2(q) > 0 && jobs(q) == "unresolved"
            rng(5000 + idxA2(q));
            F = falsify_cell(P, @(z,k,x) deal(nn_forward(net,z), false(1,size(z,2))), c, fo);
            ff(q) = F.found; frho(q) = F.rho;
        end
    end
    T = M.T(idxOp, {'water','d0_m','loc_m','w_mps','verdict_maint','provenance','reach_status','mc_outage_rate'});
    T.set = jobs; T.a2_index = idxA2;
    T.a2_final = strings(n,1); T.a2_final(idxA2 > 0) = A2.final_T20(idxA2(idxA2 > 0));
    T.a2_pass2_status = strings(n,1); T.a2_pass2_status(idxA2 > 0) = A2.pass2_status(idxA2(idxA2 > 0));
    T.disk_status = st; T.disk_certified = cert; T.disk_Mlow_dB = Ml; T.disk_leaves = lv; T.disk_runtime_s = rt;
    T.disk_possTx = pTx; T.disk_possRx = pRx; T.disk_possP = pP;
    T.attack_found = ff; T.attack_min_rho = frho;
    writetable(T, fullfile(od,'curdisk_cells.csv')); save(fullfile(od,'curdisk_cells.mat'), 'T');
    disp(groupcounts(T, {'set','disk_certified'}));
    fprintf('[curdisk] cells done %.0f s\n', toc(t00));
end
if any(strcmp(cdStage,'ccv'))
    clearvars -except t00 od cdStage
    actorTag = 'res_32'; ccvModel = '2d'; ccvTag = 'curdisk'; ccvLocs = [0.1 0.15]; ccvWaters = [1 2];
    ccvCurModel = 'disk'; ccvOutDir = od;
    run_ccv;
    fprintf('[curdisk] ccv done %.0f s\n', toc(t00));
end
diary off
