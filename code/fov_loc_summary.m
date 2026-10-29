% FOV_LOC_SUMMARY  Table and figure for campaign A (run_fov_loc).
% Output: results/fov_loc/fov_loc_table.csv, figures/fig_fov_loc.pdf
P = uwoc_params(); C = fullfile(P.results,'ccv');
S30 = [readtable(fullfile(C,'ccv_summary_2d_res_32.csv'),'TextType','string'); ...
       readtable(fullfile(C,'ccv_summary_a3_box_res_32.csv'),'TextType','string')];
S30 = S30(S30.water ~= "turbid" & S30.loc_m <= 0.3, :); S30.fov_deg = 30*ones(height(S30),1);
S30.source = repmat("reused", height(S30), 1);
S = S30;
for fov = [20 45]
    f = fullfile(C, sprintf('ccv_summary_fov%d_res_32.csv', fov));
    if ~exist(f,'file'), continue; end
    Q = readtable(f,'TextType','string'); Q.fov_deg = fov*ones(height(Q),1); Q.source = repmat("new", height(Q), 1);
    S = [S; Q]; %#ok<AGROW>
end
S = sortrows(S, {'water','fov_deg','loc_m'});
S = S(:, {'water','fov_deg','loc_m','CCV','EVV','EVV_falsified','EVV_inconclusive','overestimation_frac','reach_cpu_s','source'});
od = fullfile(P.results,'fov_loc'); if ~exist(od,'dir'), mkdir(od); end
writetable(S, fullfile(od,'fov_loc_table.csv')); disp(S);
fig = figure('Visible','off','Units','centimeters','Position',[0 0 17 6.5]);
ws = ["clear","coastal"]; fovs = [20 30 45]; col = [0.85 0.33 0.10; 0 0.45 0.74; 0.47 0.67 0.19];
for k = 1:2
    ax = subplot(1,2,k); hold(ax,'on');
    for i = 1:3
        m = S.water == ws(k) & S.fov_deg == fovs(i);
        if ~any(m), continue; end
        plot(ax, S.loc_m(m), S.CCV(m), '-o', 'Color', col(i,:), 'LineWidth', 1.4, 'MarkerFaceColor', col(i,:), 'DisplayName', sprintf('CCV, FOV %d°', fovs(i)));
        plot(ax, S.loc_m(m), S.EVV(m), '--', 'Color', col(i,:), 'LineWidth', 1.0, 'DisplayName', sprintf('EVV, FOV %d°', fovs(i)));
    end
    title(ax, sprintf('%s water', ws(k))); xlabel(ax, 'localisation error bound (m)'); ylabel(ax, 'area (m^2)');
    grid(ax,'on'); xlim(ax,[0.04 0.31]);
    if k == 2, legend(ax, 'Location', 'eastoutside', 'FontSize', 7); end
end
exportgraphics(fig, fullfile(P.figures,'fig_fov_loc.pdf'), 'ContentType','vector');
