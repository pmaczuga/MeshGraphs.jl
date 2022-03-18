import Graphs; const Gr = Graphs
import MetaGraphs; const MG = MetaGraphs
import Base: show
using LinearAlgebra

# -----------------------------------------------------------------------------
# ------ FlatGraph type definition and constructors ---------------------------
# -----------------------------------------------------------------------------

"""
`FlatGraph` is a `MeshGraph` whose vertices are on flat surface but can be
moved up and down with `elevation` property.

Can represent samll part Earth's surface, where curvature is negligible.

# Verticex properties
All properties are the same as in `MeshGraph` except for the following:
- `VERTEX` type vertices:
    - `xyz` - cartesian coordinates of vertex (include elvation as `xyz[3]`)
    - `value` - custom property of vertex - for instance water

See also: [`MeshGraph`](@ref)
"""
mutable struct FlatGraph <: MeshGraph
    graph::MG.MetaGraph
    vertex_count::Integer
    interior_count::Integer
    hanging_count::Integer
end

function FlatGraph()
    graph = MG.MetaGraph()
    FlatGraph(graph, 0, 0, 0)
end

function show(io::IO, g::FlatGraph)
    vs = g.vertex_count
    ins = g.interior_count
    hs = g.hanging_count
    es = length(edges(g))
    print(
        io,
        "FlatGraph with ($(vs) vertices), ($(ins) interiors), ($(hs) hanging nodes) and ($(es) edges)",
    )
end

# -----------------------------------------------------------------------------
# ------ Methods for MeshGraph functions -------------------------------------
# -----------------------------------------------------------------------------

function add_vertex!(
    g::FlatGraph,
    coords::AbstractVector{<:Real};
    value::Real = 0.0,
)::Integer
    Gr.add_vertex!(g.graph)
    MG.set_prop!(g.graph, nv(g), :type, VERTEX)
    MG.set_prop!(g.graph, nv(g), :value, value)
    MG.set_prop!(g.graph, nv(g), :xyz, coords[1:3])
    g.vertex_count += 1
    return nv(g)
end

function add_vertex!(
    g::FlatGraph,
    coords::AbstractVector{<:Real},
    elevation::Real;
    value::Real = 0.0,
)::Integer
    Gr.add_vertex!(g.graph)
    MG.set_prop!(g.graph, nv(g), :type, VERTEX)
    MG.set_prop!(g.graph, nv(g), :value, value)
    xyz = vcat(coords[1:2], [elevation])
    MG.set_prop!(g.graph, nv(g), :xyz, xyz)
    g.vertex_count += 1
    return nv(g)
end

get_elevation(g::FlatGraph, v::Integer) = MG.get_prop(g.graph, v, :xyz)[3]

function set_elevation!(g::FlatGraph, v::Integer, elevation::Real)
    coords = MG.get_prop(g.graph, v, :xyz)
    coords[3] = elevation
    MG.set_prop!(g.graph, v, :xyz, coords)
end

coords2D(g::FlatGraph, v::Integer) = xyz(g, v)[1:2]

get_value_cartesian(g::FlatGraph, v::Integer) =
    xyz(g, v) + [0, 0, get_value(g, v)]

function scale_graph(g::FlatGraph, scale::Real)
    for v in normal_vertices(g)
        new_xyz = xyz(g, v) * scale
        MG.set_prop!(g.graph, v, :xyz, new_xyz)
    end
end