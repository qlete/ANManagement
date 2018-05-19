using Documenter, ActiveNetworkManagement

makedocs(
    format = :html,
    sitename = "ActiveNetworkManagement.jl",
    pages = [
    "Summary" => "index.md",
    "Main" => "markov.md",
    "MDF and RL" => "rl.md"]
)