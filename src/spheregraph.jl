import Graphs; const Gr = Graphs
import MetaGraphs; const MG = MetaGraphs
using LinearAlgebra

# -----------------------------------------------------------------------------
# ------ SphereGraph type definition and constructors -------------------------
# -----------------------------------------------------------------------------

"""
`SphereGraph` is a `MeshGraph` whose vertices are on sphere with radius
`radius`.

Can represent Earth's surface where elevation above (or below) sea level is
set using `elevation` property.

# Vertices properties
All properties are the same as in `MeshGraph` except for the following:
- `VERTEX` type vertices:
    - `xyz` - cartesian coordinates of vertex, include `elevation`
    - `uv` - geographic coordinate system - latitude and longitude of vertex
    - `elevation` - elevation of point above sea level (or below when negative)
    - `value` - custom property of vertex - for instance water

# Note
- `uv` are in degress, where:
    - `lat` is in range `[-90, 90]`
    - `lon` is in range `(-180, 180]`

See also: [`MeshGraph`](@ref)
"""
mutable struct SphereGraph <: MeshGraph
    graph::MG.MetaGraph
    radius::Real
    vertex_count::Integer
    interior_count::Integer
    hanging_count::Integer
end

"""
    SphereGraph(radius)

Construct a `SphereGraph` with radius `radius`.
"""
function SphereGraph(radius::Real)::SphereGraph
    graph = MG.MetaGraph()
    SphereGraph(graph, radius, 0, 0, 0)
end

"""
    SphereGraph()

Construct a `SphereGraph` with `radius=6371000` - Earth's radius.
"""
SphereGraph() = SphereGraph(6371000)::SphereGraph

function show(io::IO, g::SphereGraph)
    vs = g.vertex_count
    ins = g.interior_count
    hs = g.hanging_count
    es = length(edges(g))
    r = g.radius
    print(
        io,
        "SphereGraph with ($(vs) vertices), ($(ins) interiors), ($(hs) hanging nodes), ($(es) edges) and (radius $(r))",
    )
end

# -----------------------------------------------------------------------------
# ------ Functions specific for SphereGraph -----------------------------------
# -----------------------------------------------------------------------------

function cartesian_to_spherical(coords::AbstractVector{<:Real})
    x, y, z = coords
    r = norm(coords[1:3])
    lat = r !=0 ? -acosd(z / r) + 90.0 : 0
    lon = atand(y, x)
    [r, lat, lon]
end

function spherical_to_cartesian(coords::AbstractVector{<:Real})
    r, lat, lon = coords
    r .* [cosd(lon) * cosd(lat), sind(lon) * cosd(lat), sind(lat)]
end

"""
    uv(g, v)

Return latitude and longtitude of vertex `v` (in geographic coordinate system).

See also: [`SphereGraph`](@ref)
"""
uv(g::SphereGraph, v::Integer) = MG.get_prop(g.graph, v, :uv)
lat(g::SphereGraph, v::Integer) = uv(g, v)[1]
lon(g::SphereGraph, v::Integer) = uv(g, v)[2]

"Return vector `[r, lat, lon]` with spherical coordinates of vertex `v`."
function get_spherical(g::SphereGraph, v::Integer)
    coords = uv(g, v)
    elevation = MG.get_prop(g.graph, v, :elevation)
    vcat([g.radius + elevation], coords)
end

"Recalculate cartesian coordinates of vertex `v` using spherical."
function recalculate_cartesian!(g::SphereGraph, v::Integer)
    spherical = get_spherical(g, v)
    coords = spherical_to_cartesian(spherical)
    MG.set_prop!(g.graph, v, :xyz, coords)
end

"Recalculate spherical coordinates of vertex `v` using cartesian."
function recalculate_spherical!(g::SphereGraph, v::Integer)
    coords = xyz(g, v)
    spherical = cartesian_to_spherical(coords)
    MG.set_prop!(g.graph, v, :elevation, spherical[1] - g.radius)
    MG.set_prop!(g.graph, v, :uv, spherical[2:3])
end

# -----------------------------------------------------------------------------
# ------ Methods for MeshGraph functions -------------------------------------
# -----------------------------------------------------------------------------

function add_vertex!(
    g::SphereGraph,
    coords::AbstractVector{<:Real};
    value::Real = 0.0,
)::Integer
    Gr.add_vertex!(g.graph)
    MG.set_prop!(g.graph, nv(g), :type, VERTEX)
    MG.set_prop!(g.graph, nv(g), :value, value)
    MG.set_prop!(g.graph, nv(g), :xyz, coords[1:3])
    recalculate_spherical!(g, nv(g))
    g.vertex_count += 1
    return nv(g)
end

function add_vertex!(
    g::SphereGraph,
    coords::AbstractVector{<:Real},
    elevation::Real;
    value::Real = 0.0,
)::Integer
    lat = coords[1]
    if lat < -90 || lat > 90
        throw(DomainError(lat, "Latitude has to be in range [-90, 90]"))
    end
    lon = -(mod((-coords[2] + 180), 360) - 180) # moves lon to range (-180, 180]

    Gr.add_vertex!(g.graph)
    MG.set_prop!(g.graph, nv(g), :type, VERTEX)
    MG.set_prop!(g.graph, nv(g), :value, value)
    MG.set_prop!(g.graph, nv(g), :uv, [lat, lon])
    MG.set_prop!(g.graph, nv(g), :elevation, elevation)
    recalculate_cartesian!(g, nv(g))
    g.vertex_count += 1
    return nv(g)
end

get_elevation(g::SphereGraph, v::Integer) =
    MG.get_prop(g.graph, v, :elevation)::Real
function set_elevation!(g::SphereGraph, v, elevation)
    MG.set_prop!(g.graph, v, :elevation, elevation)
    recalculate_cartesian!(g, v)
end

coords2D(g::SphereGraph, v::Integer) = uv(g, v)

function get_value_cartesian(g::SphereGraph, v::Integer)
    coords = get_spherical(g, v)
    coords[1] += get_value(g, v)
    return spherical_to_cartesian(coords)
end

function scale_graph(g::SphereGraph, scale::Real)
    for v in normal_vertices(g)
        new_xyz = xyz(g, v) * scale
        g.radius = g.radius * scale
        MG.set_prop!(g.graph, v, :xyz, new_xyz)
        recalculate_spherical!(g)
    end
end