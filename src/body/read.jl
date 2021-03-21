using TeaFiles.Header: TeaFileMetadata

"""
Seek `io` to the start of the first item at or after `time`.

Note that this operation will throw if `metadata` does not include a time section, or if
said section does not define a time field.
"""
function seek_to_time(io::IO, metadata::TeaFileMetadata, time::T) where T <: Real
    # TODO
    # TODO
    # TODO
end


"""Wrapper around an IO block, on which indexing gets the time field."""
struct ItemIOBlock{Time <: Real} <: AbstractVector{Time}
    io::IO
    item_start::Int64
    item_end::Int64
    item_size::Int32
    time_field_offset::Int32
end


# TODO If this doesn't work, this is trying to follow the docs here:
# https://docs.julialang.org/en/v1/manual/interfaces/#Indexing
Base.size(block::ItemIOBlock) = div(block.item_end - block.item_start, block.item_size)
function Base.getindex(block::ItemIOBlock{Time}, i::Int)::Time where Time
    seek(block.io, block.item_start + i * block.item_size + block.time_field_offset)
    return read(block.io, Time)
end
Base.IndexStyle(::Type{ItemIOBlock}) = IndexLinear()


"""
Seek `io` to the start of the first item at or after `time`.

We use a binary search in the range `item_start` <= i < `item_end`, since items must
be ordered by non-decreasing time.
"""
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

    # TODO use searchsortedfirst?
    #   https://github.com/JuliaLang/julia/blob/6913f9ccb156230f54830c8b7b8ef82b41cac27e/base/sort.jl#L178
    block = ItemIOBlock{typeof(time)}(io, item_start, item_end, item_size, time_field_offset)
    index = searchsortedfirst(block, time)

    seek(io, item_start + index * item_size)
    # TODO This isn't the fastest possible implementation, since it will potentially do up
    # to two (?) more seeks than strictly necessary.
    return io
end
