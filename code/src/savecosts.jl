using JLD
    
function costdatafilename()
    return "./data/cost_data.jld"
end

function savecost(cost)
    save(costdatafilename(), "cost", cost)
end

function loadcost()
    raw = load(costdatafilename())
    return raw["cost"]
end
