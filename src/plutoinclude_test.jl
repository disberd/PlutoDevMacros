### A Pluto.jl notebook ###
# v0.17.1

using Markdown
using InteractiveUtils

# ╔═╡ e7d3f8f0-bb20-4b41-b482-a1d4d051b20b
a = 5152

# ╔═╡ 722a2090-c956-4733-a3a0-4e776b43853d
b = 251

# ╔═╡ a5425f17-8e08-443a-8451-a5231e3144a6
c = 142

# ╔═╡ ba9665b9-f9f4-4a69-960d-5fe40ef708a8
d = 3

# ╔═╡ 8cb5cd6b-b84d-4a12-823b-b5d247d6eb2c
Base.@kwdef struct TestStruct
	a::Int = 5
end

# ╔═╡ b5efd50a-1bf2-4634-93b8-ee6c5d7a4a3f
export TestStruct

# ╔═╡ 3951f4a5-c112-4f35-bd4f-ecff125406e3
export a

# ╔═╡ e69da1bf-c376-4760-be05-e866ccc09b2f
export b

# ╔═╡ 2d487920-1fd7-4fee-bbed-435ad883bed8
# export c, d

# ╔═╡ 849be81a-9e1a-48ff-9056-2b4648e22e5a
asd(x::Int) = "INT"

# ╔═╡ 58ddadeb-1032-41c9-be45-0087671b1524
asd(x::Float64) = "FLOAT"

# ╔═╡ 9ebec3d9-4809-46ae-8d9f-f55f3b4323a3
asd(::Real, c::Int64) = "DUAL"

# ╔═╡ d5d563a1-cde7-407a-8863-689f7dfd1a1e
asd(t::TestStruct) = "THIS IS A TESTSTRUCT"

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.0-rc2"
manifest_format = "2.0"

[deps]
"""

# ╔═╡ Cell order:
# ╠═e7d3f8f0-bb20-4b41-b482-a1d4d051b20b
# ╠═722a2090-c956-4733-a3a0-4e776b43853d
# ╠═a5425f17-8e08-443a-8451-a5231e3144a6
# ╠═ba9665b9-f9f4-4a69-960d-5fe40ef708a8
# ╠═8cb5cd6b-b84d-4a12-823b-b5d247d6eb2c
# ╠═b5efd50a-1bf2-4634-93b8-ee6c5d7a4a3f
# ╠═3951f4a5-c112-4f35-bd4f-ecff125406e3
# ╠═e69da1bf-c376-4760-be05-e866ccc09b2f
# ╠═2d487920-1fd7-4fee-bbed-435ad883bed8
# ╠═849be81a-9e1a-48ff-9056-2b4648e22e5a
# ╠═58ddadeb-1032-41c9-be45-0087671b1524
# ╠═9ebec3d9-4809-46ae-8d9f-f55f3b4323a3
# ╠═d5d563a1-cde7-407a-8863-689f7dfd1a1e
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
