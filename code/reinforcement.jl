# include("markov.jl")
include("savecosts.jl")

cost = loadcost()

function qvalueiteration(list_k::Vector{Int64}, list_t::Vector{Int64})::Tuple{Vector{Float64},Vector{Int64}}
    nb_states = length(list_k)*length(list_t)
    # Initialize value vector
    qval = zeros(nb_states)
    
    alpha = 0.9
    beta = 1
    while sum(abs.(newV-oldV)) > 1e-9
        qval = copy(newV)
        for i = 1:nb_states
            # restrict only to possible values of qval atteignable from qval[i]
            qval[i] = qval[i] + alpha*(cost(a, k, t, data) + min(qval - qval[i]))
        end
        newV[15] = min(A[15,:]'*oldV, B[15,:]'*oldV, C[15,:]'*oldV)

        # hyperbolic decrease
        alpha = alpha*beta/(alpha + beta)
    end
    return qval
end