function [f, needsPhi] = make_ctrl(net)
% MAKE_CTRL  Controller handle for sim_closed_loop from an actor/fallback struct.
% 7-input nets (sway fallback) also receive the bearing estimate phi_hat.
needsPhi = isfield(net,'nIn') && net.nIn == 7;
if needsPhi
    f = @(z,k,x,ph) deal(nn_forward(net, [z; ph]), false(1,size(z,2)));
else
    f = @(z,k,x) deal(nn_forward(net, z), false(1,size(z,2)));
end
end
