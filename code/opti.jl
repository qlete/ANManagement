function opti()
	solver = CplexSolver()

	m = Model(solver=solver)

	@variable(m, v[1:5]>=0)
	JuMP.fix(v[1], 0.0529)
	@variable(m, l[2:5]>=0)
	@variable(m, P[1:5])
	@variable(m, Q[1:5])
	@variable(m, q[1:5])
	@variable(m, p[1:5])
	for i = 1:5
		setlowerbound(q[i], -0.01)
		setupperbound(q[i], 0.01)
	end
	for i = 2:5
		JuMP.fix(p[i], power[i-1])
	end

	@constraint(m, P[1] == 0)
	@constraint(m, Q[1] == 0)
	@constraint(m, [i=1:5], P[i] == p[i] + sum(P[j]-r[j-1]*l[j] for j = i+1:5))
	@constraint(m, [i=1:5], Q[i] == q[i] + sum(Q[j]-x[j-1]*l[j] for j = i+1:5))
	@constraint(m, [i=2:5], v[i-1] == v[i] -2*(r[i-1]*P[i]+x[i-1]*Q[i])+(x[i-1]^2+r[i-1]^2)*l[i])
	@constraint(m, [i=2:5], v[i]*l[i] >= P[i]^2 + Q[i]^2)

	@objective(m, Min, 0)

end