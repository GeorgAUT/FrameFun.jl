module Platforms

using BasisFunctions: Dictionary, TensorProductDict, Dictionary1d, tensorproduct,
    extensionsize, gramdual, Measure, ProductMeasure, DiscreteProductMeasure, resize,
    isbasis, hastransform, dimensions, productmeasure
import Base: getindex
import BasisFunctions: elements, dictionary, element, measure, iscomposite, AbstractMeasure

#################
# Platform
#################
export Platform, BasisPlatform, FramePlatform
"""
    abstract type Platform end

A platform represents a family of dictionaries.

A platform typically has a primal and a dual sequence. The platform maps an
index to a set of parameter values, which is then used to generate a primal
or dual dictionary (depending on the chosen measure).

See also [`BasisPlatform`](@ref), `FramePlatform`](@ref)
"""
abstract type Platform end
getindex(platform::Platform, param) = dictionary(platform, param)
correctparamformat(platform::Platform, _) = false
function dictionary(platform::Platform, param)
    if !correctparamformat(platform, param)
        throw(ArgumentError("Parameter $param not suited for platform $platform. "))
    end
    unsafe_dictionary(platform, param)
end

export dictionary, dualdictionary

"""
    dualdictionary(platform::Platform, param, measure::AbstractMeasure; options...)

Return the dual dictionary of the platform.
"""
dualdictionary(platform::Platform, param, measure::AbstractMeasure; dict=dictionary(platform, param), options...) =
    gramdual(dict, measure; options...)

include("platformadaptivity.jl")

"""
    abstract type BasisPlatform <: Platform end

A `BasisPlatform` represents a family of bases.
"""
abstract type BasisPlatform <: Platform end

"""
    abstract type FramePlatform <: Platform end

A `FramePlatform` represents a family of frames
(or ill-conditioned bases which are in the limit a frame).
"""
abstract type FramePlatform <: Platform end


include("styles.jl")






#################
# ModelPlatform
#################
"""
    struct ModelPlatform <: Platform

A `ModelPlatform` is a platform based on a model dictionary. The platform is
defined by resizing the dictionary, using its own implementation of `resize`.
All other operations are the defaults for the model dictionary.

This platform is convenient to compute adaptive approximations based on an
example of a dictionary from the desired family.
"""
struct ModelPlatform <: Platform
    model   ::  Dictionary
end

model(p::ModelPlatform) = p.model
unsafe_dictionary(p::ModelPlatform, param) = resize(model(p), param)

param_first(p::ModelPlatform) = dimensions(model(p))
DictionaryStyle(p::ModelPlatform) = isbasis(model(p)) ? BasisStyle() : UnknownDictionaryStyle()
SamplingStyle(p::ModelPlatform) = isbasis(model(p)) ? InterpolationStyle() : OversamplingStyle()
SolverStyle(p::ModelPlatform, samplingstyle::SamplingStyle) = SolverStyle(DictionaryStyle(p), p, samplingstyle)

export correctparamformat
correctparamformat(p::ModelPlatform, param)  =
    param isa typeof(dimensions(model(p)))

export measure
measure(platform::ModelPlatform) = measure(model(platform))
elements(platform::ModelPlatform) = map(ModelPlatform, elements(model(platform)))
element(platform::ModelPlatform, i) = ModelPlatform(element(model(platform), i))







#################
# ProductPlatform
#################
export ProductPlatform
"""
    struct ProductPlatform{N} <: Platform

A `ProductPlatform` corresponds to the product of two or more platforms. It results in a product
dictionary, product sampling operator, product solver, ... etcetera.
"""
struct ProductPlatform{N} <: Platform
    platforms   ::  NTuple{N,Platform}
end

ProductPlatform(platforms::Platform...) = ProductPlatform(platforms)

param_first(platform::ProductPlatform) = map(param_first, elements(platform))

function DictionaryStyle(p::ProductPlatform)
    dict = TensorProductDict(map(x->dictionary(x,1), elements(p))...)
    isbasis(dict) ? BasisStyle() : FrameStyle()
end
ProductPlatform(platform::Platform, n::Int) = ProductPlatform(ntuple(x->platform, n)...)
dualdictionary(platform::ProductPlatform, param, measure::AbstractMeasure; options...) =
    (@assert length(param)==length(elements(platform));
    TensorProductDict(map((plati, parami, mi)->dualdictionary(plati, parami, mi; options...), elements(platform), param, elements(measure))...))
iscomposite(p::ProductPlatform) = true
elements(p::ProductPlatform) = p.platforms

element(p::ProductPlatform, i) = p.platforms[i]

export productparameter
"""
    productparameter(p::ProductPlatform{N}, param)

Transform the parameter to a parameter accepted by a ProductPlatform
"""
productparameter(p::ProductPlatform{N}, n::Int) where {N} = ntuple(x->n, Val(N))
productparameter(p::ProductPlatform{N}, n::NTuple{N,Any}) where {N} = n

SamplingStyle(platform::ProductPlatform) = ProductSamplingStyle(map(SamplingStyle, elements(platform)))
SolverStyle(p::ProductPlatform, samplingstyle) =
    ProductSolverStyle(map(SolverStyle, elements(p), elements(samplingstyle)))

dictionary(p::ProductPlatform, n::Int) = dictionary(p, productparameter(p, n))

unsafe_dictionary(p::ProductPlatform, n) = tensorproduct(map(dictionary, elements(p), n)...)

dualdictionary(platform::ProductPlatform, param, measure::Union{ProductMeasure,DiscreteProductMeasure}; options...) =
    tensorproduct(map((platformi, parami, mi)->dualdictionary(platformi, parami, mi; options...),
        elements(platform), param, elements(measure))...)

measure(platform::ProductPlatform) = productmeasure(map(measure, elements(platform))...)

correctparamformat(p::ProductPlatform{N}, param::NTuple{N,Int}) where N =
    all(map(correctparamformat, p.platforms, param))

correctparamformat(::ProductPlatform, param) = false

export param, platform
"""
    param(dict::Dictionary) = dimensions(dict)

Return the parameter that is given to a platform to obtain again the dictionary.
"""
param(dict::Dictionary) = dimensions(dict)

"""
    platform(dict::Dictionary)

Return a platform that generates dictionaries of the type of dict.
"""
platform(dict::Dictionary1d) = ModelPlatform(dict)
platform(dict::TensorProductDict) = ProductPlatform(map(platform, elements(dict))...)
end
