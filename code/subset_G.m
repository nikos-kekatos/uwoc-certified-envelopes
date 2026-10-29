function H = subset_G(G, idx)
% SUBSET_G  Column subset of a scen_generic parameter struct (fields with N columns).
N = size(G.x0,2); f = fieldnames(G); H = G;
for i = 1:numel(f)
    v = G.(f{i});
    if isnumeric(v) || islogical(v)
        if size(v,2) == N, H.(f{i}) = v(:, idx); end
    end
end
end
