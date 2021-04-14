using Dates
using Setfield

using TeaFiles
using TeaFiles.Header: AbstractSection, ContentDescriptionSection, Field, ItemSection,
    NameValue, NameValueSection, TeaFileMetadata, TimeSection, field_type, field_type_id,
    get_section, minimum_item_start

"""
Quick-and-dirty field construction. Note that this doesn't properly deal with field
offsets, which -- if reading a struct -- are likely to have e.g. 8 byte alignment.
For these tests that doesn't matter though.
"""
function _make_fields(name_types::Vector{Pair{String,DataType}})::Vector{Field}
    offset = Int32(0)
    result = Field[]
    for (name, type) in name_types
        type_id = field_type_id(type)
        push!(result, Field(type_id, offset, name))
        # BEWARE: this is only suitable for these tests. If mapping a structure then one
        # should use fieldoffset(T, i) to compute the offset of field i.
        offset += sizeof(type)
    end
    return result
end
_make_fields(types::Vector{DataType}) = _make_fields(["" => type for type in types])

"""
Quick-and-dirty ItemSection construction. If we are mapping a structure of type T, then we
should instead be making use of sizeof(T).
"""
function TeaFiles.Header.ItemSection(
    item_name::AbstractString,
    fields::AbstractVector{Field}
)
    # BEWARE: this is only suitable for these tests. If we are mapping a structure then the
    #   size on disk could be larger than this due to padding.
    item_size = if isempty(fields) 0 else
        sum(fields) do field
            sizeof(field_type(field))
        end
    end
    return ItemSection(item_size, item_name, fields)
end

"""
Get a metadata section for the example used in the specification.
"""
function _get_example_metadata()::TeaFileMetadata
    return TeaFileMetadata(200, 0, [
        ItemSection(
            "Tick",
            _make_fields(["time" => Int64, "price" => Float64, "volume" => Int64])
        ),
        ContentDescriptionSection("ACME prices"),
        NameValueSection([NameValue("decimals", Int32(2))]),
        TimeSection(719162, 86400000, [0])
    ])
end

"""This is the structure the metadata expects."""
struct Tick
    time::Int64
    price::Float64
    volume::Int64
end

struct DateTimeTick
    time::DateTime
    price::Float64
    volume::Int64
end

function _replace_section!(
    metadata::TeaFileMetadata,
    section::AbstractSection
)::TeaFileMetadata
    # Filter out the old section, and replace it with the new one.
    replace!(x -> isa(x, typeof(section)) ? section : x, metadata.sections)
    return metadata
end

"""
This is the same as the example metadata, but we replace the epoch in the time section
with one that is Julia-compatible.
"""
function _get_example_datetime_metadata()
    julia_epoch_utc = DateTime(0, 1, 1) - Millisecond(Dates.DATETIMEEPOCH)
    julia_epoch = Day(julia_epoch_utc - DateTime(1, 1, 1)).value

    metadata = _get_example_metadata()

    # Create a new time section instance with the epoch changed.
    time_section = @set get_section(metadata, TimeSection).epoch = julia_epoch

    # Change the name of the item in item section.
    item_section = @set get_section(metadata, ItemSection).item_name = "DateTimeTick"

    _replace_section!(metadata, time_section)
    _replace_section!(metadata, item_section)

    # We've changed the sections, so update the location of the item section.
    return @set metadata.item_start = minimum_item_start(metadata.sections)
end

"""
Convert a vector of some struct T to a vector of equivalent namedtuples.
"""
function _structs_to_namedtuples(x::AbstractVector{T}) where {T}
    out_type = NamedTuple{tuple(fieldnames(T)...), Tuple{fieldtypes(T)...}}
    # Not the fastest, but oh well.
    return reinterpret(out_type, x)
end
