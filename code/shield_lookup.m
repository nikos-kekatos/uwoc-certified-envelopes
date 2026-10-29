function ok = shield_lookup(TB, wi, box)
% SHIELD_LOOKUP  True iff every runtime tile (water wi) overlapping the box
% [d; phi; e; u; r] x [lo hi] is Certified in TB (load_shield_tables) and the box lies
% inside the tiled region.
T = TB{wi};
if isempty(T), ok = false; return; end
E = T.E; ed = {E.d, E.p, E.e, E.u, E.r}; ix = cell(1,5);
for k = 1:5
    if box(k,1) < ed{k}(1) || box(k,2) > ed{k}(end), ok = false; return; end
    ix{k} = find(ed{k}(1:end-1) < box(k,2) & ed{k}(2:end) > box(k,1));
end
c = T.cert(ix{:});
ok = all(c(:));
end
