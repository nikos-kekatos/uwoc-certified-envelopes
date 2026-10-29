function P = uwoc_params()
% UWOC_PARAMS  All model constants (CALIBRATED set "v1", 2026-10-04). Every constant
% is listed in MODEL.md with its source and status (VERIFIED in the cited source /
% ASSUMED design or scenario choice). The provisional v0 set is not distributed.

% ---------------- paths ----------------
P.root    = fileparts(fileparts(mfilename('fullpath')));   % repository root
P.code    = fullfile(P.root,'code');
P.results = fullfile(P.root,'results');
P.figures = fullfile(P.root,'figures');                     % paper figures (PDF)
P.models  = fullfile(P.root,'models');                      % deployed actor (JSON, ONNX)
% CORA location: environment variable CORA_PATH, else <userpath>/CORA
% (userpath is ~/Documents/MATLAB on macOS by default).
P.cora    = getenv('CORA_PATH');
if isempty(P.cora), P.cora = fullfile(strtok(userpath, pathsep), 'CORA'); end

% ---------------- water (Petzold 1972 via Mobley 1994, Table 3.11, p.112) ----
% b measured at 514 nm, c measured at 530 nm, a = c(530) - b(514).
P.water.name = {'clear','coastal','turbid'};
P.water.a    = [0.114 0.179 0.366];
P.water.b    = [0.037 0.219 1.824];
P.water.c    = [0.151 0.398 2.190];
P.c_rel_unc  = 0.10;   % ASSUMED declared uncertainty of c (+-10 %)

% ---------------- optical link --------------------------------------------
P.lambda   = 532e-9;            % m, green (Celik 2020 Tab. I; Jamali 2017 Tab. I)
P.Pt       = 0.1;               % W  (N'Doye et al. 2021, Table 1)
P.Phi_half = deg2rad(15);       % Lambertian half-power semi-angle (N'Doye Tab. 1)
P.m_lamb   = -log(2)/log(cos(P.Phi_half));   % Lambertian order (N'Doye Eq. 1)
P.eta_t    = 0.9; P.eta_r = 0.9;% Tx/Rx optical efficiencies (Celik 2020 Tab. I)
P.Ar       = 1e-4;              % m^2, detector area 1 cm^2 (N'Doye Tab. 1)
P.Psi_C    = deg2rad(30);       % concentrator FOV half-angle (N'Doye Tab. 1)
P.n_conc   = 1.52;              % concentrator refractive index (N'Doye Tab. 1)
P.gconc    = P.n_conc^2/sin(P.Psi_C)^2;      % concentrator gain (N'Doye Eq. 3)
P.dlambda  = 30;                % nm, optical filter bandwidth (N'Doye Tab. 1)
% receiver (Si PIN, OOK-NRZ), noise parameters: Jamali et al. 2017, Table I
P.qe   = 0.8; P.Te = 290; P.RL = 100; P.Idark = 1.226e-9;
P.Resp = P.qe*1.602176634e-19*P.lambda/(6.62607015e-34*2.99792458e8);  % A/W (0.343)
% link-layer choices (ASSUMED): OOK-NRZ at 10 Mb/s, BER_target 1e-6, noise
% bandwidth = bit rate (conservative)
P.Rb = 10e6; P.BER = 1e-6; P.Bn = P.Rb;
% background light (N'Doye Eqs. 9-10): E_s(532 nm, surface) = 0.7645 W/m^2/nm,
% t = 0.95; attenuated to the ASSUMED operating depth z_op with exp(-a z_op), using
% the CLEAREST water and a*(1-crel) (largest background), so one P_min is
% conservative for all water types.
P.Es = 0.7645; P.tsurf = 0.95; P.z_op = 30;
P = aux_pmin(P);
% ACE predicates: Tx cone = Lambertian half-power cone; Rx FOV = concentrator FOV
P.Theta_T = P.Phi_half;
P.FOV_R   = P.Psi_C;
P.M_robust = 6;                 % dB robust reserve (ASSUMED design reserve)
% margin constant: M = K - 20 log10 d - 4.343 c d + m 10log10 cos e + 10log10 cos psi
P.K_dB = 10*log10(P.eta_t*P.eta_r*P.Pt*(P.m_lamb+1)/(2*pi)*P.Ar*P.gconc/P.Pmin);

% ---------------- vehicle: BlueROV2 Heavy (von Benzon et al. 2022, Table A1) ---
P.veh.m = 13.5; P.veh.I = [0.26 0.23 0.37];
P.veh.Ma = [6.36 7.12 18.68 0.189 0.135 0.222];          % added mass (magnitudes)
P.veh.Dl = [13.7 0 33.0 0 0.8 0];                        % linear damping
P.veh.Dq = [141.0 217.0 190.0 1.19 0.47 1.5];            % quadratic damping
P.veh.rg = [0 0 0]; P.veh.rb = [0 0 -0.01]; P.veh.g = 9.82; P.veh.rho = 1000; P.veh.vol = 0.0134;
P.veh.tauMax = [85 85 120 26 14 22];                     % body-frame maxima (Table 4)
% planar 3-DOF (surge, sway, yaw) used by the actor and by CORA
P.m11 = P.veh.m + P.veh.Ma(1); P.m22 = P.veh.m + P.veh.Ma(2); P.m33 = P.veh.I(3) + P.veh.Ma(6);
P.d11 = P.veh.Dl(1); P.d22 = P.veh.Dl(2); P.d33 = P.veh.Dl(6);
P.q11 = P.veh.Dq(1); P.q22 = P.veh.Dq(2); P.q33 = P.veh.Dq(6);
% CORA model of the quadratic damping q|x|x (the simulators use it exactly):
%  'poly3'   : q X^2 p(x/X), p(t) = a1 t + a3 t^3 least-squares fit of t|t| on [-1,1];
%              the worst-case fit error (x1.05) is a bounded force input
%  'bilinear': q|x| x = delta(t) x, delta in [0, q X] an uncertain coefficient
% Both are exact/sound for the true plant only while |x| <= X, which reach_cell
% asserts at every step (otherwise the cell is Inconclusive with status model-range).
P.dampModel = 'poly3';
if ~isempty(getenv('UWOC_DAMP')), P.dampModel = getenv('UWOC_DAMP'); end   % test override
P.qX = [0.3 0.15 0.3 0.3];    % ranges for u, v (m/s), r (rad/s), heave w (m/s) (ASSUMED envelope)
P.qDq = [P.veh.Dq(1) P.veh.Dq(2) P.veh.Dq(6) P.veh.Dq(3)];
P.qD = P.qX.*P.qDq;            % bilinear: max extra damping coefficients
P.qpoly = aux_qpoly(3);
P.qErr = P.qpoly.err*P.qX.^2.*P.qDq;   % poly3: force error bounds
P.eps_abs = 0;      % (kept for naming of the generated CORA model files)
% actor interface (as Weng et al. JFR 2024): surge-speed and yaw-rate COMMANDS,
% tracked by the vehicle's fast low-level velocity loop (continuous-time model):
%   X = Ku (u_c - u),  Y = -Kv v (sway hold),  N = Kr (r_c - r)   (ASSUMED gains)
P.uc_max = 0.2; P.rc_max = 0.2;            % command limits (m/s, rad/s), Weng JFR 2024
P.Ku = 100; P.Kv = 100; P.Kr = 5;          % N s/m, N s/m, N m s
P.tau_u_max = P.uc_max; P.tau_r_max = P.rc_max;   % (names kept: actor output limits)
% sway command (used only by the sway-capable shield fallback, S1): Y = Kv (v_c - v)
P.vc_max = 0.3;                            % m/s (BlueROV2 Heavy max sway 0.63 m/s, von Benzon Tab. 4)
P.fbs = struct('k_d', 0.10, 'k_e', 0.5, 'k_phi', 0.5);   % ASSUMED fallback gains
P.qXfb = [0.3 0.35 0.3 0.3];               % damping-model envelope for the fallback model
P.b3 = struct('k_phi', 0.5, 'vc_max', 0.3);   % B3 sway-capable teacher: v_c = sat(k_phi phi_hat), |v_c| <= 0.3 m/s (ASSUMED; same law and limit as the S1 fallback)
% heave (3-D rung): depth hold PD (ASSUMED gains), BlueROV2 heave mass/damping
P.heave = struct('m', P.veh.m + P.veh.Ma(3), 'd', P.veh.Dl(3), 'q', P.veh.Dq(3), ...
    'kz', 15, 'kw', 40, 'fmax', P.veh.tauMax(3));
% attitude hold PD for the 6-DOF model (ASSUMED gains; BlueROV2 Heavy has roll/pitch authority)
P.att = struct('kp', [4 4], 'kd', [1 1]);

% ---------------- control / horizon ---------------------------------------
P.dt_ctrl = 0.5;     % s, ZOH control period (ASSUMED; Weng JFR 2024 uses 0.2 s)
P.dt_sim  = 0.05;    % s, RK4 step for simulation
P.T       = 20;      % s, verification horizon

% ---------------- teacher (communication-aware guidance law v2) -------------
P.teacher_version = 2;
P.M_goal  = 9;                       % dB standoff target margin
P.d_ref_min = 1.5;  P.d_ref_max = 10;
P.k_d   = 0.10; P.u_lim = [-0.2 0.2];   % +-0.2 m/s as in Weng JFR 2024 actions
P.k_e = 0.5;                         % yaw-rate command gain r_c = -k_e e_hat

% ---------------- fallback (shield) law: slow down, turn to receiver ------
P.fb_k_e = 0.8;                      % fallback: u_c = 0, r_c = -fb_k_e e_hat

% ---------------- declared uncertainty (scenario choices, ASSUMED) ------------
P.eps_psi = deg2rad(1);   % heading (AHRS) error bound
P.eps_u   = 0.02; P.eps_v = 0.02; P.eps_r = 0.01;   % DVL / gyro error bounds
P.cell.d_half   = 0.25; P.cell.phi_half = deg2rad(3);
P.cell.u0 = [0 0.05]; P.cell.v_half = 0.02; P.cell.r_half = 0.02;

% ---------------- grids ----------------------------------------------------
P.grid.e0   = deg2rad([2 5 10]);
P.grid.loc  = [0.05 0.1 0.2 0.3 0.5 0.75 1.0];
P.grid.cur  = [0 0.025 0.05 0.075 0.1 0.15 0.2];
P.w_train = 0.10; P.loc_train = 0.3;
P.ccv = struct('dEdges', 1:0.5:12, 'phiEdges', -30:10:30, 'zEdges', -1:0.5:1, ...
    'e0', 5, 'w', 0.025, 'wv', 0.02, 'locz', 0.05, 'th0', deg2rad(2), 'alphaR', deg2rad(2), ...
    'nMC', 200, 'locs', [0.05 0.1 0.3 0.5]);
P.ladder.levels = struct('name', {'L1_low','L2_med','L3_high'}, ...
    'zhalf', {0.1, 0.25, 0.5}, 'th0', {deg2rad(1), deg2rad(3), deg2rad(5)}, ...
    'wv', {0.02, 0.05, 0.10}, 'locz', {0.05, 0.1, 0.25}, 'alphaR', {deg2rad(1), deg2rad(3), deg2rad(5)});
end

function Q = aux_qpoly(deg)
t = linspace(-1,1,200001)'; y = t.*abs(t); A = t.^(1:2:deg);
Q.coef = (A\y)'; Q.err = 1.05*max(abs(A*Q.coef' - y)); Q.deg = deg;
end

function P = aux_pmin(P)
% Receiver sensitivity for OOK-NRZ with a PIN detector (standard Gaussian result,
% e.g. Agrawal, Fiber-Optic Communication Systems): P_min = (Q/R)(sigma0 + q Q B),
% Q = Q^-1(BER), sigma0^2 = thermal + background shot + dark shot.
q = 1.602176634e-19; kB = 1.380649e-23;
Qf = sqrt(2)*erfcinv(2*P.BER);
Aeff = P.Ar*P.gconc;
Pb = P.Es*P.tsurf*P.dlambda*Aeff*exp(-P.water.a(1)*(1-P.c_rel_unc)*P.z_op);
sT2 = 4*kB*P.Te*P.Bn/P.RL; sB2 = 2*q*P.Resp*Pb*P.Bn; sD2 = 2*q*P.Idark*P.Bn;
sigma0 = sqrt(sT2 + sB2 + sD2);
P.Pmin = (Qf/P.Resp)*(sigma0 + q*Qf*P.Bn);
P.noise = struct('Q', Qf, 'Pb', Pb, 'sigT2', sT2, 'sigB2', sB2, 'sigD2', sD2, 'sigma0', sigma0);
end
