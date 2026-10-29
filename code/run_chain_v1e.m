% RUN_CHAIN_V1E  ladders (continuous 6-DOF inner loops), shield, width observation.
diary(fullfile(fileparts(fileparts(mfilename('fullpath'))),'results','logs','chain_v1e.log'));
t00 = tic;
clearvars -except t00; actorTag = 'res_32'; ladderLoc = 0.1; run_ladder_ccv; fprintf('[chain] ladder_ccv done %.0f s\n', toc(t00));
clearvars -except t00; actorTag = 'res_32'; run_ladder; fprintf('[chain] ladder levels done %.0f s\n', toc(t00));
clearvars -except t00; actorTag = 'res_32'; nTraj = 40; run_phase6_shield; fprintf('[chain] shield done %.0f s\n', toc(t00));
clearvars -except t00; run_width_obs; fprintf('[chain] width obs done %.0f s\n', toc(t00));
diary off
