using PyPlot

bar([1], [120], width = 0.2)
bar([2], [111.57], width = 0.2)
legend(["Optimization", "Reinforcement learning"])
xlabel("Time [s]")
ylabel("Total curtailment [kW]")
xticks([], [])
show()