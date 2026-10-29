% RUN_CHAIN_NEXT2  B1 hardware sweep and A3 localisation cliff (after the baseline note).
diary(fullfile(fileparts(fileparts(mfilename('fullpath'))),'results','logs','chain_next2.log'));
t00 = tic;
clearvars -except t00; run_b1_slices; fprintf('[chain] B1 done %.0f s\n', toc(t00));
clearvars -except t00; actorTag = 'res_32'; ccvModel = '2d'; ccvTag = 'a3_box'; ccvLocs = [0.15 0.2 0.25]; ccvWaters = [1 2]; run_ccv; fprintf('[chain] A3 box done %.0f s\n', toc(t00));
clearvars -except t00; actorTag = 'res_32'; ccvModel = '2d'; ccvTag = 'a3_disk'; ccvLocs = [0.15 0.2]; ccvWaters = [1 2]; ccvLocModel = 'disk'; run_ccv; fprintf('[chain] A3 disk done %.0f s\n', toc(t00));
diary off
