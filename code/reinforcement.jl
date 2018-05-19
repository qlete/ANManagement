# include("markov.jl")

# include("savecosts.jl")
# 
# cost = loadcost()

function cost(a,k,t)
    return rand(1)[1]
end

function qvalueiteration()
    nb_steps = 10
    nb_actions = 3^4
    nb_stages = 9
    qval = zeros(nb_steps, nb_stages, nb_actions)
    # need to fill qval with cost values
    
    t = 1
    alpha = 0.9
    beta = 1
    while t < 10
        for k = 1:nb_stages
            for a = 1:nb_actions
                min_q = minimum(qval[t,:,:])
                qval[t,k,a] = qval[t,k,a] + alpha*(cost(a,k,t) + min_q - qval[t,k,a])
            end
        end
        # hyperbolic decrease
        alpha = alpha*beta/(alpha + beta)
        t = t + 1
    end
    return qval
end

print(qvalueiteration())