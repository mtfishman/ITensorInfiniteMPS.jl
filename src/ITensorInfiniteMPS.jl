module ITensorInfiniteMPS
# For `only`, which was introduced in Julia v1.4
using Compat
using ITensors, ITensorMPS
# For using ∞ as lengths, ranges, etc.
using Infinities
# For functions like `isdiag`
using LinearAlgebra
# For indexing starting from something other than 0.
using OffsetArrays
using IterTools
# For HDF5 support
using HDF5
# For integration support when computing exact reference results
using QuadGK
# For `groupreduce`, used when splitting up an OpSum
# with the unit cell terms into terms acting on each
# site.
using SplitApplyCombine

using ITensors.NDTensors: eachdiagblock
using KrylovKit: eigsolve, linsolve, exponentiate

import Base: getindex, length, setindex!, +, -, *

import ITensors: AbstractMPS, ⊕

include("ITensors.jl")
include("itensormap.jl")
include("celledvectors.jl")
include("abstractinfinitemps.jl")
include("infinitemps.jl")
include("infinitecanonicalmps.jl")
include("infiniteblockmpo.jl")
include("infinitempo.jl")
include("transfermatrix.jl")
include("models/models.jl")
include("models/fqhe13.jl")
include("models/ising.jl")
include("models/ising_extended.jl")
include("models/heisenberg.jl")
include("models/hubbard.jl")
include("models/xx.jl")
include("orthogonalize.jl")
include("infinitemps_approx.jl")
include("subspace_expansion.jl")
include("vumps_generic.jl")
include("vumps_localham.jl")
include("vumps_nonlocalham.jl")
include("vumps_mpo.jl")

export Cell,
  CelledVector,
  InfiniteMPS,
  InfiniteCanonicalMPS,
  InfMPS,
  InfiniteSum,
  InfiniteMPO,
  InfiniteBlockMPO,
  InfiniteSumLocalOps,
  ITensorMap,
  TransferMatrix,
  @Model_str,
  Model,
  @Observable_str,
  Observable,
  input_inds,
  infinitemps_approx,
  infsiteinds,
  nsites,
  output_inds,
  reference,
  subspace_expansion,
  translatecell,
  translatecelltags,
  translator,
  tdvp,
  vumps,
  finite_mps,
  ⊕,
  ⊗,
  ×
end
