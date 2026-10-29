function RR = reach_refine(P, net, cellc, ro, maxDepth)
% REACH_REFINE  Reachability with adaptive splitting of the initial box: a cell
% is certified for a property iff every leaf is certified. Only leaves that fail
% are split (i.e. refinement happens only where R touches the ACE boundary).
leaves = {cellc}; depth = 0;
RR = struct('maint',true,'est',true,'robust',true,'Mlow',inf,'possTx',false, ...
    'possRx',false,'possP',false,'tFirstViol',inf,'runtime',0,'nLeaves',0, ...
    'statuses',{{}},'provFirst','','widthE',0,'depth',0);
pending = {cellc}; dep = 0;
while ~isempty(pending)
    next = {};
    for i = 1:numel(pending)
        c = pending{i};
        r = reach_cell(P, net, c, ro);
        RR.runtime = RR.runtime + r.runtime; RR.nLeaves = RR.nLeaves + 1;
        RR.statuses{end+1} = r.status;
        ok_m = r.maint; ok_e = r.est;
        if (~ok_m || ~ok_e) && dep < maxDepth && ~startsWith(r.status,'error') && ~strcmp(r.status,'timeout')
            [c1, c2] = aux_split(c);
            next = [next, {c1, c2}]; %#ok<AGROW>
        else
            RR.maint = RR.maint && ok_m; RR.est = RR.est && ok_e; RR.robust = RR.robust && r.robust;
            RR.Mlow = min(RR.Mlow, r.Mlow);
            RR.possTx = RR.possTx || r.possTx; RR.possRx = RR.possRx || r.possRx; RR.possP = RR.possP || r.possP;
            if r.tFirstViol < RR.tFirstViol, RR.tFirstViol = r.tFirstViol; RR.provFirst = r.provFirst; end
            RR.widthE = max(RR.widthE, r.width_e_final);
        end
    end
    pending = next; dep = dep + 1;
end
RR.depth = dep - 1;
end

function [a, b] = aux_split(c)
sc = [0.5; deg2rad(6); deg2rad(4); 1; 1; 1; 0.25; 1; deg2rad(2)];   % normalisation
n = numel(c.lo); w = (c.hi - c.lo) ./ sc(1:n);
w(4:6) = 0; if n == 9, w(8) = 0; end
[~, j] = max(w);
m = (c.lo(j) + c.hi(j))/2;
a = c; a.hi(j) = m; b = c; b.lo(j) = m;
end
