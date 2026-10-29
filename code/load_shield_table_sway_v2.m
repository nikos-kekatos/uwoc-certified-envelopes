function TB = load_shield_table_sway_v2(P, fname)
% LOAD_SHIELD_TABLE_SWAY_V2  Certified-tile lookup array (d x phi x e x u x v x r) of the
% sway fallback from results/shield/table_sway_v2.mat (run_shield_table_sway_v2).
if nargin < 2, fname = fullfile(P.results,'shield','table_sway_v2.mat'); end
S = load(fname); T = S.T; TB = cell(1,3);
for wi = 1:3
    m = T.water == P.water.name{wi};
    if ~any(m), continue; end
    E.d = unique([T.d_lo(m); T.d_hi(m)])'; E.p = deg2rad(unique([T.phi_lo_deg(m); T.phi_hi_deg(m)]))';
    E.e = deg2rad(unique([T.e_lo_deg(m); T.e_hi_deg(m)]))';
    E.u = unique([T.u_lo(m); T.u_hi(m)])'; E.v = unique([T.v_lo(m); T.v_hi(m)])'; E.r = unique([T.r_lo(m); T.r_hi(m)])';
    cert = false(numel(E.d)-1, numel(E.p)-1, numel(E.e)-1, numel(E.u)-1, numel(E.v)-1, numel(E.r)-1);
    for j = find(m)'
        ix = {aux_i(E.d, T.d_lo(j)), aux_i(E.p, deg2rad(T.phi_lo_deg(j))), aux_i(E.e, deg2rad(T.e_lo_deg(j))), ...
              aux_i(E.u, T.u_lo(j)), aux_i(E.v, T.v_lo(j)), aux_i(E.r, T.r_lo(j))};
        cert(ix{:}) = T.verdict_maint(j) == "Certified";
    end
    TB{wi} = struct('E', E, 'cert', cert);
end
end
function i = aux_i(edges, v), [~, i] = min(abs(edges - v)); end
