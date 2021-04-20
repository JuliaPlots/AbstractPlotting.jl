
struct Entry
    title::String
    source_location::LineNumberNode
    code::Expr
    func::Function
    used_functions::Set{Symbol}
end

function Entry(title, source_location, code, func)
    used_functions = Set{Symbol}()
    MacroTools.postwalk(code) do x
        if @capture(x, f_(xs__))
            push!(used_functions, Symbol(string(f)))
        end
        if @capture(x, f_(xs__) do; body__; end)
            push!(used_functions, Symbol(string(f)))
        end
        return x
    end
    return Entry(title, source_location, code, func, used_functions)
end

function unique_name(entry::Entry)
    loc = entry.source_location
    filename = splitext(basename(string(loc.file)))[1]
    sep = isempty(entry.title) ? "" : "_"
    return replace(string(filename, "_", loc.line, sep, entry.title), " " => "")
end

function nice_title(entry::Entry)
    isempty(entry.title) || return entry.title
    return unique_name(entry)
end

const DATABASE = Dict{String, Entry}()

function cell_expr(name, code, source)
    key = string(source.file, ":", source.line)
    return quote
        closure = () -> $(esc(code))
        entry = ReferenceTests.Entry(
            $(string(name)),
            $(QuoteNode(source)),
            $(QuoteNode(code)),
            closure
        )
        ReferenceTests.DATABASE[$key] = entry
        # display(closure())
    end
end

macro cell(name, code)
    return cell_expr(name, code, __source__)
end

macro cell(code)
    return cell_expr("", code, __source__)
end

"""
    save_result(path, object)

Helper, to more easily save all kind of results from the test database
"""
function save_result(path::String, scene::AbstractPlotting.FigureLike)
    FileIO.save(path * ".png", scene)
end

function save_result(path::String, stream::VideoStream)
    FileIO.save(path * ".mp4", stream)
end

function save_result(path::String, object)
    FileIO.save(path, object)
end

function load_database()
    empty!(DATABASE)
    include(joinpath(@__DIR__, "tests/text.jl"))
    include(joinpath(@__DIR__, "tests/attributes.jl"))
    include(joinpath(@__DIR__, "tests/examples2d.jl"))
    include(joinpath(@__DIR__, "tests/examples3d.jl"))
    include(joinpath(@__DIR__, "tests/short_tests.jl"))
    return DATABASE
end
