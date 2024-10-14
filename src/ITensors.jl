using ITensorMPS: MPS
using ITensors.NDTensors: NDTensors, tensor
using ITensors: ITensors, QN, Tag, TagSet, dag, inds, isdiag, sim
using LinearAlgebra: LinearAlgebra, eigen

############################################################################
# NDTensors
#

# Take the square root of a diagonal order 2 tensor
# TODO: make a AbstractDiagTensor supertype?
# TODO: make this work for non-diagonal tensors.
# TODO: define SecondOrderTensor?
function Base.sqrt(T::NDTensors.Tensor{<:Number,2}; atol=1e-15)
  @assert isdiag(T)
  sqrtT = copy(T)
  for n in 1:mindim(T)
    Tnn = T[n, n]
    if Tnn < 0 && abs(Tnn) < atol
      sqrtT[n, n] = 0
    else
      sqrtT[n, n] = sqrt(Tnn)
    end
  end
  return sqrtT
end

############################################################################
# tagset.jl
#

# Used for findfirst
Base.keys(ts::TagSet) = Base.OneTo(length(ts)) # added

import ITensors: Tag, commontags

maxlength(tag::Tag) = length(tag.data) # added

function Base.length(tag::Tag) # added
  n = 1
  while n <= maxlength(tag) && tag[n] != zero(eltype(tag))
    n += 1
  end
  return n - 1
end

Base.lastindex(tag::Tag) = length(tag) # added

Base.getindex(tag::Tag, r::UnitRange) = Tag([tag[n] for n in r]) #added

# TODO: make this work directly on a Tag, without converting
# to String
function Base.parse(::Type{T}, tag::Tag) where {T<:Integer} #added
  return parse(T, string(tag))
end

function Base.startswith(tag::Tag, subtag::Tag) #added
  for n in 1:length(subtag)
    tag[n] ≠ subtag[n] && return false
  end
  return true
end

function tag_starting_with(ts::TagSet, prefix)
  x = findfirst(t -> startswith(t, Tag(prefix)), ts)
  if isnothing(x) #in case the function is called one a link leg. Can be probably improved
    return x
  end
  return ts[findfirst(t -> startswith(t, Tag(prefix)), ts)]
end

ITensors.replacetags(ts::TagSet, p::Pair) = replacetags(ts, first(p), last(p))

############################################################################
# qn.jl
#

#
# New QN interface.
# Allows constructors like:
# Index((("Sz", 0) × ("SzParity", 0, 2) => 1) ⊕
#       (("Sz", 1) × ("SzParity", 1, 2) => 2))
#

function LinearAlgebra.cross(
  qn1::Tuple{String,Int,Vararg{Int}}, qn2::Tuple{String,Int,Vararg{Int}}
)
  return QN(qn1, qn2)
end
function LinearAlgebra.cross(qn1::QN, qn2::Tuple{String,Int,Vararg{Int}})
  return ITensors.addqnval(qn1, ITensors.QNVal(qn2...))
end

⊕(qn1::Pair{QN,Int}, qn2::Pair{QN,Int}) = [qn1, qn2]
function ⊕(qn1::Pair{QN,Int64}, qn2::Pair{<:Tuple{String,Int,Vararg{Int}},Int})
  return [qn1, QN(first(qn2)) => last(qn2)]
end
function ⊕(qn1::Pair{<:Tuple{String,Int,Vararg{Int}},Int}, qn2::Pair{QN,Int})
  return [QN(first(qn1)) => last(qn1), qn2]
end
function ⊕(
  qn1::Pair{<:Tuple{String,Int,Vararg{Int}},Int},
  qn2::Pair{<:Tuple{String,Int,Vararg{Int}},Int},
)
  return [QN(first(qn1)) => last(qn1), QN(first(qn2)) => last(qn2)]
end
⊕(qns::Vector{Pair{QN,Int}}, qn::Pair{QN,Int}) = push!(copy(qns), qn)

############################################################################
# itensor.jl
#

# TODO: implement something like this?
#function sqrt(::Order{2}, T::ITensor)
#end

# Take the square root of T assuming it is Hermitian
# TODO: add more general index structures
function Base.sqrt(T::ITensor; ishermitian=true, atol=1e-15)
  @assert ishermitian
  if isdiag(T) && order(T) == 2
    return itensor(sqrt(tensor(T)))
  end
  #U′, D, Uᴴ = eigendecomp(T; ishermitian=ishermitian)
  D, U = eigen(T; ishermitian=ishermitian)
  # XXX: if T is order 2 and diagonal, D may just be a view
  # of T so this would also modify T
  #D .= sqrt.(D)
  sqrtD = D
  for n in 1:mindim(D)
    Dnn = D[n, n]
    if Dnn < 0 && abs(Dnn) < atol
      sqrtD[n, n] = 0
    else
      sqrtD[n, n] = sqrt(Dnn)
    end
  end
  return U' * sqrtD * dag(U)
end

############################################################################
# mps.jl
#

# TODO: make this definition AbstractMPS
# Handle orthogonality center correctly
Base.getindex(ψ::MPS, r::UnitRange{Int}) = MPS([ψ[n] for n in r]) # added
