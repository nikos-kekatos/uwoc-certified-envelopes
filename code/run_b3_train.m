% RUN_B3_TRAIN  B3: res_32_sway, a residual MLP (linear skip + 2x32 ReLU) with 7 inputs
% [d_hat; e_hat; u; v; r; c_hat; phi_hat] and 3 outputs [u_c; r_c; v_c], trained by
% imitation of teacher_sway_policy exactly as run_phase2_train trains res_32 (same data
% recipe, 90/10 split, train_actor 'res', 60 epochs, Adam).
% Output: results/b3/teacher_sway_data.mat, results/b3/actor_res_32_sway.mat (copied to
% results/phase2/ for the loaders of run_ccv / run_operating_map),
% results/b3/imitation_error.csv, results/b3/closed_loop_summary.csv
P = setup_paths();
od = fullfile(P.results,'b3'); if ~exist(od,'dir'), mkdir(od); end
diary(fullfile(P.results,'logs','b3_train.log'));
fdata = fullfile(od,'teacher_sway_data.mat');
if exist(fdata,'file'), load(fdata);
else
    [Z, Y, src] = gen_teacher_data_sway(P, 150000, 60, 11);
    rng(12);
    iR = find(src==1); iR = iR(randperm(numel(iR), min(200000,numel(iR))));
    iU = find(src==0);
    idx = [iU, iR]; Z = Z(:,idx); Y = Y(:,idx); src = src(idx);
    perm = randperm(numel(src)); nTe = round(0.1*numel(src));
    te = perm(1:nTe); tr = perm(nTe+1:end);
    save(fdata,'Z','Y','src','tr','te','-v7.3');
end
sat = [P.uc_max; P.rc_max; P.b3.vc_max];
[net, info] = train_actor(P, 32, Z(:,tr), Y(:,tr), 132, 60, 'res', [], sat);
net.name = 'res_32_sway'; net.nIn = 7;
save(fullfile(od,'actor_res_32_sway.mat'), 'net', 'info');
copyfile(fullfile(od,'actor_res_32_sway.mat'), fullfile(P.results,'phase2','actor_res_32_sway.mat'));
rows = {};
for set = 0:1
    m = te(src(te)==set); e = nn_forward(net, Z(:,m)) - Y(:,m);
    rows(end+1,:) = {set, numel(m), sqrt(mean(e(1,:).^2)), sqrt(mean(e(2,:).^2)), sqrt(mean(e(3,:).^2)), ...
        max(abs(e(1,:))), max(abs(e(2,:))), max(abs(e(3,:))), info.trainTime}; %#ok<SAGROW>
end
T = cell2table(rows, 'VariableNames', {'testset_rollout','n','rmse_uc','rmse_rc','rmse_vc','maxerr_uc','maxerr_rc','maxerr_vc','train_time_s'});
writetable(T, fullfile(od,'imitation_error.csv')); disp(T);
% closed-loop sanity (sampled), same scenario groups as run_phase2_train
L0 = load(fullfile(P.results,'phase2','actor_res_32.mat'));
ctrls = {'teacher','res_32','teacher_sway','res_32_sway'}; rows = {};
for wi = 1:3
  dout = fzero(@(d) margin_db(P,d,0,0,P.water.c(wi)), [0.2 60]);
  for d0 = max(1.0, round(4*[0.3 0.5 0.7]*dout)/4)
    for e0 = deg2rad([5 10])
      for cur = [0.05 0.10]
        cfg = struct('c',P.water.c(wi),'d0',d0,'e0',e0,'loc',P.loc_train,'w',cur);
        for ci = 1:4
            rng(1000 + wi*100 + round(d0*40) + round(rad2deg(e0)) + round(cur*100));
            s = make_scen(P, 300, cfg);
            switch ci
                case 1, f = @(z,k,x,ph) deal(teacher_policy(P,z), false(1,size(z,2)));
                case 2, f = @(z,k,x,ph) deal(nn_forward(L0.net,z), false(1,size(z,2)));
                case 3, f = @(z,k,x,ph) deal(teacher_sway_policy(P,[z;ph]), false(1,size(z,2)));
                case 4, f = @(z,k,x,ph) deal(nn_forward(net,[z;ph]), false(1,size(z,2)));
            end
            o = sim_closed_loop(P, s, f, struct('passPhiHat', true));
            rows(end+1,:) = {ctrls{ci}, P.water.name{wi}, d0, rad2deg(e0), cur, mean(o.outage), ...
                mean(o.violTx), mean(o.violRx), mean(o.violP), mean(o.Mmin), mean(o.tRobust)/P.T, mean(o.effort)}; %#ok<SAGROW>
        end
      end
    end
  end
end
C = cell2table(rows, 'VariableNames', {'controller','water','d0_m','e0_deg','w_mps','outage_rate','Tx_rate','Rx_rate','Power_rate','mean_Mmin_dB','robust_frac','effort'});
writetable(C, fullfile(od,'closed_loop_performance.csv'));
S = groupsummary(C, 'controller', 'mean', {'outage_rate','Tx_rate','Rx_rate','Power_rate','mean_Mmin_dB','robust_frac'});
writetable(S, fullfile(od,'closed_loop_summary.csv')); disp(S);
diary off
