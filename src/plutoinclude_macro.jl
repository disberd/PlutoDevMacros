### A Pluto.jl notebook ###
# v0.17.1

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ f5486f67-7bfc-44e2-91b9-9401d81666da
#=╠═╡ notebook_exclusive
begin
	import Pkg
	Pkg.activate("..")
	using PlutoDevMacros: @skip_as_script, include_mapexpr, default_exprlist
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ a1096039-5a3d-4af7-b310-dd4b9104a5e2
using Base: SimpleVector, show_can_elide, isgensym, unwrap_unionall

# ╔═╡ fcbd82ae-c04d-4f87-bbb7-5f73bdbf8bd0
html"""
<h1>Disclaimer</h1>
The code in this notebook is made to be viewed with a fork of Pluto that provides functionality to make cells exclusive to the notebook (meaning that they are commented out in the .jl file).
<br>
This is a custom feature I use to clean up notebooks and only execute the relevant cells of a notebook when this is included from normal julia (I use notebooks as building blocks for packages)
<br>
<br>
This is heavily inspired by the cell disabling that exists in Pluto and the source code to save notebook exclusivity on the file is copied/adapted from <a href="https://github.com/fonsp/Pluto.jl/pull/1209">pull request #1209.</a>
The actual modifications to achieve this functionalities
are shown <a href="https://github.com/disberd/Pluto.jl/compare/master@%7B2021-08-05%7D...disberd:notebook-exclusive-cells@%7B2021-08-05%7D">here</a>
<br>
<br>
When opening this notebook without that functionality, all cells after the macro and functions definition are <i>notebook_exclusive</i> and are thus surrounded by block comments.
<br>
<br>
To try out the <i>exclusive</i> parts of the notebook, press this <button>button</button> toggle between commenting in or out the cells by removing (or adding) the leading and trailing block comments from the cells that are marked as <i>notebook_exclusive</i>.
<br>
You will then have to use <i>Ctrl-S</i> to execute all modified cells (where the block comments were removed)
<br>
<br>
<b>You still need to use at least version 0.17 of Pluto as the @plutoinclude macro only works properly with the macro analysis functionality that was added in that version (PlutoHooks)</b>
<br>
<br>
<b>The automatic reload of the macro when re-executing the cell is broken with CM6 so the whole cell should add/delete empty spaces after the macro before re-executing</b>

<script>
/* Get the button */
const but = currentScript.closest('.raw-html-wrapper').querySelector('button')


const exclusive_pre =  "#=╠═╡ notebook_exclusive"
const exclusive_post = "  ╠═╡ notebook_exclusive =#"

/* Define the function to identify if a cell is wrapped in notebook_exclusive comments */
const is_notebook_exclusive = cell => {
	if (cell.hasAttribute('notebook_exclusive')) return true
	const cm = cell.querySelector('pluto-input .CodeMirror').CodeMirror
	const arr = cm.getValue().split('\n')
	const pre = arr.shift()
	if (pre !== exclusive_pre)  return false/* return if the preamble is not found */
	const post = arr.pop()
	if (post !== exclusive_post)  return false/* return if the preamble is not found */
	cell.setAttribute('notebook_exclusive','')
	return true
}

// Check for each cell if it is exclusive, and if it is, toggle the related attribute and remove the comment blocks
const onClick = () => {
// 	Get all the cells in the notebook
	const cells = document.querySelectorAll('pluto-cell')
	cells.forEach(cell => {
	if (!is_notebook_exclusive(cell)) return false
	
	const cm = cell.querySelector('pluto-input .CodeMirror').CodeMirror
	const arr = cm.getValue().split('\n')
	if (arr[0] === exclusive_pre) {
// 		The comments must be removed
// 		Remove the first line
		arr.shift()
// 		Remove the last line
		arr.pop()
// 		Rejoin the array and change the editor text
	} else {
// 		The comments must be inserted
		arr.unshift(exclusive_pre)
		arr.push(exclusive_post)
	}
	cm.setValue(arr.join('\n'))
})}

but.addEventListener('click',onClick)
	invalidation.then(() => but.removeEventListener('click',onClick))	
</script>
"""

# ╔═╡ 2501c935-10c4-4dbb-ae35-0b310fcb3bfe
#=╠═╡ notebook_exclusive
default_exprlist
  ╠═╡ notebook_exclusive =#

# ╔═╡ 5089d8dd-6587-4172-9ffd-13cf43e8c341
#=╠═╡ notebook_exclusive
md"""
## Main Functions
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ e3e5510d-d1aa-442f-8d51-e42fe942f295
#=╠═╡ notebook_exclusive
@__FILE__
  ╠═╡ notebook_exclusive =#

# ╔═╡ 4a10255c-3a99-4939-ac29-65ef13b2c252
#=╠═╡ notebook_exclusive
md"""
### called from notebook 
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ a6f31a58-18ad-44d2-a6a2-f46e970f195a
#=╠═╡ notebook_exclusive
Main.PlutoRunner.cell_results.keys
  ╠═╡ notebook_exclusive =#

# ╔═╡ f41c1fa8-bd01-443c-bdeb-c49e5ff7127c
"""
	_called_from_notebook(filesrc::AbstractString)

Given the result of `@__FILE__` (or `string(__source__.file)` from a macro), check whether the macro was called directly from a Pluto notebook.

This works because the `@__FILE__` information contains the name of the Pluto notebook followed by the cell UUID in case this is called directly in a notebook (and not included from outside)
"""
function _called_from_notebook(filesrc)
	if isdefined(Main,:PlutoRunner)
		cell_id = tryparse(Base.UUID,last(filesrc,36))
		println("cell_id = $cell_id")
		println("currently_running = $(Main.PlutoRunner.currently_running_cell_id[])")
		cell_id !== nothing && cell_id === Main.PlutoRunner.currently_running_cell_id[] && return true
	end
	return false
end

# ╔═╡ b87d12be-a37b-4202-9426-3eef14d8253c
function ingredients(path::String,exprmap::Function=include_mapexpr())
	# this is from the Julia source code (evalfile in base/loading.jl)
	# but with the modification that it returns the module instead of the last object
	name = Symbol(basename(path))
	m = Module(name)
	Core.eval(m,
        Expr(:toplevel,
             :(eval(x) = $(Expr(:core, :eval))($name, x)),
             :(include(x) = $(Expr(:top, :include))($name, x)),
             :(include(mapexpr::Function, x) = $(Expr(:top, :include))(mapexpr, $name, x)),
			 :(using PlutoDevMacros: @plutoinclude, @skip_as_script), # This is needed for nested @plutoinclude calls
             :(include($exprmap,$path))))
	m
end

# ╔═╡ d42c118d-f1cd-4c0b-b84d-b7bd463d89b9
function stripmodules(s::Symbol)
	split(string(s),'.')[end]  |> Symbol
end

# ╔═╡ 46cccf51-f18e-4e81-8f74-4e47e8136dc7
md"""
# \_toexpr
"""

# ╔═╡ 1899cc1d-c2b6-49e4-96a6-7937ba568cb1
md"""
The function `_toexpr` is used to process the components of a method signature to reconstruct an expression that could be used to bring the method into scope from the parent module (loaded with `@plutoinclude`) to the current module 
"""

# ╔═╡ 72a712c8-a772-4ff6-be26-91169f78aa5c
# This function is basicaly copied and adapted from https://github.com/JuliaLang/julia/blob/743a37898d447d047002efcc19ce59825ef63cc1/base/show.jl#L604-L648
function _toexpr(v::Val, env::SimpleVector, orig::SimpleVector, wheres::Vector; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	ex = Expr(:curly)
	n = length(env)
    elide = length(wheres)
    function egal_var(p::TypeVar, @nospecialize o)
        return o isa TypeVar &&
            ccall(:jl_types_egal, Cint, (Any, Any), p.ub, o.ub) != 0 &&
            ccall(:jl_types_egal, Cint, (Any, Any), p.lb, o.lb) != 0
    end
    for i = n:-1:1
        p = env[i]
        if p isa TypeVar
            if i == n && egal_var(p, orig[i]) && show_can_elide(p, wheres, elide, env, i)
                n -= 1
                elide -= 1
            elseif p.lb === Union{} && isgensym(p.name) && show_can_elide(p, wheres, elide, env, i)
                elide -= 1
            elseif p.ub === Any && isgensym(p.name) && show_can_elide(p, wheres, elide, env, i)
                elide -= 1
            end
        end
    end
	if n > 0
        for i = 1:n
            p = env[i]
            if p isa TypeVar
                if p.lb === Union{} && something(findfirst(@nospecialize(w) -> w === p, wheres), 0) > elide
                    push!(ex.args, Expr(:(<:), _toexpr(v, p.ub;to, from, importedlist, fromname)))
                elseif p.ub === Any && something(findfirst(@nospecialize(w) -> w === p, wheres), 0) > elide
                    push!(ex.args, Expr(:(>:), _toexpr(v, p.lb; to, from, importedlist, fromname)))
                else
                    push!(ex.args, _toexpr(v, p; to, from, importedlist, fromname))
                end
            else
               push!(ex.args, _toexpr(v, p; to, from, importedlist, fromname))
            end
        end
    end
    resize!(wheres, elide)
    ex
end

# ╔═╡ c3c980a9-d4e1-4a67-b866-661bb10ae419
function _toexpr(v::Val, x::DataType, wheres::Vector = TypeVar[]; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	parameters = x.parameters::SimpleVector
    name = x.name.wrapper |> Symbol |> stripmodules
	# println("name = $name, stripped = $(stripmodules(name))")
	val = (isdefined(to,name) || name ∈ importedlist) ? name : :($fromname.$name)
	if isempty(parameters)
		return val
	end
	orig = if v isa Val{:wheres}
		unwrap_unionall(x.name.wrapper).parameters
	elseif v isa Val{:types}
		parameters
	else
		error("Unsupported Val direction")
	end
	ex = _toexpr(v, parameters, orig, wheres; to, from, importedlist, fromname)
	if isempty(ex.args)
		return val
	else
		pushfirst!(ex.args, val)
	end
	return ex
end

# ╔═╡ 981fc8df-12a0-4c06-a0be-a39809702196
function _toexpr(v::Val, x::UnionAll; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	wheres = TypeVar[]
	while x isa UnionAll
		push!(wheres,x.var)
		x = x.body
	end
	ex = _toexpr(v, x, wheres; to, from, importedlist, fromname)
end

# ╔═╡ 21d5b59c-f3a4-4404-8bed-a4e6e326f85e
function _toexpr(v::Val, x; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	return x
end

# ╔═╡ 198a00af-84f4-40a4-acf8-e5a4c460f51a
function _toexpr(v::Val{:types},x::TypeVar; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	# If this has a name, return the name
	isgensym(x.name) || return x.name
end

# ╔═╡ 40feef85-4eae-4c65-8264-327ed86394bb
function _toexpr(v::Val{:wheres},x::TypeVar; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	if isgensym(x.name)
		if x.lb === Union{}
			ex = Expr(:(<:), _toexpr(v,x.ub; to, from, importedlist, fromname))
		elseif x.ub === Any
			ex = Expr(:(:>), _toexpr(v,x.lb; to, from, importedlist, fromname))
		else
			ex = ()
		end
	else
		if x.lb === Union{} && x.ub === Any
			ex = x.name
		elseif x.lb === Union{}
			ex = Expr(:(<:), x.name, _toexpr(v,x.ub; to, from, importedlist, fromname))
		elseif x.ub === Any
			ex = Expr(:(:>), x.name, _toexpr(v,x.lb; to, from, importedlist, fromname))
		else
			ex = Expr(:comparison,_toexpr(v,x.lb; to, from, importedlist, fromname),:(<:),x.name,:(<:),_toexpr(v,x.ub; to, from, importedlist, fromname))
		end
	end
	return ex
end

# ╔═╡ 0dc5d00e-4211-4b9c-a07c-bf2035edb49c
function _toexpr(v::Val,u::Union; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	ex = Expr(:curly)
	push!(ex.args,:Union)
	push!(ex.args, _toexpr(v,u.a; to, from, importedlist, fromname))
	push!(ex.args, _toexpr(v,u.b; to, from, importedlist, fromname))
	ex
end

# ╔═╡ 57efc195-6a2f-4ad3-94fd-53e884838789
md"""
# Other Ingredients Helpers
"""

# ╔═╡ c45aa1a5-47a2-4218-a8f0-b3202ffb2f28
function _method_expr(mtd::Method; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	s = mtd.name
	lhs = Expr(:call)
	# Add the method name
	# push!(lhs.args,mtd.name)
	push!(lhs.args,s)
	nms = map(Base.method_argnames(mtd)[2:end]) do nm
		nm === Symbol("#unused#") ? gensym() : nm
	end
	tv = Any[]
    sig = mtd.sig
    while isa(sig, UnionAll)
        push!(tv, sig.var)
        sig = sig.body
    end
	# Get the argument types, stripped from TypeVars
	tps = sig.parameters[2:end]
	for (nm,sig) ∈ zip(nms,tps)
		push!(lhs.args, Expr(:(::),_toexpr(Val(:types), nm; to, from, importedlist, fromname),_toexpr(Val(:types), sig; to, from, importedlist, fromname)))
	end
	if !isempty(tv)
		lhs = Expr(:where,lhs,map(x -> _toexpr(Val(:wheres),x; to, from, importedlist, fromname),tv)...)
		# lhs = Expr(:where,lhs,tv...)
	end
	lhs
	# Add the function call
	rhs = :($fromname.$s())
	# Push the variables
	for (nm,sig) ∈ zip(nms,tps)
		if sig isa Core.TypeofVararg
			push!(rhs.args, Expr(:(...),nm))
		else
			push!(rhs.args, nm)
		end
	end
	rhs = Expr(:block, rhs)
	Expr(:(=), lhs, rhs)
end

# ╔═╡ 96b95882-97b8-48c2-97c9-1418a69b6a88
function _copymethods!(ex::Expr, s::Symbol; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	f = getfield(from,s)
	ml = methods(f,from)
	for mtd ∈ ml
		push!(ex.args, _method_expr(mtd; to, from, importedlist, fromname))
	end
	ex
end

# ╔═╡ aa28b5d8-e0d7-4b97-9220-b61a0c5f4fc4
html_reload_button() = html"""
<div class="plutoinclude_banner">
	Reload @pluto_include
</div>
<script>
	const cell = currentScript.closest('pluto-cell')

	const onClick = (e) => {
		console.log(e)
		if (e.ctrlKey) {
			history.pushState({},'')			
			cell.scrollIntoView({
				behavior: 'smooth',
				block: 'center',				
			})
		} else {
			cell.querySelector('button.runcell').click()
		}
	}
	const banner = cell.querySelector(".plutoinclude_banner")

	banner.addEventListener('click',onClick)
	invalidation.then(() => banner.removeEventListener('click',onClick))
</script>
<style>
	.plutoinclude_banner {
	    height: 20px;
	    position: fixed;
	    top: 40px;
		right: 10px;
	    margin-top: 5px;
	    padding-right: 5px;
	    z-index: 200;
		background: #ffffff;
	    padding: 5px 8px;
	    border: 3px solid #e3e3e3;
	    border-radius: 12px;
	    height: 35px;
	    font-family: "Segoe UI Emoji", "Roboto Mono", monospace;
	    font-size: 0.75rem;
	}
	.plutoinclude_banner:hover {
	    font-weight: 800;
		cursor: pointer;
	}
	body.disable_ui .plutoinclude_banner {
		display: none;
	}
	main 
</style>
"""

# ╔═╡ 98b1fa0d-fad1-4c4f-88a0-9452d492c4cb
function include_expr(from::Module,kwargstrs::String...; to::Module)
	modname = gensym()
	ex = Expr(:block, :($modname = $from))
	kwargs = (Symbol(s) => true for s ∈ kwargstrs if s ∈ ("all","imported"))
	varnames = names(from;kwargs...)
	# Remove the symbols that start with a '#' (still to check what is the impact)
	filter!(!isgensym,varnames)
	# Symbols to always exclude from imports
	exclude_names = (
			nameof(from),
			:eval,
			:include,
			Symbol("@bind"),
			Symbol("@plutoinclude"), # Since we included this in the module
			Symbol("@skip_as_script"), # Since we included this in the module
		)
	for s ∈ varnames
		if s ∉ exclude_names
			if getfield(from,s) isa Function
				_copymethods!(ex, s; to, from, importedlist = varnames, fromname = modname)
			else
				push!(ex.args,:($s = $modname.$s))
			end
		end
	end
	# Add the html to re-run the cell
	push!(ex.args,:($(html_reload_button())))
	ex
end

# ╔═╡ 872bd88e-dded-4789-85ef-145f16003351
"""
	@plutoinclude path nameskwargs...
	@plutoinclude modname=path namekwargs...

This macro is used to include external julia files inside a pluto notebook and is inspired by the discussion on [this Pluto issue](https://github.com/fonsp/Pluto.jl/issues/1101).

It requires Pluto >= v0.17.0 and includes and external file, taking care of putting in the caller namespace all varnames that are tagged with `export varname` inside the included file.

The macro relies on the use of [`names`](@ref) to get the variable names to be exported, and support providing the names of the keyword arguments of `names` to be set to true as additional strings 

When called from outside Pluto, it simply returns nothing
"""
macro plutoinclude(ex,kwargstrs...)
	path = ex isa String ? ex : Base.eval(__module__,ex)
	@skip_as_script begin
		m = ingredients(path)
		esc(include_expr(m,kwargstrs...; to = __module__))
	end
end

# ╔═╡ 63e2bd00-63b8-43f9-b8d3-b5d336744f3a
export @plutoinclude

# ╔═╡ 1f291bd2-9ab1-4fd2-bf50-49253726058f
#=╠═╡ notebook_exclusive
md"""
## Example Use
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ cf0d13ea-7562-4b8c-b7e6-fb2f1de119a7
#=╠═╡ notebook_exclusive
md"""
The cells below assume to also have the test notebook `ingredients_include_test.jl` from PlutoUtils in the same folder, download it and put it in the same folder in case you didn't already
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ bd3b021f-db44-4aa1-97b2-04002f76aeff
#=╠═╡ notebook_exclusive
notebook_path = "./plutoinclude_test.jl"
  ╠═╡ notebook_exclusive =#

# ╔═╡ 0e3eb73f-091a-4683-8ccb-592b8ccb1bee
#=╠═╡ notebook_exclusive
md"""
Try changing the content of the included notebook by removing some exported variables and re-execute (**using Shift-Enter**) the cell below containing the @plutoinclude call to see that variables are correctly updated.

You can also try leaving some variable unexported and still export all that is defined in the notebook by using 
```julia
@plutoinclude notebook_path "all"
```

Finally, you can also assign the full imported module in a specific variable by doing
```julia
@plutoinclude varname = notebook_path
```
"""
  ╠═╡ notebook_exclusive =#

# ╔═╡ d2ac4955-d2a0-48b5-afcb-32baa59ade21
#=╠═╡ notebook_exclusive
@plutoinclude notebook_path "all"
  ╠═╡ notebook_exclusive =#

# ╔═╡ 0d1f5079-a886-4a07-9e99-d73e0b8a2eec
#=╠═╡ notebook_exclusive
@macroexpand @plutoinclude notebook_path "all"
  ╠═╡ notebook_exclusive =#

# ╔═╡ 50759ca2-45ca-4005-9182-058a5cb68359
#=╠═╡ notebook_exclusive
mm = ingredients(notebook_path)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 0a28b1e8-e9f9-4f1e-96c3-daf7112df8fd
function plutodump(x::Union{Symbol, Expr})
	i = IOBuffer()
	Meta.dump(i, x)
	String(take!(i)) |> Text
end

# ╔═╡ 4cec781b-c6d7-4fd7-bbe3-f7db0f973698
#=╠═╡ notebook_exclusive
a
  ╠═╡ notebook_exclusive =#

# ╔═╡ a7e7123f-0e7a-4771-9b9b-d0da97fefcef
#=╠═╡ notebook_exclusive
b
  ╠═╡ notebook_exclusive =#

# ╔═╡ 2c41234e-e1b8-4ad8-9134-85cd65a75a2d
#=╠═╡ notebook_exclusive
c
  ╠═╡ notebook_exclusive =#

# ╔═╡ ce2a2025-a6e0-44ab-8631-8d308be734a9
#=╠═╡ notebook_exclusive
d
  ╠═╡ notebook_exclusive =#

# ╔═╡ d8be6b4c-a02b-43ec-b176-de6f64fefd87
#=╠═╡ notebook_exclusive
# Extending the method
asd(s::String) = "STRING"
  ╠═╡ notebook_exclusive =#

# ╔═╡ 8090dd72-a47b-4d9d-85df-ceb0c1bcedf5
#=╠═╡ notebook_exclusive
asd(2.0)
  ╠═╡ notebook_exclusive =#

# ╔═╡ d1fbe484-dcd0-456e-8ec1-c68acd708a08
#=╠═╡ notebook_exclusive
asd(TestStruct())
  ╠═╡ notebook_exclusive =#

# ╔═╡ 8df0f262-faf2-4f99-98e2-6b2a47e5ca31
#=╠═╡ notebook_exclusive
asd(TestStruct(),3,4)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 7e606056-860b-458d-a394-a2ae07771d55
#=╠═╡ notebook_exclusive
methods(asd)
  ╠═╡ notebook_exclusive =#

# ╔═╡ 1754fdcf-de3d-4d49-a2f0-9e3f4aa3498e
#=╠═╡ notebook_exclusive
asd("S")
  ╠═╡ notebook_exclusive =#

# ╔═╡ Cell order:
# ╠═f5486f67-7bfc-44e2-91b9-9401d81666da
# ╠═a1096039-5a3d-4af7-b310-dd4b9104a5e2
# ╟─fcbd82ae-c04d-4f87-bbb7-5f73bdbf8bd0
# ╠═2501c935-10c4-4dbb-ae35-0b310fcb3bfe
# ╟─5089d8dd-6587-4172-9ffd-13cf43e8c341
# ╠═e3e5510d-d1aa-442f-8d51-e42fe942f295
# ╟─4a10255c-3a99-4939-ac29-65ef13b2c252
# ╠═a6f31a58-18ad-44d2-a6a2-f46e970f195a
# ╠═f41c1fa8-bd01-443c-bdeb-c49e5ff7127c
# ╠═b87d12be-a37b-4202-9426-3eef14d8253c
# ╠═d42c118d-f1cd-4c0b-b84d-b7bd463d89b9
# ╟─46cccf51-f18e-4e81-8f74-4e47e8136dc7
# ╟─1899cc1d-c2b6-49e4-96a6-7937ba568cb1
# ╠═72a712c8-a772-4ff6-be26-91169f78aa5c
# ╠═c3c980a9-d4e1-4a67-b866-661bb10ae419
# ╠═981fc8df-12a0-4c06-a0be-a39809702196
# ╠═21d5b59c-f3a4-4404-8bed-a4e6e326f85e
# ╠═198a00af-84f4-40a4-acf8-e5a4c460f51a
# ╠═40feef85-4eae-4c65-8264-327ed86394bb
# ╠═0dc5d00e-4211-4b9c-a07c-bf2035edb49c
# ╟─57efc195-6a2f-4ad3-94fd-53e884838789
# ╠═98b1fa0d-fad1-4c4f-88a0-9452d492c4cb
# ╠═96b95882-97b8-48c2-97c9-1418a69b6a88
# ╠═c45aa1a5-47a2-4218-a8f0-b3202ffb2f28
# ╠═872bd88e-dded-4789-85ef-145f16003351
# ╠═63e2bd00-63b8-43f9-b8d3-b5d336744f3a
# ╠═aa28b5d8-e0d7-4b97-9220-b61a0c5f4fc4
# ╟─1f291bd2-9ab1-4fd2-bf50-49253726058f
# ╟─cf0d13ea-7562-4b8c-b7e6-fb2f1de119a7
# ╠═bd3b021f-db44-4aa1-97b2-04002f76aeff
# ╟─0e3eb73f-091a-4683-8ccb-592b8ccb1bee
# ╠═d2ac4955-d2a0-48b5-afcb-32baa59ade21
# ╠═0d1f5079-a886-4a07-9e99-d73e0b8a2eec
# ╠═8090dd72-a47b-4d9d-85df-ceb0c1bcedf5
# ╠═50759ca2-45ca-4005-9182-058a5cb68359
# ╠═0a28b1e8-e9f9-4f1e-96c3-daf7112df8fd
# ╠═4cec781b-c6d7-4fd7-bbe3-f7db0f973698
# ╠═a7e7123f-0e7a-4771-9b9b-d0da97fefcef
# ╠═2c41234e-e1b8-4ad8-9134-85cd65a75a2d
# ╠═ce2a2025-a6e0-44ab-8631-8d308be734a9
# ╠═d1fbe484-dcd0-456e-8ec1-c68acd708a08
# ╠═8df0f262-faf2-4f99-98e2-6b2a47e5ca31
# ╠═7e606056-860b-458d-a394-a2ae07771d55
# ╠═d8be6b4c-a02b-43ec-b176-de6f64fefd87
# ╠═1754fdcf-de3d-4d49-a2f0-9e3f4aa3498e
