using ITensorInfiniteMPS
using ITensorInfiniteMPS.ITensors

N = 2

model = Model"ising"()
model_kwargs = (J=1.0, h=1.0)

function space_shifted(::Model"ising", q̃sz)
  return [QN("SzParity", 1 - q̃sz, 2) => 1, QN("SzParity", 0 - q̃sz, 2) => 1]
end

space_ = fill(space_shifted(model, 0), N)
s = infsiteinds("S=1/2", N; space=space_)
initstate(n) = "↑"
ψ = InfMPS(s, initstate)

# Form the Hamiltonian
H = InfiniteITensorSum(model, s; model_kwargs...)

# Check translational invariance
@show norm(contract(ψ.AL[1:N]..., ψ.C[N]) - contract(ψ.C[0], ψ.AR[1:N]...))

cutoff = 1e-8
maxdim = 100
environment_iterations = 30
niter = 30
vumps_kwargs = (environment_iterations=environment_iterations, niter=niter)

# Alternate steps of running VUMPS and increasing the bond dimension
ψ = vumps(H, ψ; vumps_kwargs...)
ψ = subspace_expansion(ψ, H; cutoff=cutoff, maxdim=maxdim)
ψ = vumps(H, ψ; vumps_kwargs...)
ψ = subspace_expansion(ψ, H; cutoff=cutoff, maxdim=maxdim)
ψ = vumps(H, ψ; vumps_kwargs...)
ψ = subspace_expansion(ψ, H; cutoff=cutoff, maxdim=maxdim)
ψ = vumps(H, ψ; vumps_kwargs...)
ψ = subspace_expansion(ψ, H; cutoff=cutoff, maxdim=maxdim)
ψ = vumps(H, ψ; vumps_kwargs...)

# Check translational invariance
@show norm(contract(ψ.AL[1:N]..., ψ.C[N]) - contract(ψ.C[0], ψ.AR[1:N]...))

#
# Compare to DMRG
#

Nfinite = 40
sfinite = siteinds("S=1/2", Nfinite; conserve_szparity=true)
Hfinite = MPO(model, sfinite; model_kwargs...)
ψfinite = randomMPS(sfinite, initstate)
@show flux(ψfinite)
sweeps = Sweeps(10)
setmaxdim!(sweeps, 10)
setcutoff!(sweeps, 1E-10)
energy_finite_total, ψfinite = dmrg(Hfinite, ψfinite, sweeps)
@show energy_finite_total / Nfinite

function energy(ψ1, ψ2, h)
  ϕ = ψ1 * ψ2
  return (noprime(ϕ * h) * dag(ϕ))[]
end

function ITensors.expect(ψ, o)
  return (noprime(ψ * op(o, filterinds(ψ, "Site")...)) * dag(ψ))[]
end

nfinite = Nfinite ÷ 2
orthogonalize!(ψfinite, nfinite)
hnfinite = ITensor(model, sfinite[nfinite], sfinite[nfinite + 1]; model_kwargs...)
energy_finite = energy(ψfinite[nfinite], ψfinite[nfinite + 1], hnfinite)
energy_infinite = energy(ψ.AL[1], ψ.AL[2] * ψ.C[2], H[(1, 2)])
@show energy_finite, energy_infinite
@show abs(energy_finite - energy_infinite)

Sz1_finite = expect(ψfinite[nfinite], "Sz")
orthogonalize!(ψfinite, nfinite + 1)
Sz2_finite = expect(ψfinite[nfinite + 1], "Sz")
Sz1_infinite = expect(ψ.AL[1] * ψ.C[1], "Sz")
Sz2_infinite = expect(ψ.AL[2] * ψ.C[2], "Sz")

@show Sz1_finite, Sz2_finite
@show Sz1_infinite, Sz2_infinite

###################################################################
# Test using linsolve to compute environment

function test_left_environment(∑h::InfiniteITensorSum, ψ::InfiniteCanonicalMPS; niter)
  Nsites = nsites(ψ)
  ψᴴ = dag(ψ)
  ψ′ = ψᴴ'
  # XXX: make this prime the center sites
  ψ̃ = prime(linkinds, ψᴴ)

  l = CelledVector([commoninds(ψ.AL[n], ψ.AL[n + 1]) for n in 1:Nsites])
  l′ = CelledVector([commoninds(ψ′.AL[n], ψ′.AL[n + 1]) for n in 1:Nsites])
  r = CelledVector([commoninds(ψ.AR[n], ψ.AR[n + 1]) for n in 1:Nsites])
  r′ = CelledVector([commoninds(ψ′.AR[n], ψ′.AR[n + 1]) for n in 1:Nsites])

  hᴸ = InfiniteMPS([
    δ(only(l[n - 2]), only(l′[n - 2])) *
    ψ.AL[n - 1] *
    ψ.AL[n] *
    ∑h[(n - 1, n)] *
    ψ′.AL[n - 1] *
    ψ′.AL[n] for n in 1:Nsites
  ])

  hᴿ = InfiniteMPS([
    δ(only(dag(r[n + 2])), only(dag(r′[n + 2]))) *
    ψ.AR[n + 2] *
    ψ.AR[n + 1] *
    ∑h[(n + 1, n + 2)] *
    ψ′.AR[n + 2] *
    ψ′.AR[n + 1] for n in 1:Nsites
  ])

  eᴸ = [
    (hᴸ[n] * ψ.C[n] * δ(only(dag(r[n])), only(dag(r′[n]))) * ψ′.C[n])[] for n in 1:Nsites
  ]
  eᴿ = [(hᴿ[n] * ψ.C[n] * δ(only(l[n]), only(l′[n])) * ψ′.C[n])[] for n in 1:Nsites]

  for n in 1:Nsites
    # TODO: use these instead, for now can't subtract
    # BlockSparse and DiagBlockSparse tensors
    #hᴸ[n] -= eᴸ[n] * δ(inds(hᴸ[n]))
    #hᴿ[n] -= eᴿ[n] * δ(inds(hᴿ[n]))
    hᴸ[n] -= eᴸ[n] * denseblocks(δ(inds(hᴸ[n])))
    hᴿ[n] -= eᴿ[n] * denseblocks(δ(inds(hᴿ[n])))
  end

  ## # Compute endcaps as the sum of terms in the unit cell
  ## hᴸᴺ¹ = hᴸ[Nsites]
  ## hᴸᴺ¹ = translatecell(hᴸᴺ¹, -1)
  ## for n in 1:Nsites
  ##   hᴸᴺ¹ = hᴸᴺ¹ * ψ.AL[n] * ψ̃.AL[n]
  ## end
  ## # Loop over the Hamiltonian terms in the unit cell
  ## for n in 1:Nsites
  ##   hᴸⁿ = hᴸ[n]
  ##   for k in (n + 1):Nsites
  ##     hᴸⁿ = hᴸⁿ * ψ.AL[k] * ψ̃.AL[k]
  ##   end
  ##   hᴸᴺ¹ += hᴸⁿ
  ## end
  ## hᴸ[Nsites] = hᴸᴺ¹

  @show hᴸ[1]
  @show hᴸ[2]

  Hᴸ_rec = ITensorInfiniteMPS.left_environment_recursive(hᴸ, ψ; niter=niter)

  hᴸ[2] = hᴸ[1] * ψ.AL[2] * ψ̃.AL[2] + hᴸ[2]
  Hᴸ = ITensorInfiniteMPS.left_environment(hᴸ, ψ)

  @show norm(ITensorInfiniteMPS.Bᴸ(hᴸ, ψ, Nsites)(Hᴸ[Nsites]) - hᴸ[Nsites])
  @show norm(ITensorInfiniteMPS.Bᴸ(hᴸ, ψ, Nsites)(Hᴸ_rec[Nsites]) - hᴸ[Nsites])

  @show tr(Hᴸ[Nsites] * ψ.C[Nsites] * ψ′.C[Nsites])
  @show tr(Hᴸ_rec[Nsites] * ψ.C[Nsites] * ψ′.C[Nsites])

  @show Hᴸ[Nsites]
  @show Hᴸ_rec[Nsites]
  @show (Hᴸ[Nsites] - Hᴸ_rec[Nsites]) 

  return Hᴸ, Hᴸ_rec
end

#Hᴸ, Hᴸ_rec = test_left_environment(H, ψ; niter=40)

nothing


