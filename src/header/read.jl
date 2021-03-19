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

function _read_tea(io::IO, ::Type{ContentDescriptionSection})::ContentDescriptionSection
    return ContentDescriptionSection(_read_tea(io, String))
end

function _read_tea(io::IO, ::Type{String})::String
    length = read(io, Int32)
    return String(read(io, length))
end
