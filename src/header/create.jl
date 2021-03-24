using Dates: DateTime, Day, Millisecond, TimePeriod

"""Anything which is well-defined as a fixed amount of time."""
const Duration = Union{TimePeriod, Day}

"""Division that will throw if `y` does not fit into `x` an integer number of times."""
function _duration_div(x::Duration, y::T) where {T <: Duration}
    value, remainder = divrem(convert(T, x).value, y.value)
    if remainder != 0
        throw(ArgumentError("$y % $x != 0, division not defined."))
    end
    return value
end

"""
Create metadata given an item type, and other optional information.

# Arguments
- `item_type::Type`: A type for each item that will be stored. Must be a bits type.

# Keywords
- `time_fields::AbstractVector{Symbol}`: Fields in `item_type` that represent times. The
    first such field will be the primary time field, and must be non-decreasing in the
    file.
- `content_description::AbstractString`: A description of the file.
- `name_values::AbstractVector{NameValue}`: Additional name-value pairs to include in the
    metadata.
- `epoch_utc::DateTime`: The epoch, in UTC. Defaults to midnight 1970-01-01.
- `tick_duration::Duration`: The length of one tick of the clock.
"""
function create_metadata(
    item_type::Type;
    time_fields::AbstractVector{Symbol}=Symbol[],
    content_description::AbstractString="",
    name_values::AbstractVector{NameValue}=NameValue[],
    epoch_utc::DateTime=DateTime(1970, 1, 1),
    tick_duration::Duration=Millisecond(1)
)::TeaFileMetadata
    if !isbitstype(item_type)
        throw(ArgumentError("$item_type is not a bits type."))
    end

    # Number of days since the epoch, as an Int64.
    epoch = Day(epoch_utc - DateTime(1, 1, 1)).value
    ticks_per_day = _duration_div(Day(1), tick_duration)

    fields = [
        Field(
            field_type_id(fieldtype(item_type, i)),
            fieldoffset(item_type, i),
            string(name)
        )
        for (i, name) in enumerate(fieldnames(item_type))
    ]

    time_field_offsets = [
        fieldoffset(item_type, i)
        for time_field in time_fields
        for (i, name) in enumerate(fieldnames(item_type)) if name == time_field
    ]

    sections = [
        ItemSection(sizeof(item_type), string(item_type.name.name), fields),
        ContentDescriptionSection(content_description),
        NameValueSection(name_values),
        TimeSection(epoch, ticks_per_day, time_field_offsets)
    ]

    # We need to determine item_start. We do so automatically by calculating the size of
    # the metadata on disk, and then rounding up to a multiple of 8 bytes.
    # Remeber that each section additionally has fields denoting the section type and the
    # offset of the next section.
    metadata_size = (
        sizeof(Int64) * 4  # Top-level metadata
        + length(sections) * 2 * sizeof(Int32)  # Section metadata
        + sum(_tea_size, sections)  # Section payloads
    )
    item_start = round(Int, metadata_size / 8, RoundUp) * 8

    return TeaFileMetadata(item_start, 0, sections)
end
