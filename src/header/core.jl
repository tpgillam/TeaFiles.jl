using AutoHashEquals: @auto_hash_equals
using Bijections: Bijection, inverse
using DataStructures: DefaultDict
using Dates

# This is the identifier with which every tea file must start. It is used to ensure that
# the file is a valid tea-file, and also that the endianness matches.
const MAGIC_VALUE = Int64(0x0d0e0a0402080500)

abstract type AbstractSection end

@auto_hash_equals struct TeaFileMetadata
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
    epoch::Int64  # Number of days from 0001-01-01 to the origin.
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

section_id(::T) where {T <: AbstractSection} = _SECTION_TYPE_TO_ID[T]
function section_type(id::Int32)::(Type{T} where {T <: AbstractSection})
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

"""Division that will throw if `y` does not fit into `x` an integer number of times."""
function _duration_div(x::Dates.FixedPeriod, y::T) where {T <: Dates.FixedPeriod}
    value, remainder = divrem(convert(T, x).value, y.value)
    if remainder != 0
        throw(ArgumentError("$y % $x != 0, division not defined."))
    end
    return value
end

"""
Return true iff the specified `Item` has a compatible memory layout with that specified
in `item_section`.

Note that we *do not* inspect field names, just types and offsets.

For fields that are of Julia `DateTime` type, we verify that this corresponds to
    * an Int64 field
    * a field marked as a "time" field
    * that the epoch & ticks_per_day match that used in the Julia `DateTime` type.
"""
function is_item_compatible(Item::Type, metadata::TeaFileMetadata)::Bool
    if !isbitstype(Item)
        # Only types with a well defined layout in memory can be compatible.
        return false
    end

    item_section::ItemSection = get_section(metadata, ItemSection)

    if sizeof(Item) != item_section.item_size
        return false
    end

    if fieldcount(Item) != length(item_section.fields)
        return false
    end

    have_done_time_checks = false
    for i in 1:fieldcount(Item)
        field = item_section.fields[i]
        if fieldtype(Item, i) == DateTime
            # DateTime fields are special, and require more extensive checks to be made
            # (see the docstring).
            if field_type(field) != Int64
                return false
            end

            if !have_done_time_checks
                # We now check the epoch and ticks-per-day for compatibility with Julia
                # date times. Since this is not field-specific, we ensure that we only do
                # this check once.
                time_section::TimeSection = get_section(metadata, TimeSection)
                julia_epoch_utc = DateTime(0, 1, 1) - Millisecond(Dates.DATETIMEEPOCH)
                julia_epoch = Day(julia_epoch_utc - DateTime(1, 1, 1)).value
                if time_section.epoch != julia_epoch
                    @debug "Epoch wrong: expected $julia_epoch, got $(time_section.epoch)"
                    return false
                end

                millisecond_per_day = _duration_div(Day(1), Millisecond(1))
                if time_section.ticks_per_day != millisecond_per_day
                    return false
                end
                have_done_time_checks = true
            end

        elseif field_type(field) != fieldtype(Item, i)
            return false
        end

        if field.offset != fieldoffset(Item, i)
            return false
        end
    end

    return true
end

"""
The minimum item_start compatible with the given `metadata`.
"""
function minimum_item_start(sections::Vector{AbstractSection})::Int64
    # We need to determine item_start. We do so automatically by calculating the size of
    # the metadata on disk, and then rounding up to a multiple of 8 bytes.
    # Remeber that each section additionally has fields denoting the section type and the
    # offset of the next section.
    metadata_size = (
        sizeof(Int64) * 4  # Top-level metadata
        + length(sections) * 2 * sizeof(Int32)  # Section metadata
        + (isempty(sections) ? 0 : sum(_tea_size, sections))  # Section payloads
    )
    return round(Int, metadata_size / 8, RoundUp) * 8
end

"""Throw if `metadata` is invalid."""
function verify_metadata(metadata::TeaFileMetadata)::Nothing
    if metadata.item_start % 8 != 0
        throw(ArgumentError(
            "Invalid item_start: $(metadata.item_start) is not a multiple of 8."
        ))
    end

    # Verify that item_start is large enough to be after the whole metadata section.
    min_item_start = minimum_item_start(metadata.sections)
    if metadata.item_start < min_item_start
        throw(ArgumentError(
            "item_start is too small: $(metadata.item_start) < $min_item_start, "
        ))
    end

    if metadata.item_end != 0 && metadata.item_end < metadata.item_start
        throw(ArgumentError(
            "Invalid item_end: $(metadata.item_end) is before item_start."
        ))
    end

    # We should have at most one section of any type.
    type_to_section = Dict{Type, AbstractSection}()
    type_to_count = DefaultDict{Type, Int}(0)
    for section in metadata.sections
        type_to_count[typeof(section)] += 1
        type_to_section[typeof(section)] = section
    end
    for (type, count) in type_to_count
        if count > 1
            throw(ArgumentError(
                "Found $count sections of type $type -- there should be at most one."
            ))
        end
    end

    # At this point we could have zero or one time section.
    if haskey(type_to_section, TimeSection)
        # If the time section is present, we will do some tests
        time_section::TimeSection = type_to_section[TimeSection]

        # We *must* have an item section if we have a time section.
        if !haskey(type_to_section, ItemSection)
            throw(ArgumentError("There is a TimeSection, but no ItemSection."))
        end
        item_section = type_to_section[ItemSection]

        unclaimed_field_offsets = Set((field.offset for field in item_section.fields))
        # Verify that time field offsets match up to known fields, and that each field is
        # referred to exactly once.
        for time_field_offset in time_section.time_field_offsets
            if !(time_field_offset in unclaimed_field_offsets)
                throw(ArgumentError(
                    "Time field offset $time_field_offset does not match to a field."
                ))
            end

            # We have claimed this field.
            delete!(unclaimed_field_offsets, time_field_offset)
        end
    end

    if haskey(type_to_section, ItemSection)
        item_section::ItemSection = type_to_section[ItemSection]

        offsets = [field.offset for field in item_section.fields]
        # `item_size` takes us to the start of the next item.
        push!(offsets, item_section.item_size)
        actual_field_sizes = diff(offsets)

        minimum_field_sizes = [sizeof(field_type(field)) for field in item_section.fields]

        for (i, (actual, minimum)) in enumerate(
                zip(actual_field_sizes, minimum_field_sizes))
            # This verifies that all item offsets are strictly increasing, and each field
            # has at least enough space on disk to store the type.
            if actual < minimum
                throw(ArgumentError(
                    "offsets imply field $i has size $actual, "
                    * "but it should be at least $minimum"
                ))
            end
        end
    end

    return nothing
end
