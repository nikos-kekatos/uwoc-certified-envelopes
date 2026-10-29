function ok = shield_lookup_v2(TB, wi, box)
% SHIELD_LOOKUP_V2  True iff every tile (water wi) of the v2 sway table overlapping the
% box [d; phi; e; u; v; r] x [lo hi] is Certified and the box lies inside the tiled region.
T = TB{wi};
if isempty(T), ok = false; return; end
E = T.E; ed = {E.d, E.p, E.e, E.u, E.v, E.r}; ix = cell(1,6);
for k = 1:6
    if box(k,1) < ed{k}(1) || box(k,2) > ed{k}(end), ok = false; return; end
    ix{k} = find(ed{k}(1:end-1) < box(k,2) & ed{k}(2:end) > box(k,1));
end
c = T.cert(ix{:});
ok = all(c(:));
end
