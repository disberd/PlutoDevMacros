
#### New approach stuff ####
function get_temp_module()
    if isdefined(Main, TEMP_MODULE_NAME)
        getproperty(Main, TEMP_MODULE_NAME)::Module
    else
        m = Core.eval(Main, :(module $TEMP_MODULE_NAME
        module _LoadedModules_ end
        end))::Module
    end
end
get_temp_module(s::Symbol) = getproperty(get_temp_module(), s)
function get_temp_module(names::Vector{Symbol})
    out = get_temp_module()
    for name in names
        getproperty(out, name)
    end
    return out
end
function get_temp_module(::FromPackageController{name}) where {name}
    @nospecialize
    get_temp_module(name)::Module
end

get_loaded_modules_mod() = get_temp_module(:_LoadedModules_)::Module

function load_module!(p::FromPackageController{name}; reset=true) where {name}
    @nospecialize
    if reset
        # This reset is currently always true, it will be relevant mostly when trying to incorporate Revise
        m = let
            # We create the module holding the target package inside the calling pluto workspace. This is done to have Pluto automatically remove any binding the the previous module upon re-run of the cell containing the macro. Not doing so will cause some very weird inconsistencies as some functions will still refer to the previous version of the module which should not exist anymore from within the notebook
            temp_mod = Core.eval(p.caller_module, :(module $(gensym(:TempModule)) end))
            Core.eval(temp_mod, :(module $name end))
        end
        # We mirror the generated module inside the temp_module module, so we can alwyas access it without having to know the current workspace
        setproperty!(get_temp_module(), name, m)
        # We put the controller inside the module
        setproperty!(m, variable_name(p), p)
    end
    CURRENT_FROMPACKAGE_CONTROLLER[] = p
    try
        Core.eval(p.current_module, process_include_expr!(p, p.entry_point))
    finally
        # We set the target reached to false to avoid skipping expression when loading extensions
        p.target_reached = false
    end
    # Maybe call init
    maybe_call_init(get_temp_module(p))
    # We populate the loaded modules
    populate_loaded_modules()
    # Try loading extensions
    try_load_extensions!(p)
    return p
end

# This function separate the LNN and expression that are contained in the :block expressions returned by iteration with ExprSplitter. It is based on the assumption that each `ex` obtained while iterating with `ExprSplitter` are :block expressions with exactly two arguments, the first being a LNN and the second being the relevant expression
function destructure_expr(ex::Expr)
    @assert Meta.isexpr(ex, :block) && length(ex.args) === 2 "The expression does not seem to be coming out of iterating an `ExprSplitter` object"
    lnn, ex = ex.args
end

# This is a callback to add any new loaded package to the Main._FromPackage_TempModule_._LoadedModules_ module
function mirror_package_callback(modkey::Base.PkgId)
    @info "mirror" modkey
    target = get_loaded_modules_mod()
    name = Symbol(modkey)
    m = Base.root_module(modkey)
    @info "Mirror later" target name m
    Core.eval(target, :(const $name = $m))
    if isassigned(CURRENT_FROMPACKAGE_CONTROLLER)
        try_load_extensions!(CURRENT_FROMPACKAGE_CONTROLLER[])
    end
    return
end

# This will try to see if the extensions of the target package can be loaded
function try_load_extensions!(p::FromPackageController)
    @nospecialize
    loaded_modules = get_loaded_modules_mod()
    (; extensions, deps, weakdeps) = p.project
    for (name, triggers) in extensions
        name in p.loaded_extensions && continue
        nactive = 0
        for trigger_name in triggers
            trigger_uuid = weakdeps[trigger_name]
            id = Base.PkgId(trigger_uuid, trigger_name)
            is_loaded = isdefined(loaded_modules, Symbol(id))
            nactive += is_loaded
        end
        if nactive === length(triggers)
            entry_path = Base.project_file_ext_path(p.project.file, name)
            # Set the module to the package module
            p.current_module = get_temp_module(p)
            process_include_expr!(p, entry_path)
            push!(p.loaded_extensions, name)
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

function get_dep_from_manifest(p::FromPackageController, base_name)
    @nospecialize
    (; manifest_deps) = p
    name_str = string(base_name)
    for (uuid, pe) in manifest_deps
        if pe.name === name_str
            id = Base.PkgId(uuid, pe.name)
            return get_dep_from_loaded_modules(id)
        end
    end
    return nothing
end
function get_dep_from_loaded_modules(id::Base.PkgId)
    loaded_modules = get_loaded_modules_mod()
    key = Symbol(id)
    isdefined(loaded_modules, key) || error("The module $key can not be found in the loaded modules.")
    m = getproperty(loaded_modules, Symbol(id))::Module
    return m
end
function get_dep_from_loaded_modules(p::FromPackageController{name}, base_name; allow_manifest=false, allow_stdlibs=true)::Module where {name}
    @nospecialize
    base_name === name && return get_temp_module(p)
    package_name = string(base_name)
    if allow_stdlibs
        uuid = get(STDLIBS_DATA, package_name, nothing)
        uuid !== nothing && return get_dep_from_loaded_modules(Base.PkgId(uuid, package_name))
    end
    proj = p.project
    uuid = get(proj.deps, package_name) do
        get(proj.weakdeps, package_name) do
            out = allow_manifest ? get_dep_from_manifest(p, base_name) : nothing
            isnothing(out) && error("The package with name $package_name could not be found as deps or weakdeps of the target project, as indirect dep of the manifest, or as standard library")
            return out
        end
    end
    id = Base.PkgId(uuid, package_name)
    return get_dep_from_loaded_modules(id)
end

# This is basically `extract_import_names` that enforces a single package per statement. It is used for parsing the input statements.
function extract_input_import_names(ex)
    outs = extract_import_names(ex)
    @assert length(outs) === 1 "For import statements in the input block fed to the macro, you can only deal with one module/package per statement.\nStatements of the type `using A, B` are not allowed."
    return first(outs)
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
            full_names = map(ex -> ex.args |> Vector{Symbol}, names_expr)
            imported_names = map(x -> Symbol(last(x)), full_names)
            return ImportStatementData(package_path, imported_names, full_names)
        else
            package_path = arg.args .|> Symbol
            return ImportStatementData(package_path)
        end
    end
    return out
end

function reconstruct_import_statement(id::ImportStatementData)
    package_path = id.modname_path
    full_names = id.imported_fullnames
    pkg = Expr(:., package_path...)
    isempty(full_names) && return pkg
    names = map(full_names) do path
        if path isa Symbol
            Expr(:., path)
        else
            Expr(:., path...)
        end
    end
    return Expr(:(:), pkg, names...)
end
function reconstruct_import_statement(outs::Vector{ImportStatementData})
    map(outs) do id
        reconstruct_import_statement(id)
    end
end
function reconstruct_import_statement(head::Symbol, args...)
    inner = reconstruct_import_statement(args...)
    inner isa Vector || (inner = [inner])
    return Expr(head, inner...)
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
function custom_walk!(p::AbstractEvalController, ex)
    @nospecialize
    if p.target_reached
        return RemoveThisExpr()
    else
        # We pass through all non Expr, and process the Exprs
        new_ex = ex isa Expr ? custom_walk!(p, ex, Val{ex.head}()) : ex
        return new_ex
    end
end
custom_walk!(p::AbstractEvalController, ex::Expr, ::Val) = (@nospecialize; Expr(ex.head, map(p.custom_walk, ex.args)...))

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

valparam(::Val{T}) where {T} = (@nospecialize; T)

function process_exprsplitter_item!(p::AbstractEvalController, ex, process_func::Function=p.custom_walk)
    # We update the current line under evaluation
    lnn, ex = destructure_expr(ex)
    p.current_line = lnn
    new_ex = process_func(ex)
    # @info "Change" ex new_ex
    if !isa(new_ex, RemoveThisExpr) && !p.target_reached
        Core.eval(p.current_module, new_ex)
    end
    return
end

# This process each argument of the block, and then fitlers out elements which are not expressions and clean up eventual LineNumberNodes hanging from removed expressions
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:block})
    @nospecialize
    f = p.custom_walk
    args = map(f, ex.args)
    # We now go in reverse args order, and remove all the RemoveThisExpr (and corresponding LineNumberNodes)
    valids = trues(length(args))
    next_arg = RemoveThisExpr()
    for i in reverse(eachindex(args))
        this_arg = args[i]
        valids[i] = valid_blockarg(this_arg, next_arg)
        next_arg = this_arg
    end
    any(valids) || return RemoveThisExpr()
    return Expr(:block, args[valids]...)
end

# This will handle the import statements of extensions packages
function modify_extensions_imports!(p::FromPackageController, ex::Expr)
    @nospecialize
    @assert Meta.isexpr(ex, (:using, :import)) "You can only call this function with using or import expressions as second argument"
    weakdeps = p.project.weakdeps
    target_name = p.project.name
    outs = map(extract_import_names(ex)) do import_data
        (; modname_path, imported_names, imported_fullnames) = import_data
        base_name = first(modname_path) |> string
        if base_name === target_name
            prepend!(modname_path, [:., :.])
        elseif haskey(weakdeps, base_name)
            uuid = weakdeps[base_name]
            id = Base.PkgId(uuid, base_name)
            modname_path[1] = Symbol(id)
            prepend!(modname_path, (:Main, :_FromPackage_TempModule_, :_LoadedModules_))
        end
        import_data
    end
    new_ex = reconstruct_import_statement(ex.head, outs)
    Expr(:toplevel, p.current_line, new_ex)
end
# This will add calls below the `using` to track imported names
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:using})
    @nospecialize
    current_module_name = p.current_module |> nameof |> string
    new_ex = if haskey(p.project.extensions, current_module_name)
        # We are inside an extension code, we do not need to track usings
        modify_extensions_imports!(p, ex)
    else # Here we want to track the using expressions
        # We add the expression to the set for the current module
        expr_set = get!(Set{Expr}, p.using_expressions, p.current_module)
        push!(expr_set, ex)
        # We just leave the expression unchanged
        ex
    end
    return new_ex
end

# We need to do this because otherwise we mess with struct definitions
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:struct})
    @nospecialize
    return ex
end

function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:import})
    @nospecialize
    current_module_name = p.current_module |> nameof |> string
    haskey(p.project.extensions, current_module_name) && return modify_extensions_imports!(p, ex)
    return ex
end

# This handles include calls, by adding p.custom_walk as the modexpr
function custom_walk!(p::AbstractEvalController, ex::Expr, ::Val{:call})
    @nospecialize
    f = p.custom_walk
    # We just process this expression if it's not an `include` call
    first(ex.args) === :include || return Expr(:call, map(f, ex.args)...)
    new_ex = :($process_include_expr!($p))
    append!(new_ex.args, ex.args[2:end])
    return new_ex
end

function get_filepath(p::FromPackageController, path::AbstractString)
    @nospecialize
    (; current_line) = p
    base_dir = if isnothing(current_line)
        pwd()
    else
        p.current_line.file |> string |> dirname
    end
    return abspath(base_dir, path)
end

function split_and_execute!(p::FromPackageController, ast::Expr, f=p.custom_walk)
    @nospecialize
    top_mod = prev_mod = p.current_module
    for (mod, ex) in ExprSplitter(top_mod, ast)
        # Update the current module
        p.current_module = mod
        process_exprsplitter_item!(p, ex, f)
        if prev_mod !== top_mod && mod !== prev_mod
            maybe_call_init(prev_mod) # We try calling init in the last module after switching
        end
        prev_mod = mod
    end
end

function process_include_expr!(p::FromPackageController, path::AbstractString)
    @nospecialize
    process_include_expr!(p, identity, path)
end
function process_include_expr!(p::FromPackageController, modexpr::Function, path::AbstractString)
    @nospecialize
    filepath = get_filepath(p, path)
    if issamepath(p.target_path, filepath)
        p.target_reached = true
        p.target_location = p.current_line
        p.target_module = p.current_module
        return nothing
    end
    _f = p.custom_walk
    f = if modexpr isa ComposedFunction{typeof(_f),<:Any}
        modexpr # We just use that directly
    else
        # We compose
        _f ∘ modexpr
    end
    # @info "Custom Including $(basename(filepath))"
    ast = extract_file_ast(filepath)
    split_and_execute!(p, ast, f)
    return nothing
end

function maybe_call_init(m::Module)
    # Check if it exists
    isdefined(m, :__init__) || return nothing
    # Check if it's owned by this module
    which(m, :__init__) === m || return nothing
    f = getproperty(m, :__init__)
    # Verify that is a function
    f isa Function || return nothing
    Core.eval(m, :(__init__()))
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

### Input Parsing
# This function will extract the first name of a module identifier from `import/using` statements
function get_modpath_root(ex::Expr)
    (;modname_path) = extract_input_import_names(ex)
    modname_first = first(modname_path)
    return modname_first
end

# This function traverse a path to access a nested module from a `starting_module`. It is used to extract the corresponding module from `import/using` statements.
function extract_nested_module(starting_module::Module, nested_path; first_dot_skipped=false)
    m = starting_module
    for name in nested_path
        m = if name === :.
            first_dot_skipped ? parentmodule(m) : m
        else
            @assert isdefined(m, name) "The module `$name` could not be found inside parent module `$(nameof(m))`"
            getproperty(m, name)::Module
        end
        first_dot_skipped = true
    end
    return m
end

# This will construct the catchall import expression for the module `m`
function catchall_import_expression(p::FromPackageController, m::Module; exclude_usings::Bool=false)
    @nospecialize
    modname_path = fullname(m) |> collect
    imported_names = filterednames(p, m)
    id = ImportStatementData(modname_path, imported_names)
    # We use `import` explicitly as Pluto does not deal well with `using` not directly handled by the PkgManager
    ex = reconstruct_import_statement(:import, id)
    # We simplty return this if we exclude usings
    exclude_usings && return ex
    # Otherwise, we have to add
    block = quote
        $ex
    end
    # We extract the using expression that were encountered while loading the specified module
    using_expressions = get(Set{Expr}, p.using_expressions, m)
    for ex in using_expressions
        for out in extract_import_names(ex)
            ex = process_input_statement(p, out; is_import = false, allow_manifest = false, pop_first = false)
            push!(block.args, ex)
        end
    end
    return block
end

# This function will generate an importa statement by expanding the modname_path to the correct path based on the provided `starting_module`. It will also expand imported names if a catchall expression is found
function generate_import_statement(p::FromPackageController, ex::Expr, starting_module::Module; pop_first::Bool=true, exclude_usings::Bool=false)
    @nospecialize
    # We extract the arguments of the statement
    (; modname_path, imported_names) = id = extract_input_import_names(ex)
    # We remove the first dot as it's a relative import with potentially invalid first name
    pop_first && popfirst!(modname_path)
    import_module = extract_nested_module(starting_module, modname_path; first_dot_skipped=true) # We already skipped the first dot
    catchall = length(imported_names) === 1 && first(imported_names) === :*
    if catchall
        catchall_import_expression(p, import_module; exclude_usings)
    else
        # We have to update the modname_path
        id.modname_path = fullname(import_module) |> collect
        return reconstruct_import_statement(ex.head, id)
    end
end

function RelativeImport(p::FromPackageController, ex::Expr; exclude_usings::Bool)
    @nospecialize
    @assert !isnothing(p.target_module) "You can not use relative imports while calling the macro from a notebook that is not included in the package"
    new_ex = generate_import_statement(p, ex, p.target_module; pop_first=true, exclude_usings)
    return new_ex
end

function PackageImport(p::FromPackageController, ex::Expr; exclude_usings::Bool)
    @nospecialize
    new_ex = generate_import_statement(p, ex, get_temp_module(p); pop_first=true, exclude_usings)
    return new_ex
end

function CatchAllImport(p::FromPackageController, ex::Expr; exclude_usings::Bool)
    @nospecialize
    m = isnothing(p.target_module) ? get_temp_module(p) : p.target_module
    new_ex = catchall_import_expression(p, m; exclude_usings)
    return new_ex
end

# This will modify the input import statements by updating the modname_path and eventually extracting exported names from the module and explicitly import them. It will also always return an `import` statement because `using` are currently somehow broken in Pluto if not handled by the PkgManager
function process_input_statement(p::FromPackageController, out::ImportStatementData; pop_first::Bool = false, allow_manifest = false, is_import::Bool = true)
    (; modname_path, imported_names) = out
    pop_first && popfirst!(modname_path)
    root_name = first(modname_path)
    target_module, new_modname = if root_name === :.
        _m = extract_nested_module(m, modname_path)
        _m, fullname(_m) |> collect
    else
        _m = get_dep_from_loaded_modules(p, root_name; allow_manifest)
        new_modname = Symbol[
            :Main, TEMP_MODULE_NAME, :_LoadedModules_,
            Symbol(Base.PkgId(_m)),
            modname_path[2:end]...
        ]
        _m, new_modname
    end
    ex = if isempty(imported_names)
        # We are just plain using, so we have to explicitly extract the exported names
        nms = if is_import 
            [nameof(target_module)]
        else 
            filter(names(target_module)) do name
                Base.isexported(target_module, name)
            end
        end
        reconstruct_import_statement(:import, ImportStatementData(new_modname, nms))
    else
        # We have an explicit list of names, so we simply modify the using to import
        reconstruct_import_statement(:import, ImportStatementData(new_modname, imported_names))
    end
    return ex
end

function DepsImport(p::FromPackageController, ex::Expr; exclude_usings::Bool=false)
    @nospecialize
    is_import = ex.head === :import
    id = extract_input_import_names(ex)
    new_ex = process_input_statement(p, id; pop_first=true, allow_manifest = true, is_import)
    return new_ex
end

# Macro
macro lolol(target::Symbol, ex::Expr)
    isdefined(__module__, target) || error("The symbol $target is not defined in the caller module")
    # @info "$(__module__)"
    path = Core.eval(__module__, target)
    p = FromPackageController(path, __module__)
    load_module!(p)
    args = extract_input_args(ex)
    for (i, arg) in enumerate(args)
        arg isa Expr || continue
        args[i] = process_input_expr(p, arg)
    end
    quote $(args...) end
end

function excluded_names(p::FromPackageController)
    @nospecialize
    excluded = (:eval, :include, variable_name(p), Symbol("@bind"), :PLUTO_PROJECT_TOML_CONTENTS, :PLUTO_MANIFEST_TOML_CONTENTS, :__init__)
    return excluded
end

function filterednames_filter_func(p::FromPackageController)
    @nospecialize
    f(s) =
        let excluded = excluded_names(p)
            Base.isgensym(s) && return false
            s in excluded && return false
            return true
        end
    return f
end

## Similar to names but allows to exclude names by applying a filtering function to the output of `names`.
function filterednames(m::Module, filter_func; all=true, imported=true)
    mod_names = names(m; all, imported)
    filter(filter_func, mod_names)
end
function filterednames(p::FromPackageController, m::Module; kwargs...)
    @nospecialize
    filter_func = filterednames_filter_func(p)
    return filterednames(m, filter_func; kwargs...)
end

# This is just for doing some check on the inputs and returning the list of expressions
function extract_input_args(ex)
    # Single import
    Meta.isexpr(ex, (:import, :using)) && return [ex]
    # Block of imports
    Meta.isexpr(ex, :block) && return ex.args
    # single statement preceded by @exclude_using
    Meta.isexpr(ex, :macrocall) && ex.args[1] === Symbol("@exclude_using") && return [ex]
    error("You have to call this macro with an import statement or a begin-end block of import statements")
end