% RUN_B3_EVAL  B3 evaluation of res_32_sway against res_32 (no shield).
%   (a) hero-map cells where Rx provenance dominated: |w| >= 0.05 m/s, loc <= 0.3 m, all
%       waters, both separations (120 cells of opmap_res_32), same eval settings as
%       run_operating_map (500 MC, falsifier 12 x 120, splitting depth 1);
%   (b) planar CCV at loc 0.1 m, |w| <= 0.025 and <= 0.05 m/s, clear + coastal (run_ccv);
%   (c) MC outage on the shield-B rows (current step to 1.0-3.0 x 0.05 m/s; s4_rows.mat),
%       200 trajectories each, seeds of the NN rows of run_shield_v2 (rng(1000 r + 20)).
% Reach settings for the 3-command closed loop: the fallback-model settings of S1
% (aug_dyn_fb, damping envelope |v| <= 0.35 m/s, time step 0.02 s, 6 Taylor terms).
% Reachability is skipped on cells/tiles that Monte Carlo already falsifies (verdict
% unchanged; eo.skipReachIfWitness).
% Output: results/b3/hero_rx_cells.csv|mat, results/b3/hero_rx_compare.csv,
% results/ccv/ccv_b3w*_res_32_sway.*, results/b3/shieldB_mc.csv
if ~exist('b3Stage','var'), b3Stage = {'a','b','c'}; end
P = setup_paths(); od = fullfile(P.results,'b3');
Ls = load(fullfile(od,'actor_res_32_sway.mat')); netS = Ls.net;
L0 = load(fullfile(P.results,'phase2','actor_res_32.mat')); net0 = L0.net;
roS = default_eo().ro; roS.timeStep = 0.02; roS.taylorTerms = 6;
t00 = tic;
if any(strcmp(b3Stage,'a'))
    M = load(fullfile(P.results,'opmap','opmap_res_32.mat'));
    sel = find(M.T.w_mps >= 0.05 - 1e-9 & M.T.loc_m <= 0.3 + 1e-9);
    eo = default_eo(); eo.precheck = true; eo.maxDepth = 1; eo.ro = roS; eo.skipReachIfWitness = true;
    [Rs, T] = run_cells(P, netS, M.cells(sel), eo, 10);
    T.range_class = M.T.range_class(sel);
    save(fullfile(od,'hero_rx_cells.mat'), 'Rs', 'T', 'sel', 'eo');
    writetable(T, fullfile(od,'hero_rx_cells.csv'));
    T0 = M.T(sel,:);
    C = table(T.water, T.d0_m, T.loc_m, T.w_mps, T0.verdict_maint, T0.provenance, T0.mc_outage_rate, T0.reach_status, ...
        T.verdict_maint, T.provenance, T.mc_outage_rate, T.reach_status, ...
        'VariableNames', {'water','d0_m','loc_m','w_mps','res32_verdict','res32_prov','res32_mc','res32_status', ...
        'sway_verdict','sway_prov','sway_mc','sway_status'});
    writetable(C, fullfile(od,'hero_rx_compare.csv'));
    disp(groupcounts(C, {'res32_verdict','sway_verdict'}));
    fprintf('[b3] stage a done %.0f s\n', toc(t00));
end
if any(strcmp(b3Stage,'b'))
    for wv = [0.025 0.05]
        clearvars -except t00 wv b3Stage P od netS net0 roS
        Pover = @(Q) setfield(Q, 'ccv', setfield(Q.ccv, 'w', wv)); %#ok<SFLD>
        actorTag = 'res_32_sway'; ccvModel = '2d'; ccvTag = sprintf('b3w%03d', round(1000*wv));
        ccvLocs = 0.1; ccvWaters = [1 2]; ccvRo = roS; ccvSkipW = true;
        run_ccv;
        fprintf('[b3] stage b w %.3f done %.0f s\n', wv, toc(t00));
    end
end
if any(strcmp(b3Stage,'c'))
    S4 = load(fullfile(P.results,'shield','s4_rows.mat'));
    rows = {};
    for r = 2:6
        G = S4.rows{r}; scen = scen_generic(P, G);
        for a = 1:2
            rng(1000*r + 10*2);                        % seed of the NN rows (c = 2) in run_shield_v2
            if a == 1, f = @(z,k,x,ex) deal([nn_forward(net0,z); zeros(1,size(z,2))], false(1,size(z,2))); nm = 'res_32';
            else,      f = @(z,k,x,ex) deal(nn_forward(netS,[z; ex.phih]), false(1,size(z,2))); nm = 'res_32_sway'; end
            o = sim_closed_loop(P, scen, f, struct('passExtra', true));
            k = sum(o.outage); n = numel(o.outage); [p, lo, hi] = aux_wilson(k, n);
            rows(end+1,:) = {S4.rowName{r}, nm, n, k, p, lo, hi, mean(o.violTx), mean(o.violRx), mean(o.violP), mean(o.tOut)}; %#ok<SAGROW>
        end
    end
    TC = cell2table(rows, 'VariableNames', {'row','controller','n','n_outage','outage_rate','ci_lo','ci_hi','Tx_rate','Rx_rate','P_rate','mean_outage_time_s'});
    writetable(TC, fullfile(od,'shieldB_mc.csv')); disp(TC);
end
fprintf('[b3] eval wall %.0f s\n', toc(t00));
function [p, lo, hi] = aux_wilson(k, n)
z = 1.96; p = k/n; den = 1 + z^2/n; c = (p + z^2/(2*n))/den;
h = z*sqrt(p*(1-p)/n + z^2/(4*n^2))/den; lo = max(0, c-h); hi = min(1, c+h);
end
