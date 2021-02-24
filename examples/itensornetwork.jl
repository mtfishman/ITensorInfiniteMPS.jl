using AbstractTrees
using ITensors
using ITensorsVisualization
using ITensorsInfiniteMPS
using IterTools # For subsets
using ProfileView
using Random # For seed!
using StatsBase # For sample

Random.seed!(1234)

Sz0 = ("Sz", 0) => 1
Sz1 = ("Sz", 1) => 1
#space = Sz0 ⊕ Sz1
space = 2

# Make a random network
N = 9 # Tensors in the network
max_nedges = max(1, N * (N-1) ÷ 2)
# Fill 2/3 of the edges
nedges = max(1, max_nedges * 2 ÷ 3)
# 1/3 of tensors have physical indices
nsites = N ÷ 3
edges = StatsBase.sample(collect(subsets(1:N, 2)), nedges; replace = false)
sites = StatsBase.sample(collect(1:N), nsites; replace = false)

indsnetwork = ITensorsInfiniteMPS.IndexSetNetwork(N)
for e in edges
  le = IndexSet(Index(space, "l=$(e[1])↔$(e[2])"))
  pair_e = Pair(e...)
  indsnetwork[pair_e] = le
  indsnetwork[reverse(pair_e)] = dag(le)
end

for n in sites
  indsnetwork[n => n] = IndexSet(Index(space, "s=$(n)"))
end

T = Vector{ITensor}(undef, N)
for n in 1:N
  T[n] = randomITensor(only.(ITensorsInfiniteMPS.eachlinkinds(indsnetwork, n))...)
end

# Can just use indsnetwork, this recreates indsnetwork
TN = ⊗(T...)

@show N
sequence, cost = @time ITensorsInfiniteMPS.optimal_contraction_sequence(TN)
@show cost
@show Tree(sequence)
#@profview ITensorsInfiniteMPS.optimal_contraction_sequence(TN)

# Benchmark results
# N  cost
# 2  0.000034
# 3  0.000054
# 4  0.000104
# 5  0.000870
# 6  0.017992
# 7  0.475907
# 8  20.809482
# 9

