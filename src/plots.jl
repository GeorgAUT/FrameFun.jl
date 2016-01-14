# plots.jl


# One-dimensional plot, just the domain
function plot(f::FrameFun{1}; n=200)
    grid = EquispacedGrid(n,left(domain(f)),right(domain(f)))
    data = f(grid)
    Main.PyPlot.plot(BasisFunctions.range(grid),data)
end

## # One-dimensional plot, including extension
## function plot_full{1}(f::Fun{1})
    
## end
function plot_expansion(f::FrameFun{1}; n=200)
    grid = EquispacedGrid(n,left(basis(set(f))),right(basis(set(f))))
    data = f(grid)
    for i=-2:2
        Main.PyPlot.plot(BasisFunctions.range(grid)+i*(right(grid)-left(grid)),data,linestyle="dashed",color="blue")
    end
    Main.PyPlot.plot(BasisFunctions.range(grid),data,color="blue")
end

function plot_error(f::FrameFun{1}, g::Function; n=200)
    grid = EquispacedGrid(n,left(basis(set(f))),right(basis(set(f))))
    data = f(grid)
    for i=-2:2
        Main.PyPlot.semilogy(BasisFunctions.range(grid)+i*(right(grid)-left(grid)),abs(g(BasisFunctions.range(grid))-data),linestyle="dashed",color="blue")
    end
    Main.PyPlot.semilogy(BasisFunctions.range(grid),abs(g(BasisFunctions.range(grid))-data),color="blue")
    Main.PyPlot.ylim([-16,1])
end 

function plot_samples(f::FrameFun{1}; gamma=2)
    grid, fbasis2 = oversampled_grid(domain(f), basis(f), gamma)
    x = [grid[i] for i in eachindex(grid)]
    data = f(grid)
    Main.PyPlot.stem(x,data)
end 


# Maybe place this in funs.jl?
function call(f::FrameFun, g::AbstractGrid)
    result = Array(eltype(f), size(g))
    call!(f, result, g)
    result
end

function call!{N}(f::FrameFun, result::AbstractArray, g::AbstractGrid{N})
    x = Array(eltype(f), N)
    for i in eachindex(g)
        getindex!(x, g, i)
        result[i] = call(f, x...)
    end
end

function call!(f::FrameFun, result::AbstractArray, g::AbstractGrid1d)
    for i in eachindex(g)
        result[i] = call(f, g[i])
    end
end

function call!(f::FrameFun, result::AbstractArray, x::AbstractArray)
    @assert size(result) == size(x)
    for i = 1:length(x)
        result[i] = call(f, x[i])
    end
end



function plot{N,T}(f::FrameFun{N,T};n=100)
    Tgrid=TensorProductGrid([EquispacedGrid(100, left(set(expansion(f)),idx), right(set(expansion(f)),idx)) for idx = 1:N]...)
    Mgrid=MaskedGrid(Tgrid, domain(f))
    data = expansion(f)(Mgrid)
    x=[Mgrid[i][1] for i = 1:length(Mgrid)]
    y=[Mgrid[i][2] for i = 1:length(Mgrid)]
    Main.PyPlot.plot_trisurf(x,y,data)
end

## function plot{B}(f::FrameFun{N,T}; n=35)
##     Tgrid = TensorProductGrid([EquispacedGrid(n, left(boundingbox(domain(f)),idx), right(boundingbox(domain(f)),idx)) for idx = 1:dim(f)]...)
##     data = real(f(Tgrid))
##     Main.PyPlot.surf(BasisFunctions.range(grid(Tgrid,1)),BasisFunctions.range(grid(Tgrid,2)),data,rstride=1, cstride=1, cmap=Main.PyPlot.ColorMap("coolwarm"),linewidth=0, antialiased=false,vmin=-1.0,vmax=1.0)
## end
## # One-dimensional plot, including extension
## function plot_full{1}(f::Fun{1})
    
## end
function plot_expansion{N,T}(f::FrameFun{N,T}; n=35)
    Tgrid = TensorProductGrid([EquispacedGrid(n, left(set(expansion(f)),idx), right(set(expansion(f)),idx)) for idx = 1:dim(f)]...)
    data = real(expansion(f)(Tgrid))
    Main.PyPlot.surf(BasisFunctions.range(grid(Tgrid,1)),BasisFunctions.range(grid(Tgrid,2)),data,rstride=1, cstride=1, cmap=Main.PyPlot.ColorMap("coolwarm"),linewidth=0, antialiased=false,vmin=-1.0,vmax=1.0)
end

