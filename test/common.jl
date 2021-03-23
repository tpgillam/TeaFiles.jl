using TeaFiles
using TeaFiles.Header: ContentDescriptionSection, Field, ItemSection, NameValue,
    NameValueSection, TeaFileMetadata, TimeSection, field_type, field_type_id

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
            _make_fields(["Time" => Int64, "Price" => Float64, "Volume" => Int64])
        ),
        ContentDescriptionSection("ACME prices"),
        NameValueSection([NameValue("decimals", Int32(2))]),
        TimeSection(719162, 86400000, [0])
    ])
end
