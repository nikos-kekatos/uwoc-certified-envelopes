% RUN_B1_SLICES  B1 hardware sweep on representative slices: clear and
% coastal water, near/far separation (hero-map d0: clear 3 / 6.5 m, coastal 2 / 4 m),
% each slice a phi-strip of six 10-deg tiles at d0 +- 0.25 m, loc 0.1 m, |w| <= 0.025 m/s,
% |e0| <= 5 deg. 7 variants (base, Phi_half 10/30, FOV 20/45, P_min -3/+3 dB), actor res_32
% unchanged. Certified area (CCV) and Monte Carlo apparent-success area (EVV) per slice.
P0 = setup_paths(); L = load(fullfile(P0.results,'phase2','actor_res_32.mat'));
V = {'base','Pt',0.1; 'Phi10','Phi_half',10; 'Phi30','Phi_half',30; 'FOV20','FOV',20; 'FOV45','FOV',45; 'Pmin_m3','Pmin_dB',-3; 'Pmin_p3','Pmin_dB',3};
slices = [1 3; 1 6.5; 2 2; 2 4]; pE = deg2rad(-30:10:30);
eo = default_eo(); eo.nMC = 200; eo.maxDepth = 1; eo.checkCertified = false; eo.estFals = false; eo.precheck = true; eo.fo.iters = 8;
rows = {}; t0 = tic;
for vi = 1:size(V,1)
    P = link_variant(P0, V{vi,2}, V{vi,3});
    cells = {}; meta = [];
    for s = 1:size(slices,1)
        for j = 1:numel(pE)-1
            c = make_cell(P, slices(s,1), slices(s,2), deg2rad(5), 0.1, 0.025);
            c.lo(2) = pE(j); c.hi(2) = pE(j+1);
            cells{end+1} = c; %#ok<SAGROW>
            meta(end+1,:) = [s, 0.5*((slices(s,2)+0.25)^2 - (slices(s,2)-0.25)^2)*(pE(j+1)-pE(j))]; %#ok<SAGROW>
        end
    end
    [~, T] = run_cells(P, L.net, cells, eo, 10);
    for s = 1:size(slices,1)
        m = meta(:,1) == s; a = meta(:,2);
        rows(end+1,:) = {string(V{vi,1}), string(P.water.name{slices(s,1)}), slices(s,2), sum(a(m & T.verdict_maint=="Certified")), ...
            sum(a(m & T.mc_outage_rate==0)), sum(a(m & T.mc_outage_rate==0 & T.verdict_maint=="Falsified")), ...
            sum(a(m & T.verdict_maint=="Inconclusive")), sum(a(m)), K_of(P)}; %#ok<SAGROW>
    end
    fprintf('[B1] %s done %.0f s\n', V{vi,1}, toc(t0));
end
R = cell2table(rows, 'VariableNames', {'variant','water','d0_m','CCV_m2','EVV_m2','false_assurance_m2','inconclusive_m2','tiled_m2','K_dB'});
outdir = fullfile(P0.results,'b1'); if ~exist(outdir,'dir'), mkdir(outdir); end
writetable(R, fullfile(outdir,'b1_slices_raw.csv'));             % save before post-processing
base = R(R.variant == "base",:);
R.CCV_change_pct = nan(height(R),1); R.EVV_change_pct = nan(height(R),1);
for i = 1:height(R)
    b = base(base.water == R.water(i) & base.d0_m == R.d0_m(i), :);
    R.CCV_change_pct(i) = 100*(R.CCV_m2(i) - b.CCV_m2)/max(b.CCV_m2, eps);
    R.EVV_change_pct(i) = 100*(R.EVV_m2(i) - b.EVV_m2)/max(b.EVV_m2, eps);
end
writetable(R, fullfile(outdir,'b1_slices.csv')); disp(R);
function k = K_of(P), k = P.K_dB; end
