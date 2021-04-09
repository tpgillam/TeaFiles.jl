using Dates

function _create_metadata_impl(
    item_size::Int32,
    item_name::AbstractString,
    fields::AbstractVector{Field},
    time_field_offsets::AbstractVector{Int32},
    content_description::AbstractString,
    name_values::AbstractVector{NameValue},
    epoch_utc::DateTime,
    tick_duration::Dates.FixedPeriod
)::TeaFileMetadata
    # Number of days since the epoch, as an Int64.
    epoch = Day(epoch_utc - DateTime(1, 1, 1)).value
    ticks_per_day = _duration_div(Day(1), tick_duration)

    sections = [
        ItemSection(item_size, item_name, fields),
        ContentDescriptionSection(content_description),
        NameValueSection(name_values),
        TimeSection(epoch, ticks_per_day, time_field_offsets)
    ]

    item_start = minimum_item_start(sections)
    return TeaFileMetadata(item_start, 0, sections)
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
- `tick_duration::Dates.FixedPeriod`: The length of one tick of the clock.
"""
function create_metadata(
    item_type::Type;
    time_fields::AbstractVector{Symbol}=Symbol[],
    content_description::AbstractString="",
    name_values::AbstractVector{NameValue}=NameValue[],
    epoch_utc::DateTime=DateTime(1970, 1, 1),
    tick_duration::Dates.FixedPeriod=Millisecond(1)
)::TeaFileMetadata
    if !isbitstype(item_type)
        throw(ArgumentError("$item_type is not a bits type."))
    end

    fields = [
        Field(
            field_type_id(fieldtype(item_type, i)),
            fieldoffset(item_type, i),
            string(name)
        )
        for (i, name) in enumerate(fieldnames(item_type))
    ]

    time_field_offsets = Int32[
        fieldoffset(item_type, i)
        for time_field in time_fields
        for (i, name) in enumerate(fieldnames(item_type)) if name == time_field
    ]

    return _create_metadata_impl(
        Int32(sizeof(item_type)), string(item_type.name.name), fields, time_field_offsets,
        content_description, name_values, epoch_utc, tick_duration
    )
end

"""
Create metadata that derives whether or not a field represents a time from whether it is
a `DateTime`. Such a field will always be encoded as milliseconds since the Julia epoch,
as an Int64.
"""
function create_metadata_julia_time(
    item_type::Type;
    content_description::AbstractString="",
    name_values::AbstractVector{NameValue}=NameValue[]
)::TeaFileMetadata
    if !isbitstype(item_type)
        throw(ArgumentError("$item_type is not a bits type."))
    end

    # The epoch and tick duration for Julia `DateTime` objects.
    epoch_utc = DateTime(0) - Millisecond(Dates.DATETIMEEPOCH)
    tick_duration = Millisecond(1)

    # Any `DateTime` field should be registered as an Int64, and also as a time field.
    fields = Field[]
    time_field_offsets = Int32[]

    for i in 1:fieldcount(item_type)
        offset = fieldoffset(item_type, i)
        T = fieldtype(item_type, i)
        if T == DateTime
            T = Int64
            push!(time_field_offsets, offset)
        end
        push!(fields, Field(field_type_id(T), offset, string(fieldname(item_type, i))))
    end

    return _create_metadata_impl(
        Int32(sizeof(item_type)), string(item_type.name.name), fields, time_field_offsets,
        content_description, name_values, epoch_utc, tick_duration
    )
end
