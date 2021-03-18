module TeaFiles

module Header

using Bijections

# TODO decide what we actually need to export
export TeaFileMetadata, Field, ItemSection, TimeSection, ContentSection
export NameValue, NameValueSection
export kind, section_id

# This is the identifier with which every tea file must start.
const MAGIC_VALUE = UInt8[0x0d, 0x0e, 0x0a, 0x04, 0x02, 0x08, 0x05, 0x00]

abstract type AbstractSection end

struct TeaFileMetadata
    item_start::Int64  # Byte-index of the start of the item area.
    item_end::Int64  # Byte-index for the end of the item area, or 0 for EOF.
    sections::Vector{AbstractSection}
end

const FIELD_DATA_TYPE_TO_ID = Bijection(Dict{DataType,Int32}(
    Int8 => 1,
    Int16 => 2,
    Int32 => 3,
    Int64 => 4,
    UInt8 => 5,
    UInt16 => 6,
    UInt32 => 7,
    UInt64 => 8,
    Float32 => 9,
    Float64 => 10,
    # TODO support for Decimal, 0x200?
))

struct Field
    type_id::Int32
    offset::Int32  # Byte offset inside the item
    name::String
end

field_type(field::Field) = inverse(FIELD_DATA_TYPE_TO_ID, field.type_id)

function make_fields(name_types::Vector{Pair{String,DataType}})::Vector{Field}
    offset = Int32(0)
    result = Field[]
    for (name, type) in name_types
        type_id = FIELD_DATA_TYPE_TO_ID[type]
        push!(result, Field(type_id, offset, name))
        offset += sizeof(type)
    end
    return result
end
make_fields(types::Vector{DataType}) = make_fields(["" => type for type in types])

struct ItemSection <: AbstractSection
    item_size::Int32  # Size of each item in bytes.
    item_name::String
    fields::Vector{Field}
end

function ItemSection(item_name::AbstractString, fields::AbstractVector{Field})
    item_size = if isempty(fields) 0 else
        sum(fields) do field
            sizeof(field_type(field))
        end
    end
    return ItemSection(item_size, item_name, fields)
end


struct TimeSection <: AbstractSection

    ticks_per_day::Int64
    time_field_offsets::Vector{Int32}
end

struct ContentSection <: AbstractSection
    description::String
end

struct NameValue{T <: Union{Int32,Float64,String,Base.UUID}}
    name::String
    value::T
end

kind(::NameValue{T}) where T = kind(T)
kind(::Type{Int32})::Int32 = 1
kind(::Type{Float64})::Int32 = 2
kind(::Type{String})::Int32 = 3
kind(::Type{Base.UUID})::Int32 = 4

struct NameValueSection <: AbstractSection
    name_values::Vector{NameValue}
end

section_id(::T) where T <: AbstractSection = section_id(T)
section_id(::Type{ItemSection})::Int32 = 0x0a
section_id(::Type{TimeSection})::Int32 = 0x40
section_id(::Type{ContentSection})::Int32 = 0x80
section_id(::Type{NameValueSection})::Int32 = 0x81


function Base.write(io::IO, metadata::TeaFileMetadata)::Int
    bytes_written = write(io, MAGIC_VALUE)
    bytes_written += write(io, item_start)
    bytes_written += write(io, item_end)
    bytes_written += write(io, Int64(length(metadata.sections)))  # section count
    for section in sections
        bytes_written += write(io, section)
    end
    return bytes_written
end

function Base.write(io::IO, section::AbstractSection)::Int
    return (
        write(io, section_id(section)) # section_id
        + write(io, _tea_size(section))  # next_section_offset
        + _write_tea(io, section)
    )
end

Base.write(io::IO, name_value::NameValue) = _write_tea(io, name_value)
Base.write(io::IO, field::Field) = _write_tea(io, field)

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

function _write_tea(io::IO, xs::Vector{T}) where T
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
    bytes_written = write(io, section.item_size)
    bytes_written += _write_tea(io, section.item_name)
    bytes_written += _write_tea(io, section.fields)
    return bytes_written
end

function _write_tea(io::IO, section::TimeSection)::Int
    return (
        write(io, section.epoch)
        + write(io, section.ticks_per_day)
        + write(io, Int32(length(section.time_field_offsets)))  # Time fields count
        + write(io, section.time_field_offsets)
    )
end

_write_tea(io::IO, section::ContentSection) = _write_tea(io, section.description)
_write_tea(io::IO, section::NameValueSection) = _write_tea(io, section.name_values)

end  # Header


"""
Create a new file, and write the necessary header information, then open it for appending.
"""
function create()::IOStream
end


function open_append()::IOStream
end

function open_read()::IOStream
end



end  # TeaFiles
