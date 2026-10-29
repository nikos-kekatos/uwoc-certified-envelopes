% RUN_CODESIGN  Campaign D: assurance co-design table (planar CCV / EVV, clear + coastal,
% |w| <= 0.025 m/s). Rows (existing results reused, only the combined row is computed):
%   baseline    30 deg, res_32,      loc 0.10  ccv/ccv_summary_2d_res_32.csv
%   optical     45 deg, res_32,      loc 0.10  ccv/ccv_summary_fov45_res_32.csv      (12k)
%   control     30 deg, res_32_sway, loc 0.10  ccv/ccv_summary_b3w025_res_32_sway.csv (12l)
%   navigation  30 deg, res_32,      loc 0.05  ccv/ccv_summary_2d_res_32.csv (a smaller
%               localisation bound as a proxy for a better estimator)
%   optical+navigation 45 deg, res_32, loc 0.05  ccv/ccv_summary_fov45_res_32.csv (12k)
%               (the combined row without the control upgrade, since res_32_sway has no
%               certificate anywhere, 12l)
%   combined    45 deg, res_32_sway, loc 0.05  computed here -> results/codesign/
% Output: results/codesign/codesign_table.csv, figures/fig_codesign.pdf
if ~exist('cdRun','var'), cdRun = true; end
P0 = setup_paths(); od = fullfile(P0.results,'codesign'); if ~exist(od,'dir'), mkdir(od); end
fComb = fullfile(od, 'ccv_summary_combined_res_32_sway.csv');
if cdRun && ~exist(fComb,'file')
    diary(fullfile(P0.results,'logs','codesign.log'));
    roS = default_eo().ro; roS.timeStep = 0.02; roS.taylorTerms = 6;     % B3 reach settings
    Pover = @(Q) link_variant(Q, 'FOV', 45);
    actorTag = 'res_32_sway'; ccvModel = '2d'; ccvTag = 'combined'; ccvLocs = 0.05; ccvWaters = [1 2];
    ccvRo = roS; ccvOutDir = od; ccvSkipW = true;
    run_ccv;
    diary off
end
P0 = uwoc_params(); C = fullfile(P0.results,'ccv'); od = fullfile(P0.results,'codesign');
src = {'baseline',   30, "res_32",      0.10, fullfile(C,'ccv_summary_2d_res_32.csv');
       'optical',    45, "res_32",      0.10, fullfile(C,'ccv_summary_fov45_res_32.csv');
       'control',    30, "res_32_sway", 0.10, fullfile(C,'ccv_summary_b3w025_res_32_sway.csv');
       'navigation', 30, "res_32",      0.05, fullfile(C,'ccv_summary_2d_res_32.csv');
       'optical+navigation', 45, "res_32", 0.05, fullfile(C,'ccv_summary_fov45_res_32.csv');
       'combined',   45, "res_32_sway", 0.05, fullfile(od,'ccv_summary_combined_res_32_sway.csv')};
rows = {};
for i = 1:size(src,1)
    if ~exist(src{i,5},'file'), fprintf('missing %s\n', src{i,5}); continue; end
    S = readtable(src{i,5}, 'TextType', 'string');
    for w = ["clear","coastal"]
        m = S.water == w & abs(S.loc_m - src{i,4}) < 1e-9;
        rows(end+1,:) = {src{i,1}, src{i,2}, src{i,3}, src{i,4}, w, S.CCV(m), S.EVV(m), S.EVV_falsified(m), S.EVV_inconclusive(m), ...
            1 - S.CCV(m)/max(S.EVV(m),eps), string(src{i,5})}; %#ok<SAGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'system','fov_deg','controller','loc_m','water','CCV','EVV','EVV_falsified','EVV_inconclusive','gap','source'});
T.dCCV_pct = nan(height(T),1); T.dEVV_pct = nan(height(T),1);
for i = 1:height(T)
    b = T(T.system == "baseline" & T.water == T.water(i), :);
    T.dCCV_pct(i) = 100*(T.CCV(i) - b.CCV)/b.CCV; T.dEVV_pct(i) = 100*(T.EVV(i) - b.EVV)/b.EVV;
end
T.source = strrep(T.source, [P0.root filesep], '');   % store paths relative to the repository root
writetable(T, fullfile(od,'codesign_table.csv')); disp(T(:, setdiff(T.Properties.VariableNames, {'source'}, 'stable')));
fig = figure('Visible','off','Units','centimeters','Position',[0 0 17 6]);
ws = ["clear","coastal"];
for k = 1:2
    ax = subplot(1,2,k); m = T.water == ws(k);
    b = bar(ax, categorical(T.system(m), T.system(m)), [T.CCV(m), T.EVV(m) - T.CCV(m)], 'stacked');
    b(1).FaceColor = [0 0.45 0.74]; b(2).FaceColor = [0.8 0.8 0.8];
    ylabel(ax, 'area (m^2)'); title(ax, sprintf('%s water', ws(k))); grid(ax, 'on');
    if k == 2, legend(ax, {'certified (CCV)','EVV not certified'}, 'Location','northwest','FontSize',7); end
end
exportgraphics(fig, fullfile(P0.figures,'fig_codesign.pdf'), 'ContentType','vector');
