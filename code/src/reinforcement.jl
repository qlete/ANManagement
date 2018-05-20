include("markov.jl")

include("savecosts.jl")

using Plots, PyPlot

function qvalueiteration(cost_akt)
    nb_time_steps = 169
    nb_stages = 18
    nb_actions = 2*3^3
    qval = zeros(nb_time_steps, nb_stages, nb_actions)
    # need to fill qval with cost values
    opt_action = zeros(nb_time_steps, nb_stages)
    
    alpha = 0.9
    beta = 1
    while alpha > 0.01
        print(alpha, "\n")
        for t = 2:nb_time_steps
		    for k = 1:nb_stages
		    	state = ind_to_vect(k,3,3)[1]
		    	nb_actions = state[1] == 1 ? 2*3^3 : 3^3
                min_q = 0
		    	for a = 1:nb_actions
		    		actions = ind_to_vect(a,4,3)
		    		if actions[1] == 1
                        min_q = minimum(qval[t-1,:,:])
                    end
		    		if actions[1] == 2
                        min_q = minimum(qval[t-1,10:18,28:54])
                    end
                    qval[t,k,a] = qval[t,k,a] + alpha*(cost_akt[a,k,t] + min_q - qval[t,k,a])
                    opt_action[t,k] = indmin(qval[t,k,:])
               end
           end     
        end
        # hyperbolic decrease
        alpha = alpha*beta/(alpha + beta)
    end
    return opt_action
end

function run_and_save_bestactions()
    cost_akt = loadcost()
    opt_actions = qvalueiteration(cost_akt)
    save("./data/opt_actions.jld", "opt_actions", opt_actions)
end

# run_and_save_bestactions()

raw = load("./data/opt_actions.jld")
opt_actions = raw["opt_actions"]

nb_time_steps = size(opt_actions)[1]
nb_stages = size(opt_actions)[2]

state_min = 1
power_cut = zeros(nb_time_steps)

for t = 2:nb_time_steps
    iter_state = rand(state_min:18)
    # once we set the load OFF, we have to keep it OFF till the end
    # if (iter_state[1] > 9)
    #     state_min = 10
    # end
    iter_action = ind_to_vect(opt_actions[t,iter_state], 4, 3)
    action_h3 = iter_action[4]
    # print("House 3 : ", action_h3, "\n")
    if action_h3 == 1
        power_cut[t] = 0
    elseif action_h3 == 2
        power_cut[t] = 0.5
    else 
        power_cut[t] = 1
    end
end

data = matread("./data/data_4nodes.mat")
p_pred = data["pSolarMax"][:, 3]

p_pred = p_pred*1000

p_grid = power_cut.*p_pred

fig = plot()

times = [i for i=1:nb_time_steps]
# plot!(times, p_grid,
#    label=["Power cut"],
#    xlabel=("Time step"),
#    ylabel=("Power in kW"))
# plot!(times, p_grid, marker="o", label=["Power forecast"])

# histogram(p_grid, nbins = 20)

bar(times, p_grid, xticks([],[]), xlabel("Time step"), ylabel("Power in kW"))
show()

# show()
savefig(fig, "../fig.pdf")