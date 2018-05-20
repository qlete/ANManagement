using MAT
using JuMP
using CPLEX

"""
    vect_to_ind(vec, m, n)
    
This function converts the vector vec into a single integer betwen 1 and n^m,
where `m` is the length of the vector, `n` is the number of possibilities 
in each entry of the vector and each entry of vec is between 1 and `n`.
"""
function vect_to_ind(vec, m, n)
	@assert (length(vec) == m)
	vec=vec-ones(m)
	return sum(vec[i]*n^(m-i) for i = 1:m)+1
end


"""
    ind_to_vect(ind, m, n)
    
This function converts the integer `ind` into the corresponding vector of length `m`
such that `ind_to_vect(vect_to_ind(vec, m, n), m, n) = vec`.
Here `m` is the length of the vector, `n` is the number of possibilities 
in each entry of the vector and `ind` is an integer between 1 and n^m.
"""
function ind_to_vect(ind, m, n)
	ind = ind-1
	vect = zeros(m)
	for i = 1:m
		to_div = ind - sum(vect[j]*n^(m-j) for j = 1:m)
		vect[i] = div(to_div, n^(m-i))
	end
	return vect+ones(m)
end

"""
    power_flow(p, r, x, I_up, Vmin, Vmax)
    
Computes the values of branch and nodal electrical quantities for given injection `p`
and returns the cost associated to the unfeasibility of the voltages and currents.
"""
function power_flow(power, r, x, I_up, Vmin, Vmax)
	Cunfeas = 8300
	solver = CplexSolver(
    	CPX_PARAM_SCRIND=0,   # Verbose solver output
    )

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

	status = solve(m)
	if status == :Optimal
		v_val = getvalue(v)
		l_val = getvalue(l)
		cost_unfeas = 0
		for j = 2:4
			if l_val[j] > I_up[j-1]
				cost_unfeas = cost_unfeas + Cunfeas*(l_val[j]-I_up[j-1])
			end
		end
		for i = 1:4
			if v_val[i] > Vmax[i]
				cost_unfeas = cost_unfeas + Cunfeas*(v_val[i]-Vmax[i])
			end
			if v_val[i] < Vmin[i]
				cost_unfeas = cost_unfeas + Cunfeas*(Vmin[i]-v_val[i])
			end
		end
	else
		cost_unfeas = 1e9
	end

	return cost_unfeas
end

"""
    cost(a, k, t, data)
    
Computes the cost for a given action, stage and time step.
`a` is an integer from 1:81 representing the action (+10%, +0% or -10% for each node).
`k` is an integer from 1:9 representing the state (demand or solar, +10%, +0% or -10%).
`t` is an integer from 1:169 representing the time step (one week, hourly resolution).
"""
function cost(a, k, t, data)
	Ccurt = 300
	forecast_demand = data["pDemand"][t, :]
	forecast_solar = data["pSolarMax"][t, :]

	# Apply uncertainty given by k to demand and solar production
	uncertainty = ind_to_vect(k, 2, 3)
	uncertainty[find(iszero, uncertainty-1)] = 1.1
	uncertainty[find(iszero, uncertainty-2)] = 1
	uncertainty[find(iszero, uncertainty-3)] = 0.9
	forecast_demand = uncertainty[1]*forecast_demand
	forecast_solar = uncertainty[2]*forecast_solar

    # Apply curtailment action given by k
	curtailment = ind_to_vect(a, 4, 3)
	curtailment[find(iszero, curtailment-1)] = 0
	curtailment[find(iszero, curtailment-2)] = -0.5
	curtailment[find(iszero, curtailment-3)] = -1
	power = forecast_solar + forecast_solar.*curtailment - forecast_demand
	cost_curt = sum(-Ccurt*forecast_solar.*curtailment)

	# Get data
	r = data["r"]
	x = data["x"]
	I_up = data["I_up"]
	Vmin = data["Vmin"]
	Vmax = data["Vmax"]

	cost_unfeas = power_flow(power, r, x, I_up, Vmin, Vmax)
	tot_cost = cost_curt + cost_unfeas
end


"""
    markovdecision(data)
    
Computes the optimal action and the value function using the value iteration algorithm
data is the dictionnary given by the call `matread(\"data_4nodes.mat\")`.
"""
function markovdecision(data)
	pDemand = data["pDemand"]
	nb_steps = size(pDemand)[1]
	print(nb_steps)
	nb_nodes = size(pDemand)[2]
	nb_actions = 3^4
	nb_stages = 9
	P = 1/nb_stages*ones(nb_stages, nb_stages)
	V = zeros(nb_stages, nb_steps)
	opt_actions = zeros(nb_stages, nb_steps)
	for t = nb_steps-1:-1:1
		for k = 1:nb_stages
			all_possibilities = zeros(nb_actions)
			for a = 1:nb_actions
				cost_a = cost(a, k, t, data)
				cost[a,k,t]  = cost_a
				all_possibilities[a] = cost_a + P[k,:]'*V[:,t+1]
			end
			V[k,t] = minimum(all_possibilities)
			opt_actions[k,t] = indmin(all_possibilities)
		end
		println("Iteration t = ", t)
	end
	return (V, opt_actions)
end

# include("savecosts.jl")
# savecost(cost)
# load with cost = loadcost()

data = matread("./data/data_4nodes.mat")
(V, opt_actions) = markovdecision(data)
@show V
@show opt_actions