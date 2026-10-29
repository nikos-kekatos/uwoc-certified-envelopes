function d = teacher_dref(P, c)
% TEACHER_DREF  Standoff range of the teacher (same Newton solve as teacher_policy).
d = 3*ones(size(c));
for k = 1:40
    g = margin_db(P, d, 0, 0, c) - P.M_goal; dg = -20./(d*log(10)) - (10/log(10))*c;
    d = max(d - g./dg, 0.3);
end
d = min(max(d, P.d_ref_min), P.d_ref_max);
end
