% RUN_PHASE2_TRAIN  Train compact ReLU actors by imitation; report imitation
% error AND closed-loop link performance (Monte Carlo, sampled, not verification).
P = uwoc_params();
outdir = fullfile(P.results,'phase2'); if ~exist(outdir,'dir'), mkdir(outdir); end
fdata = fullfile(outdir,'teacher_data.mat');
if exist(fdata,'file')
    load(fdata);
else
    [Z, Y, src] = gen_teacher_data(P, 150000, 60, 11);
    rng(12);
    iR = find(src==1); iR = iR(randperm(numel(iR), min(200000,numel(iR))));
    iU = find(src==0);
    idx = [iU, iR]; Z = Z(:,idx); Y = Y(:,idx); src = src(idx);
    perm = randperm(numel(src)); nTe = round(0.1*numel(src));
    te = perm(1:nTe); tr = perm(nTe+1:end);
    save(fdata,'Z','Y','src','tr','te','-v7.3');
end
widths = [16 32 64 256]; archs = {'mlp','res'};
rows = {};
for a = 1:2
for H = widths
    [net, info] = train_actor(P, H, Z(:,tr), Y(:,tr), 100+H, 60, archs{a});
    net.name = sprintf('%s%d', archs{a}, H);
    save(fullfile(outdir, sprintf('actor_%s_%d.mat',archs{a},H)), 'net', 'info');
    for set = 0:1
        m = te(src(te)==set);
        e = nn_forward(net, Z(:,m)) - Y(:,m);
        rows(end+1,:) = {archs{a}, H, set, numel(m), sqrt(mean(e(1,:).^2)), sqrt(mean(e(2,:).^2)), ...
            max(abs(e(1,:))), max(abs(e(2,:))), info.trainTime}; %#ok<SAGROW>
    end
    fprintf('trained %s %d (%.1fs)\n', archs{a}, H, info.trainTime);
end
end
T = cell2table(rows, 'VariableNames', {'arch','width','testset_rollout','n','rmse_tau_u_N','rmse_tau_r_Nm', ...
    'maxerr_tau_u_N','maxerr_tau_r_Nm','train_time_s'});
writetable(T, fullfile(outdir,'imitation_error.csv'));
disp(T)

% ---- closed-loop link performance (same scenarios for every controller) ----
ctrls = {'teacher'}; files = {''};
for a = 1:2, for H = widths, ctrls{end+1} = sprintf('%s%d',archs{a},H); files{end+1} = sprintf('actor_%s_%d.mat',archs{a},H); end, end
rows = {};
for wi = 1:3
  dout = fzero(@(d) margin_db(P,d,0,0,P.water.c(wi)), [0.2 60]);
  for d0 = max(1.0, round(4*[0.3 0.5 0.7]*dout)/4)
    for e0 = deg2rad([5 10])
      for cur = [0.05 0.10]
        cfg = struct('c',P.water.c(wi),'d0',d0,'e0',e0,'loc',P.loc_train,'w',cur);
        for ci = 1:numel(ctrls)
            rng(1000 + wi*100 + round(d0*40) + round(rad2deg(e0)) + round(cur*100));  % identical scenarios
            s = make_scen(P, 300, cfg);
            if ci == 1
                f = @(z,k,x) deal(teacher_policy(P,z), false(1,size(z,2)));
            else
                L = load(fullfile(outdir, files{ci}));
                f = @(z,k,x) deal(nn_forward(L.net,z), false(1,size(z,2)));
            end
            o = sim_closed_loop(P, s, f);
            rows(end+1,:) = {ctrls{ci}, P.water.name{wi}, d0, rad2deg(e0), cur, mean(o.outage), ...
                mean(o.violTx), mean(o.violRx), mean(o.violP), mean(o.Mmin), median(o.Mmin), ...
                mean(o.tRobust)/P.T, mean(o.tOut)/P.T, mean(o.effort)}; %#ok<SAGROW>
        end
      end
    end
  end
end
C = cell2table(rows, 'VariableNames', {'controller','water','d0_m','e0_deg','w_mps','outage_rate', ...
    'Tx_rate','Rx_rate','Power_rate','mean_Mmin_dB','median_Mmin_dB','robust_frac','outage_frac','effort'});
writetable(C, fullfile(outdir,'closed_loop_performance.csv'));
S = groupsummary(C, 'controller', 'mean', {'outage_rate','mean_Mmin_dB','robust_frac','outage_frac','effort'});
writetable(S, fullfile(outdir,'closed_loop_summary.csv'));
disp(S)
