using PyPlot

bar([1], [3.94], width = 0.2)
bar([2], [54.95], width = 0.2)
legend(["Optimization", "Reinforcement learning"])
xlabel("Time [s]")
xticks([], [])
show()