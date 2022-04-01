function check_p6 end

"""
    transform_p6!(g, center, use_uv, new_coords_fun, converter_fun)

Run transgormation P6 on triangle represented by interior `center`.

Three hanging nodes, any edge can be the longest-edge.

```text
     v                v
    / \\              /|\\
   h   h     =>     h | h
  /     \\          /  |  \\
 v---h---v        v---h---v
```

Conditions:
- Breaks *longest edge*
"""
function transform_p6!(
    g::MeshGraph,
    center::Integer;
    use_uv::Bool,
    distance_fun::Function,
    new_coords_fun::Function,
    converter_fun::Function,
)::Bool
    mapping = check_p6(g, center, distance_fun)
    if isnothing(mapping)
        return false
    end

    v1, v2, v3, h1, h2, h3 = mapping

    unset_hanging!(g, h1)

    add_edge!(g, v3, h1)

    add_interior!(g, v1, h1, v3)
    add_interior!(g, h1, v2, v3)

    rem_vertex!(g, center)

    return true
end


function check_p6(g::MeshGraph, center::Integer, distance_fun::Function)
    if !is_interior(g, center)
        return nothing
    end

    vs = interiors_vertices(g, center)
    vA = vs[1]
    vB = vs[2]
    vC = vs[3]
    hA = get_hanging_node_between(g, vB, vC)
    hB = get_hanging_node_between(g, vA, vC)
    hC = get_hanging_node_between(g, vA, vB)

    if isnothing(hA) || isnothing(hB) || isnothing(hC) || hA == vA || hB == vB || hC == vC
        return nothing
    end

    lA = distance_fun(g, vB, hA) + distance_fun(g, vC, hA)
    lB = distance_fun(g, vA, hB) + distance_fun(g, vC, hB)
    lC = distance_fun(g, vA, hC) + distance_fun(g, vB, hC)
    longest = maximum([lA, lB, lC])

    v1 = nothing
    v2 = nothing
    v3 = nothing
    h1 = nothing
    h2 = nothing
    h3 = nothing

    if longest == lA
        v1 = vB
        v2 = vC
        v3 = vA
        h1 = hA
        h2 = hB
        h3 = hB
    elseif longest == lB
        v1 = vC
        v2 = vA
        v3 = vB
        h1 = hB
        h2 = hC
        h3 = hA
    elseif longest == lC
        v1 = vA
        v2 = vB
        v3 = vC
        h1 = hC
        h2 = hA
        h3 = hB
    else
        return nothing
    end

    L12 = distance_fun(g, v1, v2)
    L34 = distance_fun(g, v2, v3)
    L56 = distance_fun(g, v3, v1)

    if L12 >= L34 && L12 >= L56
        return v1, v2, v3, h1, h2, h3
    end
    return nothing
end