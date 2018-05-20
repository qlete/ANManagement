using Documenter, ActiveNetworkManagement

makedocs(
    format = :html,
    sitename = "ActiveNetworkManagement.jl",
    pages = [
    "Summary" => "index.md",
    "MDP and model" => "markov.md",
    "Reinforcement learning" => "rl.md",
    "Multi-time-steps optimization" => "opti.md",
    ]
)