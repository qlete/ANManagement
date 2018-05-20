using MAT
using JuMP
using CPLEX

function opti()
	data = matread("./data/data_4nodes.mat")

	# Get data
	r = data["r"]
	x = data["x"]
	I_up = data["I_up"]
	Vmin = data["Vmin"]
	Vmax = data["Vmax"]
	pDemand = data["pDemand"]
	pSolar = data["pSolarMax"]
	Ccurt = 300
	Cunfeas = 8300

	solver = CplexSolver()
	m = Model(solver=solver)

	@variable(m, v[1:5,1:169]>=0)
	# for i = 1:169
	# 	JuMP.fix(v[1,i], 0.0529)
	# end
	@variable(m, l[2:5,1:169]>=0)
	@variable(m, P[1:5,1:169])
	@variable(m, Q[1:5,1:169])
	@variable(m, q[1:5,1:169])
	@variable(m, p[1:5,1:169])
	@variable(m, p_prod[2:5,1:169]>=0)
	for i = 1:5
		for j = 1:169
			setlowerbound(q[i,j], -0.01)
			setupperbound(q[i,j], 0.01)
		end
	end

	@constraint(m, [t=1:169], P[1,t] == 0)
	@constraint(m, [t=1:169], Q[1,t] == 0)
	@constraint(m, [i=1:5,t=1:169], P[i,t] == p[i,t] + sum(P[j,t]-r[j-1]*l[j,t] for j = i+1:5))
	@constraint(m, [i=1:5,t=1:169], Q[i,t] == q[i,t] + sum(Q[j,t]-x[j-1]*l[j,t] for j = i+1:5))
	@constraint(m, [i=2:5,t=1:169], v[i-1,t] == v[i,t] -2*(r[i-1]*P[i,t]+x[i-1]*Q[i,t])+(x[i-1]^2+r[i-1]^2)*l[i,t])
	@constraint(m, [i=2:5,t=1:169], v[i,t]*l[i,t] >= P[i,t]^2 + Q[i,t]^2)
	@constraint(m, [i=2:5,t=1:169], p_prod[i,t] <= pSolar[t,i-1])
	@constraint(m, [i=2:5,t=1:169], p[i,t] == p_prod[i,t] - pDemand[t,i-1])
	@constraint(m, [i=1:5,t=1:169], v[i,t] <= Vmax[i])
	@constraint(m, [i=1:5,t=1:169], v[i,t] >= Vmin[i])
	@constraint(m, [i=2:5,t=1:169], l[i,t] <= I_up[i-1])

	@objective(m, Min, Ccurt*sum(pSolar[t,i-1]-p_prod[i,t] for i=2:5,t=1:169))

	status = solve(m)
end

opti()