const Layoutable = Union{LAxis, LObject, GridLayout}

defaultlayout(layoutable::Layoutable) = ProtrusionLayout(layoutable)

function align_to_bbox!(layoutable::Layoutable, bbox)
    layoutable.layoutobservables.suggestedbbox[] = bbox
end

reportedsizenode(layoutable::Layoutable) = layoutable.layoutobservables.reportedsize
protrusionnode(layoutable::Layoutable) = layoutable.layoutobservables.protrusions

# Define `getproperty` for each Layoutable so that inference succeeds for the fields via constant propagation
for L in Any[Any[GridLayout, LAxis]; subtypes(LObject)]
    (L === LText || L === LToggle) && continue  # defined elsewhere
    # The final `else` is for attribute lookup
    ex = :(return getfield(layoutable, :attributes)[s])
    for (fn, ft) in zip(fieldnames(L), fieldtypes(L))
        fnq = QuoteNode(fn)
        ex = Expr(:elseif, :(s === $fnq), :(return getfield(layoutable, $fnq)::$ft), ex)
    end
    ex.head = :if   # mutate the head to `if` rather than `ifelse`
    @eval begin
        function Base.getproperty(layoutable::$L, s::Symbol)
            $ex
        end
    end
end

function Base.setproperty!(layoutable::T, s::Symbol, value) where T <: Layoutable
    if s in fieldnames(T)
        setfield!(layoutable, s, value)
    else
        layoutable.attributes[s][] = value
    end
end

function Base.propertynames(layoutable::T) where T <: Layoutable
    [fieldnames(T)..., keys(layoutable.attributes)...]
end

Base.Broadcast.broadcastable(l::Layoutable) = Ref(l)
