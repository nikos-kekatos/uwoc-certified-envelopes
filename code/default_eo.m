function eo = default_eo()
% DEFAULT_EO  Settings for eval_cell (reach, MC, falsifier).
eo.nMC = 500; eo.seed = 1; eo.maxDepth = 2; eo.checkCertified = true; eo.estFals = true;
eo.ro = struct('timeStep',0.05,'taylorTerms',8,'zonotopeOrder',100,'polyMethod','singh','tmax',900,'trace',false);
eo.fo = struct('pop',120,'iters',12,'elite',12,'tol',0.01);
eo.tol = 0.01;
end
