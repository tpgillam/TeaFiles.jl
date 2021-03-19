using AutoHashEquals
using Bijections

# This is the identifier with which every tea file must start. It is used to ensure that
# the file is a valid tea-file, and also that the endianness matches.
const MAGIC_VALUE = Int64(0x0d0e0a0402080500)

abstract type AbstractSection end

# FIXME for construction method, we should
#   - add bounds checking to item_start & item_end
#   - fail if item_start isn't on an 8-byte boundary
#   - fail if the size of all sections would end up going past item_start
#   - ensure that fields marked as being times are integers?
struct TeaFileMetadata
    item_start::Int64  # Byte-index of the start of the item area.
    item_end::Int64  # Byte-index for the end of the item area, or 0 for EOF.
    sections::Vector{AbstractSection}
end

const _FIELD_DATA_TYPE_TO_ID = Bijection(Dict{DataType,Int32}(
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
    # User-defined types must have identifiers at or above 0x1000
))

field_type_id(T::Type) = _FIELD_DATA_TYPE_TO_ID[T]

struct Field
    type_id::Int32
    offset::Int32  # Byte offset inside the item
    name::String
end

field_type(field::Field) = inverse(_FIELD_DATA_TYPE_TO_ID, field.type_id)

struct NameValue{T <: Union{Int32,Float64,String,Base.UUID}}
    name::String
    value::T
end

const _NAME_VALUE_TYPE_TO_KIND = Bijection(Dict{DataType, Int32}(
    Int32 => 1,
    Float64 => 2,
    String => 3,
    Base.UUID => 4,
))

kind(::NameValue{T}) where T = _NAME_VALUE_TYPE_TO_KIND[T]
name_value_type(kind::Int32) = inverse(_NAME_VALUE_TYPE_TO_KIND, kind)

@auto_hash_equals struct ItemSection <: AbstractSection
    item_size::Int32  # Size of each item in bytes.
    item_name::String
    fields::Vector{Field}
end

@auto_hash_equals struct TimeSection <: AbstractSection
    epoch::Int64  # Number of days from 0000-01-01 to the origin. 719162 for 1970
    ticks_per_day::Int64
    time_field_offsets::Vector{Int32}
end

struct ContentDescriptionSection <: AbstractSection
    description::String
end

@auto_hash_equals struct NameValueSection <: AbstractSection
    name_values::Vector{NameValue}
end

const _SECTION_TYPE_TO_ID = Bijection(Dict{DataType, Int32}(
    ItemSection => 0x0a,
    TimeSection => 0x40,
    ContentDescriptionSection => 0x80,
    NameValueSection => 0x81,
))

section_id(::T) where T <: AbstractSection = _SECTION_TYPE_TO_ID[T]
section_type(id::Int32)::T where T <: AbstractSection = inverse(_SECTION_TYPE_TO_ID, id)