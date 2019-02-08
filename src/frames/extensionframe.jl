
"""
An ExtensionFrame is the restriction of a basis to a subset of its domain. This
results in a frame that implicitly represents extensions of functions on the
smaller set to the larger set.
"""
struct ExtensionFrame{S,T} <: DerivedDict{S,T}
    domain      ::  Domain
    basis       ::  Dictionary{S,T}

    function ExtensionFrame{S,T}(domain::Domain, basis::Dictionary) where {S,T}
        # @assert isbasis(basis)
        new(domain, basis)
    end
end

ExtensionFrame(domain::Domain, basis::Dictionary{S,T}) where {S,T} =
    ExtensionFrame{S,T}(domain, basis)

# superdict is the function for DerivedDict's to obtain the underlying set
superdict(f::ExtensionFrame) = f.basis

basis(f::ExtensionFrame) = f.basis
support(f::ExtensionFrame) = f.domain

similar_dictionary(f::ExtensionFrame, dict::Dictionary) = ExtensionFrame(support(f), dict)

isbasis(f::ExtensionFrame) = false
isframe(f::ExtensionFrame) = true
isbiorthogonal(f::ExtensionFrame, measure::Measure) = false
isorthogonal(f::ExtensionFrame, measure::Measure) = false
isorthonormal(f::ExtensionFrame, measure::Measure) = false

# The following properties do not hold for extension frames
# - there is no interpolation grid
hasinterpolationgrid(f::ExtensionFrame) = false
# - there is no unitary transform
hastransform(f::ExtensionFrame) = false
hastransform(f::ExtensionFrame, dgs) = false
# - there is no antiderivative (in general)
hasantiderivative(f::ExtensionFrame) = false

name(f::ExtensionFrame) = "Extension frame"


dict_in_support(f::ExtensionFrame, x) = x ∈ support(f)
dict_in_support(f::ExtensionFrame, idx, x) = x ∈ support(f) && in_support(basis(f), idx, x)

iscompatible(d1::ExtensionFrame, d2::ExtensionFrame) = iscompatible(basis(d1),basis(d2))

function (*)(d1::ExtensionFrame, d2::ExtensionFrame, args...)
    @assert iscompatible(d1,d2)
    (mset, mcoef) = (*)(basis(d1),basis(d2),args...)
    df = ExtensionFrame(support(d1) ∩ support(d2),mset)
    (df, mcoef)
end

unsafe_eval_element(s::ExtensionFrame, idx::Int, x) =
    unsafe_eval_element(basis(s), idx, x)

function interpolation_grid(f::ExtensionFrame)
    @warn "interpolation_grid called on extensionframe $f"
    subgrid(interpolation_grid(basis(f)),support(f))
end

"""
Make an ExtensionFrame, but match tensor product domains with tensor product sets
in a suitable way.

For example: an interval ⊗ a disk (= a cylinder) combined with a 3D Fourier series, leads to a
tensor product of a Fourier series on the interval ⊗ a 2D Fourier series on the disk.
"""
function extensionframe(domain::ProductDomain, basis::TensorProductDict)
    ExtensionFrames = Dictionary[]
    dc = 1
    for i = 1:numelements(domain)
        el = element(domain, i)
        range = dc:dc+dimension(el)-1
        push!(ExtensionFrames, ExtensionFrame(el, element(basis, range)))
        dc += dimension(el)
    end
    tensorproduct(ExtensionFrames...)
end

extensionframe(domain::Domain, basis::Dictionary) = ExtensionFrame(domain, basis)
extensionframe(basis::Dictionary, domain::Domain) = extensionframe(domain, basis)

leftendpoint(d::ExtensionFrame, args...) = leftendpoint(support(d))
rightendpoint(d::ExtensionFrame, args...) = rightendpoint(support(d))


import BasisFunctions: measure, restrict
import BasisFunctions: innerproduct, innerproduct_native

hasmeasure(::ExtensionFrame) = true
measure(f::ExtensionFrame) = SubMeasure(measure(basis(f)), support(f))

innerproduct_native(f1::ExtensionFrame, i, f2::ExtensionFrame, j, measure::SubMeasure; options...) =
    innerproduct(superdict(f1), i, superdict(f2), j, measure; options...)

# # Just to insert the :extensionframe_spantype as default for ExtensionFrame
# @inline dualdictionary(dict::ExtensionFrame, measure::Measure=measure(dict), space::BasisFunctions.FunctionSpace=Span(dict);
#             dualtype=:extensionframe_spantype) =
#     BasisFunctions._dualdictionary(dict, measure, space; dualtype=dualtype)

function BasisFunctions._dualdictionary(dict::DICT, measure::Measure, space::Span, spandict::DICT;
            warnslow = BasisFunctions.BF_WARNSLOW, dualtype=:extensionframe_spantype) where DICT <: ExtensionFrame
    if dualtype == :spantype
        warnslow && @warn "Are you sure you want `dualtype=:spantype` and not `:extensionframe_spantype`"
        BasisFunctions.spantype_dualdictionary(dict, measure, space, spandict)
    elseif dualtype == :extensionframe_spantype
        extensionframe_spantype_dualdictionary(dict, measure, space, spandict)
    else
        @warn "Only `:spantype` and `:extensionframe_spantype` implemented/known."
    end
end

"Create a dual dictionary based on the superdict of the ExtensionFrame"
function extensionframe_spantype_dualdictionary(dict::DICT, measure::Measure, space::Span, spandict::DICT) where DICT <: Dictionary
    @assert size(dict) == size(spandict)
    conj(inv( wrap_operator(dict, dict, gramoperator(superdict(dict), supermeasure(measure))))) * dict
end

## Printing

string(f::ExtensionFrame) = name(f) * " of " * name(f.basis)

modifiersymbol(dict::ExtensionFrame) = PrettyPrintSymbol{:𝔼}(dict)

string(s::PrettyPrintSymbol{:𝔼}) = _string(s, s.object)
_string(s::PrettyPrintSymbol{:𝔼}, dict::ExtensionFrame) =
    "Extension frame, from $(support(dict)) to $(support(superdict(dict)))"



##################
# platform
##################

SolverStyle(dict::ExtensionFrame, ::OversamplingStyle) = AZStyle()

GridSampling(dgs::GridBasis, grid::AbstractGrid, domain::Domain, scaling) =
    GridSampling(GridBasis{coefficienttype(dgs)}(subgrid(grid, domain)), scaling=scaling)
