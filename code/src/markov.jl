export vect_to_ind, ind_to_vect, power_flow, cost, markovdecision

using MAT
using JuMP
using CPLEX
# include("savecosts.jl")

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
`a` is an integer from 1:54 representing the action (+10%, +0% or -10% for each household
 and the activation level for the flexible load).
`k` is an integer from 1:9 representing the state (demand or solar, +10%, +0% or -10%).
`t` is an integer from 1:169 representing the time step (one week, hourly resolution).
"""
function cost(a, k, t, data)
	Ccurt = 300
	Cflex = 1
	forecast_demand = data["pDemand"][t, :]
	forecast_solar = data["pSolarMax"][t, :]

	# Apply uncertainty given by k to demand and solar production
	state = ind_to_vect(k, 3, 3)
	uncertainty = state[2:3]
	uncertainty[find(iszero, uncertainty-1)] = 1.1
	uncertainty[find(iszero, uncertainty-2)] = 1
	uncertainty[find(iszero, uncertainty-3)] = 0.9
	forecast_demand = uncertainty[1]*forecast_demand
	forecast_solar = uncertainty[2]*forecast_solar

    # Apply curtailment action given by k
	actions = ind_to_vect(a, 4, 3)
	curtailment = actions[2:4]
	curtailment[find(iszero, curtailment-1)] = 0
	curtailment[find(iszero, curtailment-2)] = -0.5
	curtailment[find(iszero, curtailment-3)] = -1
	power = zeros(4)
	power[1:3] = forecast_solar[1:3] + forecast_solar[1:3].*curtailment - forecast_demand[1:3]
	power[4] = actions[1] == 1 ? 0 : forecast_demand[4]
	cost_flex = actions[1] == 1 ? 0 : Cflex
	cost_curt = sum(-Ccurt*forecast_solar[1:3].*curtailment)

	# Get data
	r = data["r"]
	x = data["x"]
	I_up = data["I_up"]
	Vmin = data["Vmin"]
	Vmax = data["Vmax"]

	cost_unfeas = power_flow(power, r, x, I_up, Vmin, Vmax)
	tot_cost = cost_curt + cost_unfeas + cost_flex
end


"""
    markovdecision(data)
    
Computes the optimal action and the value function using the value iteration algorithm
data is the dictionnary given by the call `matread(\"data_4nodes.mat\")`.
"""
function markovdecision(data)
	pDemand = data["pDemand"]
	nb_steps = size(pDemand)[1]
	nb_nodes = size(pDemand)[2]
	nb_stages = 18
	cost_akt = zeros(2*3^3, nb_stages, nb_steps)
	big_P = zeros(18,18)
	P = zeros(9,9)
	for i = 1:9
		for j = 1:9
			val = 1
			vec1 = ind_to_vect(i, 3, 3)[2:3]
			vec2 = ind_to_vect(j, 3, 3)[2:3]
			for k in abs.(vec1-vec2)
				val = val*(k == 0 ? 0.5 : 0.25)
			end
			P[i,j] = val
		end
	end
	V = zeros(nb_stages, nb_steps)
	opt_actions = zeros(nb_stages, nb_steps)
	for t = nb_steps-1:-1:1
		for k = 1:nb_stages
			state = ind_to_vect(k,3,3)[1]
			nb_actions = state[1] == 1 ? 2*3^3 : 3^3
			all_possibilities = zeros(nb_actions)
			for a = 1:nb_actions
				actions = ind_to_vect(a,4,3)
				if actions[1] == 1
					big_P = [P zeros(9,9);zeros(9,9) P]
				elseif actions[1] == 2
					big_P = [zeros(9,9) P;zeros(9,9) zeros(9,9)]
				end
				cost_a = cost(a, k, t, data)
				cost_akt[a,k,t] = cost_a
				all_possibilities[a] = cost_a + big_P[k,:]'*V[:,t+1]
			end
			V[k,t] = minimum(all_possibilities)
			opt_actions[k,t] = indmin(all_possibilities)
		end
		println("Iteration t = ", t)
	end
	savecost(cost_akt)
	return (V, opt_actions)
end

function run()
    data = matread("./data/data_4nodes.mat")
    (V, opt_actions) = markovdecision(data)
    @show V
    @show opt_actions
end