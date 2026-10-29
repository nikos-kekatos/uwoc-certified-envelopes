function P = setup_paths()
% SETUP_PATHS  Add code + CORA to the path (client and, if open, pool workers).
P = uwoc_params();
addpath(P.code); addpath(genpath(P.cora));
end
