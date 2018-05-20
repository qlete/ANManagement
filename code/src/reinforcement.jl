include("markov.jl")

include("savecosts.jl")

function qvalueiteration(cost_atk)
    nb_time_steps = 10
    nb_stages = 18
    nb_actions = 2*3^3
    qval = zeros(nb_time_steps, nb_stages, nb_actions)
    # need to fill qval with cost values
    opt_action = zeros(nb_time_steps, nb_stages)
    
    alpha = 0.9
    beta = 1
    while alpha > 0.001
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
cost_akt = loadcost()
actions = qvalueiteration(cost_akt)

for t = 1:size(actions)[1]
    print(actions[t,size(actions)[2]])
end
    

