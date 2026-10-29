function LT = load_shield_tables(P)
% LOAD_SHIELD_TABLES  Certified-tile lookup arrays (d x phi x e x u x r) from
% results/shield/table_*.mat (run_shield_tables).
names = {'nn','sway','old'};
for n = 1:numel(names)
    S = load(fullfile(P.results,'shield',['table_' names{n} '.mat'])); T = S.T;
    TB = cell(1,3);
    for wi = 1:3
        m = T.water == P.water.name{wi};
        if ~any(m), continue; end
        E.d = unique([T.d_lo(m); T.d_hi(m)])'; E.p = deg2rad(unique([T.phi_lo_deg(m); T.phi_hi_deg(m)]))';
        E.e = deg2rad(unique([T.e_lo_deg(m); T.e_hi_deg(m)]))';
        E.u = unique([T.u_lo(m); T.u_hi(m)])'; E.r = unique([T.r_lo(m); T.r_hi(m)])';
        cert = false(numel(E.d)-1, numel(E.p)-1, numel(E.e)-1, numel(E.u)-1, numel(E.r)-1);
        for j = find(m)'
            ix = {aux_i(E.d, T.d_lo(j)), aux_i(E.p, deg2rad(T.phi_lo_deg(j))), aux_i(E.e, deg2rad(T.e_lo_deg(j))), ...
                  aux_i(E.u, T.u_lo(j)), aux_i(E.r, T.r_lo(j))};
            cert(ix{:}) = T.verdict_maint(j) == "Certified";
        end
        TB{wi} = struct('E', E, 'cert', cert);
    end
    LT.(names{n}) = TB;
end
end
function i = aux_i(edges, v), [~, i] = min(abs(edges - v)); end
