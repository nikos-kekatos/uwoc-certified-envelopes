function S = slowcur_cells(P)
% SLOWCUR_CELLS  Cell lists for campaign E (slowly varying current).
%   S.idxOp   indices into opmap cells (M.cells) of the 99 jobs
%   S.set     "unresolved67" | "certified_hero" | "certified_a2"
%   S.idxA2   index among the 74 A2 cells (0 for hero-map Certified cells)
%   S.nearEdge true for the 39 unresolved cells of class_adv "borderline" (diag70)
%   S.M, S.A2 the loaded tables
% Unresolved = A2 final_T20 Inconclusive (70) minus the 3 cells falsified by the sideways
% adversary (diag70/sideways_cells.csv, found_any & group inconclusive70).
M = load(fullfile(P.results,'opmap','opmap_res_32.mat'));
sel74 = find(M.T.verdict_maint == "Inconclusive");
A2 = readtable(fullfile(P.results,'a2','a2_inconclusive.csv'), 'TextType', 'string');
assert(height(A2) == numel(sel74));
SW = readtable(fullfile(P.results,'diag70','sideways_cells.csv'), 'TextType', 'string');
DB = readtable(fullfile(P.results,'diag70','drift_budget.csv'), 'TextType', 'string');
fals3 = SW.cell(SW.found_any == 1 & SW.group == "inconclusive70");
assert(numel(fals3) == 3);
iUnres = find(A2.final_T20 == "Inconclusive");
keep = ~ismember(sel74(iUnres), fals3); iUnres = iUnres(keep);       % 67
iA2cert = find(startsWith(A2.final_T20, "Certified"));               % 3
selCert = find(M.T.verdict_maint == "Certified");                    % 29
S.set = [repmat("unresolved67",numel(iUnres),1); repmat("certified_hero",numel(selCert),1); repmat("certified_a2",numel(iA2cert),1)];
S.idxOp = [sel74(iUnres); selCert; sel74(iA2cert)];
S.idxA2 = [iUnres; zeros(numel(selCert),1); iA2cert];
ne = DB.cell(DB.class_adv == "borderline" & DB.verdict == "Unresolved");
S.nearEdge = ismember(S.idxOp, ne) & S.set == "unresolved67";
S.fals3 = fals3; S.M = M; S.A2 = A2;
assert(numel(S.idxOp) == 99 && nnz(S.set == "unresolved67") == 67 && nnz(S.nearEdge) == 39);
end
