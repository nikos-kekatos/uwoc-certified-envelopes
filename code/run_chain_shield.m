% RUN_CHAIN_SHIELD  S1/S2 tables then the S3-S5 ablation.
diary(fullfile(fileparts(fileparts(mfilename('fullpath'))),'results','logs','chain_shield.log'));
t00 = tic;
clearvars -except t00; run_shield_tables; fprintf('[chain] tables done %.0f s\n', toc(t00));
clearvars -except t00; run_shield_v2; fprintf('[chain] shield v2 done %.0f s\n', toc(t00));
diary off
