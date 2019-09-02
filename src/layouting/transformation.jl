
function Transformation()
    flip = node(:flip, (false, false, false))
    scale = node(:scale, Vec3f0(1))
    scale = lift(flip, scale) do f, s
        map((f, s)-> f ? -s : s, Vec(f), s)
    end
    translation, rotation, align = (
        node(:translation, Vec3f0(0)),
        node(:rotation, Quaternionf0(0, 0, 0, 1)),
        node(:align, Vec2f0(0))
    )
    trans = nothing
    model = map_once(scale, translation, rotation, align, flip) do s, o, q, a, flip
        parent = if trans !== nothing && isassigned(trans.parent)
            boundingbox(trans.parent[])
        else
            nothing
        end
        transformationmatrix(o, s, q, a, flip, parent)
    end
    trans = Transformation(
        translation,
        scale,
        rotation,
        model,
        flip,
        align,
        signal_convert(Node{Any}, identity)
    )
end

function Transformation(scene::SceneLike)
    flip = node(:flip, (false, false, false))
    scale = node(:scale, Vec3f0(1))
    translation, rotation, align = (
        node(:translation, Vec3f0(0)),
        node(:rotation, Quaternionf0(0, 0, 0, 1)),
        node(:align, Vec2f0(0))
    )
    pmodel = transformationmatrix(scene)
    trans = nothing
    model = map_once(scale, translation, rotation, align, pmodel, flip) do s, o, q, a, p, f
        bb = if trans !== nothing && isassigned(trans.parent)
            boundingbox(trans.parent[])
        else
            nothing
        end
        p * transformationmatrix(o, s, q, align, f, bb)
    end
    trans = Transformation(
        translation,
        scale,
        rotation,
        model,
        flip,
        align,
        signal_convert(Node{Any}, identity)
    )
    return trans
end


function translated(scene::Scene, translation...)
    tscene = Scene(scene, transformation = Transformation())
    transform!(tscene, translation...)
    tscene
end

function translated(scene::Scene; kw_args...)
    tscene = Scene(scene, transformation = Transformation())
    transform!(tscene; kw_args...)
    tscene
end

function transform!(
        scene::SceneLike;
        translation = Vec3f0(0),
        scale = Vec3f0(1),
        rotation = 0.0,
    )
    translate!(scene, translation)
    scale!(scene, scale)
    rotate!(scene, rotation)
end



transformation(t::Scene) = t.transformation
transformation(t::AbstractPlot) = t.transformation
transformation(t::Transformation) = t

scale(t::Transformable) = transformation(t).scale

scale!(t::Transformable, s) = (scale(t)[] = to_ndim(Vec3f0, Float32.(s), 1))

"""
    scale!(t::Transformable, x, y)
    scale!(t::Transformable, x, y, z)
    scale!(t::Transformable, xyz)
    scale!(t::Transformable, xyz...)

Scale the given [`Transformable`](@ref) (a Scene or Plot) to the given arguments.
Can take `x, y` or `x, y, z`.
This is an absolute scaling, and there is no option to perform relative scaling.
"""
scale!(t::Transformable, xyz...) = scale!(t, xyz)

rotation(scene::Transformable) = transformation(scene).rotation

function rotate!(::Type{T}, scene::Transformable, q) where T
    rot = convert_attribute(q, key"rotation"())
    if T === Accum
        rot1 = rotation(scene)[]
        rotation(scene)[] = rot1 * rot
    elseif T == Absolute
        rotation(scene)[] = rot
    else
        error("Unknown transformation: $T")
    end
end

"""
    rotate!(Accum, scene::Transformable, axis_rot...)

Apply a relative rotation to the Scene, by multiplying by the current rotation.
"""
rotate!(::Type{T}, scene::Transformable, axis_rot...) where T = rotate!(T, scene, axis_rot)

"""
    rotate!(scene::Transformable, axis_rot::Quaternion)
    rotate!(scene::Transformable, axis_rot::AbstractFloat)
    rotate!(scene::Transformable, axis_rot...)

Apply an absolute rotation to the Scene.  Rotations are all internally converted to
[`Quaternion`](@ref)s.
"""
rotate!(scene::Transformable, axis_rot...) = rotate!(Absolute, scene, axis_rot)
rotate!(scene::Transformable, axis_rot::Quaternion) = rotate!(Absolute, scene, axis_rot)
rotate!(scene::Transformable, axis_rot::AbstractFloat) = rotate!(Absolute, scene, axis_rot)

translation(scene::Transformable) = transformation(scene).translation

"""
    Accum
Force transformation to be relative to the current state, not absolute.
"""
struct Accum end

"""
    Absolute
Force transformation to be absolute, not relative to the current state.
This is the default setting.
"""
struct Absolute end

function translate!(::Type{T}, scene::Transformable, t) where T
    offset = to_ndim(Vec3f0, Float32.(t), 0)
    if T === Accum
        translation(scene)[] = translation(scene)[] .+ offset
    elseif T === Absolute
        translation(scene)[] = offset
    else
        error("Unknown translation type: $T")
    end
end
"""
    translate!(scene::Transformable, xyz::VecTypes)
    translate!(scene::Transformable, xyz...)

Apply an absolute translation to the Scene, translating it to `x, y, z`.
"""
translate!(scene::Transformable, xyz::VecTypes) = translate!(Absolute, scene, xyz)
translate!(scene::Transformable, xyz...) = translate!(Absolute, scene, xyz)
"""
    translate!(Accum, scene::Transformable, xyz...)

Translate the scene relative to its current position.
"""
translate!(::Type{T}, scene::Transformable, xyz...) where T = translate!(T, scene, xyz)


function transform!(scene::Transformable, x::Tuple{Symbol, <: Number})
    plane, dimval = string(x[1]), Float32(x[2])
    if length(plane) != 2 || (!all(x-> x in ('x', 'y', 'z'), plane))
        error("plane needs to define a 2D plane in xyz. It should only contain 2 symbols out of (:x, :y, :z). Found: $plane")
    end
    if all(x-> x in ('x', 'y'), plane) # xy plane
        translate!(scene, 0, 0, dimval)
    elseif all(x-> x in ('x', 'z'), plane) # xz plane
        rotate!(scene, Vec3f0(1, 0, 0), 0.5pi)
        translate!(scene, 0, dimval, 0)
    else #yz plane
        r1 = qrotation(Vec3f0(0, 1, 0), 0.5pi)
        r2 = qrotation(Vec3f0(1, 0, 0), 0.5pi)
        rotate!(scene,  r2 * r1)
        translate!(scene, dimval, 0, 0)
    end
    scene
end

transformationmatrix(x) = transformation(x).model
