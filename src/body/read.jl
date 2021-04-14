using ArgCheck
using Mmap

using TeaFiles.Header: ItemSection, TeaFileMetadata, create_item_namedtuple, field_type,
    get_primary_time_field, get_section, is_item_compatible

"""Wrapper around an IO block, on which indexing gets a particular field."""
mutable struct ItemIOBlock{T <: Real} <: AbstractVector{T}
    io::IO
    item_start::Int64
    item_end::Int64
    item_size::Int32
    time_field_offset::Int32
end

Base.size(block::ItemIOBlock) = (div(block.item_end - block.item_start, block.item_size),)
function Base.getindex(block::ItemIOBlock{T}, i::Int)::T where T
    seek(block.io, block.item_start + (i - 1) * block.item_size + block.time_field_offset)
    return read(block.io, T)
end
Base.IndexStyle(::Type{ItemIOBlock}) = IndexLinear()

"""Get an `ItemIOBlock` for the primary time field."""
function _get_primary_time_field_block(io::IO, metadata::TeaFileMetadata)::ItemIOBlock
    time_field = get_primary_time_field(metadata)
    item_section = get_section(metadata, ItemSection)

    time_type = field_type(time_field)

    return ItemIOBlock{time_type}(
        io,
        metadata.item_start,
        metadata.item_end == 0 ? _filesize(io) : metadata.item_end,
        item_section.item_size,
        time_field.offset
    )
end

"""
Get the position of the end of the given `io`.

Note that this may seek to the end of `io` in the process.
"""
function _filesize(io::IO)::Int64
    seekend(io)
    return position(io)
end
_filesize(io::IOBuffer) = io.size
_filesize(io::IOStream) = filesize(io)

"""Get the number of items in the given stream."""
function get_num_items(io::IO, metadata::TeaFileMetadata)::Int64
    item_end = metadata.item_end == 0 ? _filesize(io) : metadata.item_end
    return get_num_items(item_end - metadata.item_start, metadata)
end

function get_num_items(item_block_size::Integer, metadata::TeaFileMetadata)::Int64
    item_size = get_section(metadata, ItemSection).item_size
    num_items, remainder = divrem(item_block_size, item_size)
    if remainder != 0
        throw(ArgumentError(
            "item_size $item_size doesn't divide block size $item_block_size"
        ))
    end
    return num_items
end

"""
Get the position in `io` of the first item with time `time`.

We use a binary search in the range `block.item_start` <= i < `block.item_end`, since
items must be ordered by non-decreasing time. Will return `block.item_end` when `time` is
after all items present.
"""
function _first_position_ge_time(
    block::ItemIOBlock{Time},
    time::Time
)::Int64 where {Time <: Real}
    index = searchsortedfirst(block, time)
    return block.item_start + (index - 1) * block.item_size
end

function _get_item_start_and_end(
    io::IO,
    metadata::TeaFileMetadata,
    lower::Union{Nothing, Time},
    upper::Union{Nothing, Time}
)::Tuple{Int64, Int64} where {Time <: Real}
    if !isnothing(lower) && !isnothing(upper)
        @argcheck lower < upper
    elseif isnothing(lower) && isnothing(upper)
        # Fast path; we don't need to look at the time block.
        return (
            metadata.item_start,
            metadata.item_end == 0 ? _filesize(io) : metadata.item_end
        )
    end

    time_block = _get_primary_time_field_block(io, metadata)

    # Where we should start reading the file.
    item_start = if !isnothing(lower)
        # Position at start of first item we would like to read.
        position = _first_position_ge_time(time_block, lower)

        # Re-define the time block to start from the lower bound. This will make it more
        # efficient to find the upper bound if specified.
        time_block.item_start = position

        position
    else
        time_block.item_start
    end

    # Where we should end reading the file.
    item_end = if !isnothing(upper)
        # This is the position of the first time >= the upper bound; this corresponds to the
        # end position.
        _first_position_ge_time(time_block, upper)
    else
        time_block.item_end
    end

    return item_start, item_end
end

"""
    read_items(::Type{Item}, io, metadata; lower=nothing, upper=nothing)
    read_items(io, metadata; lower=nothing, upper=nothing)

Read items from `io`, returning a vector of instances of the appropriate type.

The second form of this function will attempt to form a NamedTuple that conforms to the
metadata, and read instances appropriately.

We provide the option of reading a specified closed-open time interval of such items.

# Arguments
- `::Type{Item}`: The type `Item` to be read -- should be a bits type.
- `io::IO`: The IO instance from which to read.

# Keywords
- `lower::Union[Nothing, Time]=nothing`: If specified, only include times >= `lower`.
- `upper::Union[Nothing, Time]=nothing`: If specified, only include times < `upper`.
"""
function read_items(
    ::Type{Item},
    io::IO,
    metadata::TeaFileMetadata;
    lower::Union{Nothing, Time}=nothing,
    upper::Union{Nothing, Time}=nothing
)::Vector{Item} where {Item, Time <: Real}
    # Work out where to start and end reading the file
    item_start, item_end = _get_item_start_and_end(io, metadata, lower, upper)
    if item_start == item_end
        # This will happen if the lower and upper bounds return an empty range.
        return Item[]
    end

    # Allocate output; we know the number of items that we're about to read ahead of time.
    @argcheck is_item_compatible(Item, metadata)
    item_section = get_section(metadata, ItemSection)
    num_items, remainder = divrem(item_end - item_start, item_section.item_size)
    if remainder != 0 error("Got remainder $remainder, should be zero.") end

    output = Vector{Item}(undef, num_items)
    seek(io, item_start)
    _read_mappable_items!(output, io, item_end - item_start)
    return output
end

"""
Read items, dispatched on the type of IO, so that we memory-map when possible.

This assumes that we can directly interpret bytes in `io` as `Item` instances.
"""
function _read_mappable_items!(output::Vector{Item}, io::IO, num_bytes::Int64) where {Item}
    GC.@preserve output begin
        unsafe_read(io, pointer(output), num_bytes)
    end
    return nothing
end

function _read_mappable_items!(
    output::Vector{Item},
    io::IOStream,
    num_bytes::Int64
) where {Item}
    map = Mmap.mmap(io)

    # Profiling suggests that this is the most performant way to load the data (and faster
    # than reinterpret in Julia 1.6)
    GC.@preserve output map begin
        p_source = convert(Ptr{UInt8}, pointer(map))
        p_dest = convert(Ptr{UInt8}, pointer(output))
        unsafe_copyto!(p_dest, p_source, num_bytes)
    end

    return nothing
end

function read_items(
    io::IO,
    metadata::TeaFileMetadata;
    lower::Union{Nothing, Time}=nothing,
    upper::Union{Nothing, Time}=nothing
)::Vector{<:NamedTuple} where {Time <: Real}
    item_type = create_item_namedtuple(metadata)
    return read_items(item_type, io, metadata; lower=lower, upper=upper)
end

"""
Read columns from `io`, returning a vector of vectors, one per column.

We provide the option of reading a specified closed-open time interval of such items.

# Arguments
- `::Type{Item}`: The type `Item` to be read -- should be a bits type.
- `io::IO`: The IO instance from which to read.

# Keywords
- `columns::Union[Nothing, AbstractVector{Int64}]=nothing`: If specified,
    only read columns with the given indices
- `lower::Union[Nothing, Time]=nothing`: If specified, only include times >= `lower`.
- `upper::Union[Nothing, Time]=nothing`: If specified, only include times < `upper`.
"""
function read_columns(
    io::IO,
    metadata::TeaFileMetadata;
    columns::Union{Nothing, AbstractVector{Int64}}=nothing,
    lower::Union{Nothing, Time}=nothing,
    upper::Union{Nothing, Time}=nothing
)::Vector{Vector} where {Time <: Real}
    # Work out where to start and end reading the file
    item_start, item_end = _get_item_start_and_end(io, metadata, lower, upper)

    item_section = get_section(metadata, ItemSection)

    fields = if isnothing(columns)
        # Default to all indices.
        item_section.fields
    else
        [field for (i, field) in enumerate(item_section.fields) if i in columns]
    end

    offsets = [field.offset for field in fields]
    @argcheck sort(offsets) == offsets ArgumentError(
        "Columns should be requested in the order in which they appear in the file."
    )

    # Allocate outputs; we know the number of items that we're about to read ahead of time.
    num_items, remainder = divrem(item_end - item_start, item_section.item_size)
    if remainder != 0 error("Got remainder $remainder, should be zero.") end
    output_vectors = [Vector{field_type(field)}(undef, num_items) for field in fields]

    # Read the items.

    # We always keep track of the position of the read head relative to the start of the
    # item that we are currently reading.
    current_offset = 0

    seek(io, item_start)
    for i_item in 1:num_items
        for (i_field, field) in enumerate(fields)
            if current_offset > field.offset
                # Note that, at this point, it is guaranteed that the fields appear in
                # order of increasing offset, so we never have to seek backwards. We will
                # therefore get here when we have moved onto a new item; we therefore reset
                # the current offset relative to the start of the new item.
                current_offset -= item_section.item_size
            end

            if current_offset != field.offset
                # We need to skip forward
                skip(io, field.offset - current_offset)
                current_offset = field.offset
            end

            type_ = field_type(field)
            output_vectors[i_field][i_item] = read(io, type_)
            current_offset += sizeof(type_)
        end
    end

    return output_vectors
end
