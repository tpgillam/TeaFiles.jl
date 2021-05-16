using ArgCheck
using Dates
using Tables

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

function _create_metadata_from_schema(
    @nospecialize(schema::Tables.Schema),
    item_type_name::AbstractString,
    content_description::AbstractString,
    name_values::AbstractVector{Header.NameValue}
)::Header.TeaFileMetadata
    # From the schema, create a NamedTuple which has the correct field names and types. We
    # can then use the internal API.
    item_type = NamedTuple{schema.names, Tuple{schema.types...}}
    return Header.create_metadata_julia_time(
        item_type;
        item_type_name=item_type_name,
        content_description=content_description,
        name_values=name_values
    )
end

function write(
    destination::AbstractString,
    table;
    append_only::Bool=true,
    total_rewrite::Bool=false,
    item_type_name::AbstractString="",
    content_description::AbstractString="",
    name_values::AbstractVector{Header.NameValue}=Header.NameValue[]
)
    @argcheck Tables.istable(table)

    create_new_file = total_rewrite || !isfile(destination)

    if isfile(destination) && create_new_file
        # The destination is a file, but we wish to rewrite it.
        rm(destination)
    end

    # TODO use append_only & create_new_file
    @assert create_new_file
    @assert append_only

    metadata = _create_metadata_from_schema(
        Tables.schema(table),
        item_type_name,
        content_description,
        name_values
    )

    # TODO We could avoid multiple calls to write if we know that the whole table is in the
    # correct binary form already.
    # All we need is to have every row accessible as a namedtuple for writing. Do this
    # prior to opening the file in case it takes a non-trivial amount of time.
    row_iterator = Tables.namedtupleiterator(table)

    # Perform writing
    open(destination; write=true) do io
        Base.write(io, metadata)
        for row in row_iterator
            Base.write(io, [row])
        end
    end
end
