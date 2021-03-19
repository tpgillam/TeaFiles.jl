"""Read a tea header from the given IO stream."""
function read_header(io::IO)::TeaFileMetadata
    _read_magic(io)

    item_start = read(io, Int64)
    item_end = read(io, Int64)
    n_sections = read(io, Int64)

    sections = AbstractSection[]
    for i_section in 1:n_sections
        push!(sections, _read_section(io))
    end


    return TeaFileMetadata(0, 0, [])
end

"""Consume the magic value if present, or throw if not."""
function _read_magic(io::IO)
    marker = read(io, Int64)
    if marker != MAGIC_VALUE
        if marker == bswap(MAGIC_VALUE)
            throw(ArgumentError(
                "This is a tea-file written on a system with different endianness."
            ))
        else
            throw(ArgumentError(
                "Expected file to start with $MAGIC_VALUE, but got $marker."
            ))
        end
    end
end

"""Read a section of the correct type."""
function _read_section(io::IO)::AbstractSection
    id = read(io, Int32)
    next_section_offset = read(io, Int32)
    # TODO use next section offset...
    return _read_tea(io, section_type(id))
end

"""Read a value previously written with _write_tea."""
_read_tea(io::IO, ::Type{T}) where T <: Real = read(io, T)
_read_tea(io::IO, ::Type{Base.UUID}) = Base.UUID(read(io, UInt128))

function _read_tea(io::IO, ::Type{String})::String
    length = read(io, Int32)
    return String(read(io, length))
end

function _read_tea(io::IO, ::Type{Vector{T}})::Vector{T} where T
    length = read(io, Int32)
    return [_read_tea(io, T) for _ in 1:length]
end

function _read_tea(io::IO, ::Type{Field})
    type_id = read(io, Int32)
    offset = read(io, Int32)
    name = _read_tea(io, String)
    return Field(type_id, offset, name)
end

function _read_tea(io::IO, ::Type{NameValue{T}})::NameValue{T} where T
    name_value = _read_tea(io, NameValue)
    type = typeof(name_value.value)
    if type != T
        error("$T does not match the type read, which is $type.")
    end
    return name_value
end

function _read_tea(io::IO, ::Type{NameValue})::NameValue
    name = _read_tea(io, String)
    kind = read(io, Int32)
    T = name_value_type(kind)
    value = _read_tea(io, T)
    return NameValue(name, value)
end

function _read_tea(io::IO, ::Type{ItemSection})::ItemSection
    item_size = read(io, Int32)
    item_name = _read_tea(io, String)
    fields = _read_tea(io, Vector{Field})
    return ItemSection(item_size, item_name, fields)
end

function _read_tea(io::IO, ::Type{TimeSection})::TimeSection
    epoch = read(io, Int64)
    ticks_per_day = read(io, Int64)
    time_field_offsets = _read_tea(io, Vector{Int32})
    return TimeSection(epoch, ticks_per_day, time_field_offsets)
end

function _read_tea(io::IO, ::Type{ContentDescriptionSection})::ContentDescriptionSection
    return ContentDescriptionSection(_read_tea(io, String))
end

function _read_tea(io::IO, ::Type{NameValueSection})::NameValueSection
    return NameValueSection(_read_tea(io, Vector{NameValue}))
end
