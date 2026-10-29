function net = teacher_net(P, wi)
% TEACHER_NET  The classical communication-aware LOS/PAT law (teacher_policy) written
% exactly as a piecewise-linear network for water type wi (c_hat fixed):
%   u_c = sat(k_d (d_hat - d_ref(c))),  r_c = sat(-k_e e_hat)
% so that CORA can verify the classical baseline with the same machinery.
c = P.water.c(wi); dref = teacher_dref(P, c);
W = zeros(2,6); W(1,1) = P.k_d; W(2,2) = -P.k_e;
net.W = {W}; net.b = {[-P.k_d*dref; 0]}; net.sat = [P.uc_max; P.rc_max];
net.name = sprintf('teacher_%s', P.water.name{wi});
end
