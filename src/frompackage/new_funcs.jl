const EMPTY_PIPE = Pipe()
const MODEXPR = Ref{Function}(identity)
const STDLIBS_DATA = Dict{String, Base.UUID}()
for (uuid, (name, _)) in Pkg.Types.stdlibs()
    STDLIBS_DATA[name] = uuid
end
CURRENT_FROMPACKAGE_CONTROLLER = Ref{FromPackageController}()

struct RemoveThisExpr end

#### New approach stuff ####
get_loaded_modules_mod() = getproperty(get_temp_module(), :_LoadedModules_)::Module

# This is a callback to add any new loaded package to the Main._FromPackage_TempModule_._LoadedModules_ module
function mirror_package_callback(modkey::Base.PkgId)
    target = get_loaded_modules_mod
    name = Symbol(modkey)
    m = Base.root_module(modkey)
    Core.eval(target, :(const $name = $m))
    if isassigned(CURRENT_FROMPACKAGE_CONTROLLER)
        try_load_extensions!(CURRENT_FROMPACKAGE_CONTROLLER[])
    end
    return
end

function get_package_module(p::FromPackageController{name}) where name
    @nospecialize
    getproperty(get_temp_module(), name)::Module
end

# This will try to see if the extensions of the target package can be loaded
function try_load_extensions!(p::FromPackageController)
    @nospecialize
    loaded_modules = get_loaded_modules_mod()
    (; extensions, deps, weakdeps) = p.project
    for (name, triggers) in extensions
        nactive = 0
        for trigger_name in triggers
            trigger_uuid = weakdeps[trigger_name]
            id = Base.PkgId(trigger_uuid, trigger_name)
            nactive += isdefined(loaded_modules, Symbol(id))
        end
        if nactive === length(triggers)
            modexpr = custom_walk!(p)
            entry_path = Base.project_file_ext_path(p.project.file, name)
            ex = :(include($modexpr, $entry_path))
            Core.eval(get_package_module(p), ex)
        end
    end
end

function populate_loaded_modules()
    loaded_modules = get_loaded_modules_mod()
    @lock Base.require_lock begin
        for (id, m) in Base.loaded_modules
            name = Symbol(id)
            isdefined(loaded_modules, name) && continue
            Core.eval(loaded_modules, :(const $name = $m))
        end
    end
    empty!(Base.package_callbacks) ### IMPORTANT, TO REMOVE ###
    if mirror_package_callback ∉ Base.package_callbacks
        # Add the package callback if not already present
        push!(Base.package_callbacks, mirror_package_callback)
    end
end

function get_loaded_module(id::Base.PkgId)
    loaded_modules = get_loaded_modules_mod()
    m = getproperty(loaded_modules, Symbol(id))::Module
    return m
end
function get_loaded_module(p::FromPackageController{name}, base_name) where name
    @nospecialize
    base_name === name && return get_package_module(p)
    package_name = string(base_name)
    proj = p.project
    uuid = get(proj.deps, package_name) do
        get(proj.weakdeps, package_name) do 
            get(STDLIBS_DATA, package_name) do
                error("The package with name $package_name could not be found as deps or weakdeps of the target project, or as standard library")
            end
        end
    end
    id = Base.PkgId(uuid, package_name)
    return get_loaded_module(id)
end

# This function will return, for each package of the expression, two outputs which represent the modname path of the package being used, and the list of imported names
function extract_import_names(ex::Expr)
    @assert Meta.isexpr(ex, (:using, :import)) "The `extract_import_names` only accepts `using` or `import` statements as input"
    out = map(ex.args) do arg
        if Meta.isexpr(arg, :(:))
            # This is the form `using PkgName: name1, name2, ...`
            package_expr, names_expr... = arg.args
            package_path = package_expr.args .|> Symbol
            # We extract the last symbol as we can also do e.g. `import A: B.C`, which will bring C in scope
            full_names = map(ex -> ex.args, names_expr)
            imported_names = map(x -> Symbol(last(x)), full_names)
            return package_path, imported_names, full_names
        else
            package_path = arg.args .|> Symbol
            imported_names = Symbol[]
            return package_path, imported_names, []
        end
    end
    return out
end

function reconstruct_import_statement(package_path::Vector{Symbol}, full_names::Vector)
    pkg = Expr(:., package_path...)
    isempty(full_names) && return pkg
    names = map(full_names) do path
        Expr(:., path...)
    end
    return Expr(:(:), pkg, names...)
end
function reconstruct_import_statement(outs::Vector{<:Tuple})
    map(outs) do (package_path, _, full_names)
        reconstruct_import_statement(package_path, full_names)
    end
end
function reconstruct_import_statement(head::Symbol, args...)
    inner = reconstruct_import_statement(args...)
    inner isa Vector || (inner = [inner])
    return Expr(head, inner...)
end


# This function will add to p.using_names the names either specified by `imported_names` or exported by the module pointed at by `modname_path`. 
function add_using_names!(p::FromPackageController, modname_path::Vector{Symbol}, imported_names::Vector{Symbol})
    @nospecialize
    base_module = first(modname_path)
    key, _module = if base_module === :. # This is a local module
        m = p.current_module
        # We remove the first dot
        popfirst!(modname_path)
        while first(modname_path) === :.
            # We pop one from the modname
            popfirst!(modname_path)
            # We pop the last from the module path
            m = parentmodule(m)
        end
        # We now eventually go down in the remaining modname_path
        for name in modname_path
            m = getproperty(m, name)::Module
        end
        # We get the path of this module relative to the package root (1 and 2 in the fullname are Main._FromPackage_TempModule_)
        _, _, relative_path... = fullname(m)
        # We join the path
        collect(relative_path), m
    else
        # We are loading a normal package not located within the loaded module
        path = copy(modname_path)
        base_name = popfirst!(path)
        m = get_loaded_module(p, base_name)
        for name in path
            m = getproperty(m, name)::Module
        end
        # This is another package, we just use the modname_path as it is
        modname_path, m
    end
    names_set = get!(Set{Symbol}, p.using_names, key)
    # We check whether we explicitly imported or just did `using PkgName`
    to_add = isempty(imported_names) ? names(m) : imported_names
    union!(names_set, to_add)
    return p
end

# Extracts the name (as Symbol) of the loaded package
function symbol_name(::FromPackageController{T})::Symbol where T
    @nospecialize
    return T
end
# Returns the name (as Symbol) of the variable where the controller will be stored within the generated module
variable_name(p::FromPackageController) = (@nospecialize; :_frompackage_controller_)

# This function is inspired by MacroTools.walk (and prewalk/postwalk). It allows to specify custom way of parsing the expressions of an included file/package. The first method is used to process the include statement as the `modexpr` in the two-argument `include` method (i.e. `include(modexpr, file)`)
function custom_walk!(p::AbstractEvalController) 
    @nospecialize
    function modexpr(ex)
        out = custom_walk!(p, ex)
        return out
    end
    return modexpr
end
custom_walk!(p::AbstractEvalController, ex) = (@nospecialize; ex) # pass-through for non exprs
custom_walk!(p::AbstractEvalController, ex::Expr) = (@nospecialize; custom_walk!(p, ex, Val{ex.head}()))
custom_walk!(p::AbstractEvalController, ex::Expr, ::Val) = (@nospecialize; Expr(ex.head, map(custom_walk!(p), ex.args)...))

function valid_blockarg(this_arg, next_arg)
    @nospecialize
    if this_arg isa RemoveThisExpr
        return false
    elseif this_arg isa LineNumberNode
        return !isa(next_arg, LineNumberNode) && !isa(next_arg, RemoveThisExpr)
    else
        return true
    end
end

valparam(::Val{T}) where T = (@nospecialize; T)

# This process each argument of the block, and then fitlers out elements which are not expressions and clean up eventual LineNumberNodes hanging from removed expressions
function custom_walk!(p::AbstractEvalController, ex::Expr, val::Union{Val{:block}, Val{:toplevel}})
    @nospecialize
    f = custom_walk!(p)
    args = map(f, ex.args)
    # We now go in reverse args order, and remove all the RemoveThisExpr (and corresponding LineNumberNodes)
    valids = trues(length(args))
    next_arg = RemoveThisExpr()
    for i in reverse(eachindex(args))
        this_arg = args[i]
        valids[i] = valid_blockarg(this_arg, next_arg)
        next_arg = this_arg
    end
    return Expr(valparam(val), args[valids]...)
end
# This handles removing PLUTO expressions
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:(=)})
    if ex.args[1] in (:PLUTO_PROJECT_TOML_CONTENTS, :PLUTO_MANIFEST_TOML_CONTENTS) && ex.args[2] isa String
        return RemoveThisExpr()
    else
        return Expr(:(=), map(custom_walk!(p), ex.args)...)
    end
end

# This will handle the import statements of extensions packages
function modify_extensions_imports!(p::FromPackageController, ex::Expr)
    @nospecialize
    @assert Meta.isexpr(ex, (:using, :import)) "You can only call this function with using or import expressions as second argument"
    weakdeps = p.project.weakdeps
    target_name = p.project.name
    out = map(extract_import_names(ex)) do (package_path, imported_names, full_names)
        base_name = first(package_path) |> string
        if base_name === target_name
            prepend!(package_path, [:., :.])
        elseif haskey(weakdeps, base_name)
            uuid = weakdeps[base_name]
            id = Base.PkgId(uuid, base_name)
            package_path[1] = Symbol(id)
            prepend!(package_path, (:Main, :_FromPackage_TempModule_, :_LoadedModules_))
        end
        (package_path, imported_names, full_names)
    end
    new_ex = reconstruct_import_statement(ex.head, out)
    return new_ex
end
# This will add calls below the `using` to track imported names
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:using})
    current_module_name = p.current_module |> nameof |> string
    haskey(p.project.extensions, current_module_name) && return modify_extensions_imports!(p, ex)
    # We wrap the using statement in a begin block to be able to add expressions after it
    new_ex = Expr(:block, ex)
    for (package_path, imported_names, _) in extract_import_names(ex)
        push!(new_ex.args, :($add_using_names!($p, $package_path, $imported_names)))
    end
    return new_ex
end
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:import})
    current_module_name = p.current_module |> nameof |> string
    haskey(p.project.extensions, current_module_name) && return modify_extensions_imports!(p, ex)
    return ex
end

# This handles include calls, by adding custom_walk!(p) as the modexpr
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:call})
    f = custom_walk!(p)
    # We just process this expression if it's not an `include` call
    first(ex.args) === :include || return Expr(:call, map(f, ex.args)...)
    nargs = length(ex.args)
    modexpr = if nargs === 2
        # Simple 1-arg include, we just push our function as modexpr
        f
    else
        original_modexpr_name = args[2]
        :($f ∘ $original_modexpr_name)
    end
    return Expr(:call, :include, modexpr, last(ex.args))
end

# This handles modules, by storing the current module in the controller at the beginning of the module and restoring it to the parent module before exiting. It also ensure the __init__ function is executed just before restoring the module
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:module})
    # We first process the block
    block = ex.args[3] |> custom_walk!(p)
    args = block.args
    # Change the current module of the controller to this module
    pushfirst!(args, :($p.current_module = @__MODULE__))
    # Call init function if present
    push!(args, :($maybe_call_init(@__MODULE__)))
    # We change back the current module to the parentmodule
    push!(args, :($p.current_module = parentmodule(@__MODULE__)))
    ex.args[3] = block
    return ex
end

function maybe_call_init(m::Module)
    # Check if it exists
    isdefined(m, :__init__) || return nothing
    # Check if it's owned by this module
    which(m, :__init__) === m || return nothing
    f = getproperty(m, :__init__)
    # Verify that is a function
    f isa Function || return nothing
    f() # execute it
    return nothing
end

nested_getproperty_expr(name::Symbol) = QuoteNode(name)
# This function creates the expression to access a nested property specified by a path. For example, if `path = [:Main, :ASD, :LOL]`, `nested_getproperty_expr(path...)` will return the expression equivalent to `Main.ASD.LOL`. This is not to be used within `import/using` statements as the synthax for accessing nested modules is different there.
function nested_getproperty_expr(names_path::Symbol...)
    @nospecialize
    others..., tail = names_path
    last_arg = nested_getproperty_expr(tail)
    first_arg = length(others) === 1 ? first(others) : nested_getproperty_expr(others...)
    ex = isempty(others) ? arg : Expr(:., first_arg, last_arg)
    return ex
end