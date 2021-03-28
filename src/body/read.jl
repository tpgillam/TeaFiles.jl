using TeaFiles.Header: ItemSection, TeaFileMetadata, field_type,
    get_primary_time_field, get_section

"""Wrapper around an IO block, on which indexing gets the time field."""
struct ItemIOBlock{Time <: Real} <: AbstractVector{Time}
    io::IO
    item_start::Int64
    item_end::Int64
    item_size::Int32
    time_field_offset::Int32
end

Base.size(block::ItemIOBlock) = (div(block.item_end - block.item_start, block.item_size),)
function Base.getindex(block::ItemIOBlock{Time}, i::Int)::Time where Time
    seek(block.io, block.item_start + (i - 1) * block.item_size + block.time_field_offset)
    return read(block.io, Time)
end
Base.IndexStyle(::Type{ItemIOBlock}) = IndexLinear()

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
Seek `io` to the start of the first item at or after `time`.

Note that this operation will throw if `metadata` does not include a time section, or if
said section does not define a time field.

We use a binary search in the range `item_start` <= i < `item_end`, since items must be
ordered by non-decreasing time. We will seek to `item_end` if `time` is after the final
entry in the stream.
"""
function seek_to_time(io::IO, metadata::TeaFileMetadata, time::T) where T <: Real
    time_field = get_primary_time_field(metadata)
    item_section = get_section(metadata, ItemSection)

    if (T != field_type(time_field))
        throw(ArgumentError(
            "Specified time is of type $T, but was expecting a $(field_type(time_field))"
        ))
    end

    return seek_to_time(
        io,
        metadata.item_start,
        metadata.item_end == 0 ? _filesize(io) : metadata.item_end,
        item_section.item_size,
        time_field.offset,
        time
    )
end

function seek_to_time(
    io::IO,
    item_start::Int64,
    item_end::Int64,
    item_size::Int32,
    time_field_offset::Int32,
    time::Time
)::IO where Time <: Real
    # TODO Check that (item_end - item_start) % item_size == 0?
    # TODO Check that time_field_offset + sizeof(T) <= item_size

    block = ItemIOBlock{typeof(time)}(
        io, item_start, item_end, item_size, time_field_offset
    )
    index = searchsortedfirst(block, time)

    seek(io, item_start + (index - 1) * item_size)
    # TODO This isn't the fastest possible implementation, since it will potentially do up
    # to two (?) more seeks than strictly necessary.
    return io
end
