using AutoHashEquals: @auto_hash_equals
using Bijections: Bijection, inverse
using DataStructures: DefaultDict

# This is the identifier with which every tea file must start. It is used to ensure that
# the file is a valid tea-file, and also that the endianness matches.
const MAGIC_VALUE = Int64(0x0d0e0a0402080500)

abstract type AbstractSection end

@auto_hash_equals struct TeaFileMetadata
    item_start::Int64  # Byte-index of the start of the item area.
    item_end::Int64  # Byte-index for the end of the item area, or 0 for EOF.
    sections::Vector{AbstractSection}
end

"""Throw if `metadata` is invalid."""
function verify_metadata(metadata::TeaFileMetadata)::Nothing
    if metadata.item_start % 8 != 0
        throw(ArgumentError(
            "Invalid item_start: $(metadata.item_start) is not a multiple of 8."
        ))
    end

    if metadata.item_end != 0 && metadata.item_end < metadata.item_start
        throw(ArgumentError(
            "Invalid item_end: $(metadata.item_end) is before item_start."
        ))
    end

    # We should have at most one section of any type.
    type_to_count = DefaultDict{Type, Int}(0)
    for section in metadata.sections
        type_to_count[typeof(section)] += 1
    end
    for (type, count) in type_to_count
        if count > 1
            throw(ArgumentError(
                "Found $count sections of type $type -- there should be at most one."
            ))
        end
    end

    # TODO Verify that time field offsets match up to known fields.

    return nothing
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
function section_type(id::Int32)::(Type{T} where T <: AbstractSection)
    return inverse(_SECTION_TYPE_TO_ID, id)
end

"""Get a section of the specified type."""
function get_section(metadata::TeaFileMetadata, type::Type)
    return only(filter(section -> isa(section, type), metadata.sections))
end

"""
Get all Field instances which are marked as representing times in the metadata.
"""
function get_time_fields(metadata::TeaFileMetadata)::Vector{Field}
    # There should never be more than one time section, and this will throw if there is not
    # a time section. Same for the item section.
    time_section = get_section(metadata, TimeSection)
    item_section = get_section(metadata, ItemSection)

    result = Field[]
    field, iter_field_state = iterate(item_section.fields)
    for time_field_offset in time_section.time_field_offsets
        while time_field_offset > field.offset
            field, field_state = iterate(item_section.fields, iter_field_state)
        end
        if field.offset != time_field_offset
            throw(ArgumentError("Inconsistent metadata; could not find time field."))
        end

        push!(result, field)
    end

    return result
end

"""Get the time field which is the primary index for the tea file."""
get_primary_time_field(metadata::TeaFileMetadata) = first(get_time_fields(metadata))
