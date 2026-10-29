% RUN_WIDTH_OBS  Small observation: 2-D CCV at
% localisation 0.1 m, |w| <= 0.025 m/s for actors of different width/architecture,
% compared with their (near-identical) sampled closed-loop performance.
diary(fullfile(fileparts(fileparts(mfilename('fullpath'))),'results','logs','width_obs.log'));
tags = {'mlp_16','mlp_32','mlp_256','res_16','res_256'};
for i = 1:numel(tags)
    clearvars -except tags i; actorTag = tags{i}; ccvModel = '2d'; ccvTag = '2d_loc01'; ccvLocs = 0.1; run_ccv;
end
diary off
