function c = make_cell(P, wi, d0, e0, loc, w, varargin)
% MAKE_CELL  Operating cell (declared bounds) for reach/MC/falsification.
c.lo = [d0 - P.cell.d_half; -P.cell.phi_half; -e0; P.cell.u0(1); -P.cell.v_half; -P.cell.r_half];
c.hi = [d0 + P.cell.d_half;  P.cell.phi_half;  e0; P.cell.u0(2);  P.cell.v_half;  P.cell.r_half];
c.c = P.water.c(wi); c.wi = wi; c.crel = P.c_rel_unc;
c.loc = loc; c.w = w; c.epsPsi = P.eps_psi; c.epsVel = [P.eps_u; P.eps_v; P.eps_r];
c.T = P.T; c.Te = 10; c.d0 = d0; c.e0 = e0;
for i = 1:2:numel(varargin), c.(varargin{i}) = varargin{i+1}; end
end
