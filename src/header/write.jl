Base.write(io::IO, metadata::TeaFileMetadata) = _write_tea(io, metadata)

function _write_tea(io::IO, metadata::TeaFileMetadata)::Int
    bytes_written = write(io, MAGIC_VALUE)
    bytes_written += write(io, metadata.item_start)
    bytes_written += write(io, metadata.item_end)
    bytes_written += write(io, Int64(length(metadata.sections)))  # section count
    for section in metadata.sections
        bytes_written += _write_section(io, section)
    end
    return bytes_written
end

# TODO This could just be _write_tea, but for the fact that _tea_size relies on _write_tea
#   *not* writing the section metadata.
function _write_section(io::IO, section::AbstractSection)::Int
    return (
        write(io, section_id(section)) # section_id
        + write(io, _tea_size(section))  # next_section_offset
        + _write_tea(io, section)
    )
end

"""
Get the size of this object in bytes when written.
"""
_tea_size(x::Real) = sizeof(x)
_tea_size(x::String) = 4 + sizeof(x)
_tea_size(x::Base.UUID) = sizeof(x)
function _tea_size(x::AbstractSection)::Int32
    # FIXME be less lazy
    out = IOBuffer()
    return _write_tea(out, x)
end

"""Write x in the way that a TeaFile expects."""
_write_tea(io::IO, x::Real) = write(io, x)
_write_tea(io::IO, x::Base.UUID) = write(io, x.value)

function _write_tea(io::IO, string::AbstractString)::Int
    return (
        write(io, Int32(sizeof(string)))
        + write(io, string)
    )
end

function _write_tea(io::IO, xs::Vector)
    # Write the number of items as an int32, followed by the items.
    bytes_written = write(io, Int32(length(xs)))
    for x in xs
        bytes_written += _write_tea(io, x)
    end
    return bytes_written
end

function _write_tea(io::IO, field::Field)::Int
    return (
        write(io, field.type_id)
        + write(io, field.offset)
        + _write_tea(io, field.name)
    )
end

function _write_tea(io::IO, name_value::NameValue)::Int
    return (
        _write_tea(io, name_value.name)
        + write(io, kind(name_value))
        + _write_tea(io, name_value.value)
    )
end

function _write_tea(io::IO, section::ItemSection)::Int
    return (
        write(io, section.item_size)
        + _write_tea(io, section.item_name)
        + _write_tea(io, section.fields)
    )
end

function _write_tea(io::IO, section::TimeSection)::Int
    return (
        write(io, section.epoch)
        + write(io, section.ticks_per_day)
        + _write_tea(io, section.time_field_offsets)
    )
end

_write_tea(io::IO, section::ContentDescriptionSection) = _write_tea(io, section.description)
_write_tea(io::IO, section::NameValueSection) = _write_tea(io, section.name_values)
