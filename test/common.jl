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
