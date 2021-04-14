using Dates

# TODO This should live in TeaFiles.Body. Also read_items needs to support DateTimes!
TimeLike = Union{Real, DateTime}

function read(
    source::IO;
    lower::Union{Nothing, TimeLike}=nothing,
    upper::Union{Nothing, TimeLike}=nothing
)::Vector{<:NamedTuple}
    metadata = Base.read(source, Header.TeaFileMetadata)
    return Body.read_items(source, metadata; lower=lower, upper=upper)
end

function read(
    source::AbstractString;
    lower::Union{Nothing, TimeLike}=nothing,
    upper::Union{Nothing, TimeLike}=nothing
)::Vector{<:NamedTuple}
    return open(source; read=true) do io
        read(io; lower=lower, upper=upper)
    end
end

# function write()
