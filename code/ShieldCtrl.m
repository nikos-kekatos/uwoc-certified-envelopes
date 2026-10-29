classdef ShieldCtrl < handle
% SHIELDCTRL  Runtime-assurance controller for the S2-S5 experiments.
%   check   : 'none' (NN only), 'lookup' (precomputed 4 s certificates, S2) or
%             'online' (short-horizon CORA check, shield_check)
%   fb      : 'old' (slow down, turn to Rx) or 'sway' (sway-capable, S1)
%   monitor : true -> online current estimate (DVL ground minus water velocity,
%             low-pass) flags violations of the declared bound (S3); a flag forces
%             the fallback
% Accept the actor's command iff the check certifies it and no monitor flag is set;
% otherwise apply the fallback. Interventions are scored as unnecessary when a
% counterfactual NN-only rollout (true state, true current, 4 s) has no outage.
properties
    P; net; check; fb; monitor; wi; decl; LT; sh; fbOld; fbSway; scen
    alpha = 0.5/3; thr; wf; flag; firstFlag
    nInterv; nUnnec; nSteps; tDec = []; agree = [0 0 0 0]   % [both acc, both rej, lut rej only, online rej only]
    nFbCertHits; fbCert
    % optional (default off; added for run_shield_sway_v2_eval): v2 sway table with
    % velocity bins, and a per-step log of every fallback step
    LTv2 = []; logFb = false; fbLog = zeros(0,23); prevFb
end
methods
    function obj = ShieldCtrl(P, net, check, fb, monitor, wi, decl, LT, sh, scen)
        obj.P = P; obj.net = net; obj.check = check; obj.fb = fb; obj.monitor = monitor;
        obj.wi = wi; obj.decl = decl; obj.LT = LT; obj.sh = sh; obj.scen = scen;
        obj.fbOld = fallback_net(P);
        obj.fbSway = arrayfun(@(w) fallback_sway(P, w), 1:3, 'uni', 0);
        N = numel(wi); obj.wf = zeros(2,N); obj.flag = false(1,N); obj.firstFlag = nan(1,N);
        obj.nInterv = zeros(1,N); obj.nUnnec = zeros(1,N); obj.nSteps = 0; obj.nFbCertHits = zeros(1,N); obj.fbCert = nan(1,N);
        obj.thr = decl.w; obj.prevFb = false(1,N);
    end
    function [cmd, iv] = step(obj, z, k, x, ex)
        P = obj.P; N = size(z,2); obj.nSteps = obj.nSteps + 1;
        nn = nn_forward(obj.net, z);
        cmd = [nn; zeros(1,N)]; iv = false(1,N);
        if obj.monitor                                     % S3: current monitor
            obj.wf = (1-obj.alpha)*obj.wf + obj.alpha*ex.wmeas;
            mag = sqrt(sum(obj.wf.^2,1));
            newf = ~obj.flag & mag > obj.thr; obj.firstFlag(newf & isnan(obj.firstFlag)) = ex.t;
            obj.flag = (obj.flag & mag > 0.9*obj.thr) | mag > obj.thr;   % hysteresis
        end
        if strcmp(obj.check,'none') && ~obj.monitor, return; end
        for i = 1:N
            t0 = tic;
            okNN = true;
            switch obj.check
                case 'lookup'
                    okNN = obj.lut(z(:,i), ex.phih(i), nn(:,i), i, 'nn');
                case 'online'
                    sh = obj.sh; sh.c = P.water.c(obj.wi(i)); sh.phihat = ex.phih(i);
                    if strcmp(obj.fb,'sway'), sh.fbnet = obj.fbSway{obj.wi(i)}; end
                    okNN = shield_check(P, sh.Sfb, z(:,i), nn(:,i), sh);
                    okL = obj.lut(z(:,i), ex.phih(i), nn(:,i), i, 'nn');
                    obj.agree = obj.agree + [okNN&&okL, ~okNN&&~okL, okNN&&~okL, ~okNN&&okL];
            end
            acc = okNN && ~(obj.monitor && obj.flag(i));
            obj.tDec(end+1) = toc(t0);
            if ~acc
                iv(i) = true; obj.nInterv(i) = obj.nInterv(i) + 1;
                if strcmp(obj.fb,'sway')
                    cmd(:,i) = nn_forward(obj.fbSway{obj.wi(i)}, [z(:,i); ex.phih(i)]);
                else
                    cmd(:,i) = [nn_forward(obj.fbOld, z(:,i)); 0];
                end
                obj.nUnnec(i) = obj.nUnnec(i) + obj.counterfactualOK(x, i, ex.t);
                % is the fallback certified (4 s) from the current estimate box?
                obj.nFbCertHits(i) = obj.nFbCertHits(i) + obj.fbTileCert(z(:,i), ex.phih(i), i);
                obj.fbCert(i) = obj.nFbCertHits(i)/obj.nInterv(i);
                if obj.logFb
                    c1 = obj.fbTileCert(z(:,i), ex.phih(i), i);
                    c2 = nan; tl = nan;
                    if ~isempty(obj.LTv2), t1 = tic; c2 = obj.fbTileCertV2(z(:,i), ex.phih(i), i); tl = toc(t1); end
                    wt = obj.scen.wfun(ex.t, x); wt = norm(wt(:,i));
                    % [traj t wasActive dh eh uh vh rh phih d phi e u v r |w| certV1 certV2 tLookupV2 wi accNN monitorFlag pad]
                    obj.fbLog(end+1,:) = [i ex.t obj.prevFb(i) z(1:5,i)' ex.phih(i) x(:,i)' wt c1 c2 tl obj.wi(i) okNN double(obj.monitor && obj.flag(i)) 0];
                end
            end
        end
        obj.prevFb = iv;
    end
    function ok = fbTileCertV2(obj, zi, ph, i)
        % as fbTileCert, on the v2 sway table (velocity bins in u, v and r)
        P = obj.P; loc = obj.decl.loc; d = zi(1); ab = asin(min(loc/max(d - loc, 0.3), 1));
        mg = [loc; ab; P.eps_psi + ab; P.eps_u; P.eps_v; P.eps_r]; xh = [zi(1); ph; zi(2); zi(3); zi(4); zi(5)];
        ok = shield_lookup_v2(obj.LTv2, obj.wi(i), [xh - mg, xh + mg]);
    end
    function ok = lut(obj, zi, ph, cmd, i, tab)
        % one-step prediction of the estimate under cmd (no current), inflated by the
        % declared error and drift bounds, must lie in certified tiles of table tab
        P = obj.P; D = P.dt_ctrl; loc = obj.decl.loc; w = obj.decl.w;
        xh = [zi(1); ph; zi(2); zi(3:5)];
        for s = 1:5, xh = xh + D/5*plant_f(P, xh, cmd, [0;0]); end
        d = xh(1); ab = asin(min(loc/max(d - loc, 0.3), 1));
        mg = [loc + w*D + 0.05; ab + w*D/d + deg2rad(1); P.eps_psi + ab + w*D/d + deg2rad(1); ...
              P.eps_u + 0.02; P.eps_r + 0.02];
        xs = [xh(1:4); xh(6)];
        box = [xs - mg, xs + mg];
        ok = abs(xh(5)) + P.eps_v + 0.01 <= 0.05 && shield_lookup(obj.LT.(tab), obj.wi(i), box);   % tiles: |v| <= 0.05
    end
    function ok = fbTileCert(obj, zi, ph, i)
        P = obj.P; loc = obj.decl.loc; d = zi(1); ab = asin(min(loc/max(d - loc, 0.3), 1));
        mg = [loc; ab; P.eps_psi + ab; P.eps_u; P.eps_r]; xh = [zi(1); ph; zi(2); zi(3); zi(5)];
        ok = abs(zi(4)) + P.eps_v <= 0.05 && shield_lookup(obj.LT.(obj.fb), obj.wi(i), [xh - mg, xh + mg]);
    end
    function u = counterfactualOK(obj, x, i, t)
        % NN-only rollout from the TRUE state to the end of the episode under the TRUE
        % current (time-shifted): 1 if no outage
        P = obj.P; sc = obj.scen; N = size(sc.x0,2);
        s1.x0 = x(:,i); s1.c = sc.c(i); s1.chat = sc.chat(i);
        s1.wfun = @(tt,xx) aux_col(sc.wfun(t+tt, repmat(xx,1,N)), i);
        loc = obj.decl.loc;
        s1.noise = @(kk,xx) struct('dpos', loc*sqrt(rand)*[cos(2*pi*rand); sin(2*pi*rand)], ...
            'dpsi', P.eps_psi*(2*rand-1), 'du', P.eps_u*(2*rand-1), 'dv', P.eps_v*(2*rand-1), 'dr', P.eps_r*(2*rand-1));
        Trem = max(P.dt_ctrl, round((P.T - t)/P.dt_ctrl)*P.dt_ctrl);   % rest of the episode
        o = sim_closed_loop(P, s1, @(zz,kk,xx) deal(nn_forward(obj.net, zz), false), struct('T', Trem));
        u = ~o.outage;
    end
end
end

function c = aux_col(W, i), c = W(:,i); end
