using UUIDs

using TeaFiles.Header: AbstractSection, ContentDescriptionSection, Field,
    ItemSection, NameValue, NameValueSection, TeaFileMetadata, TimeSection,
    MAGIC_VALUE, _tea_size, _write_section, _write_tea, section_id

to_tea_byte_array(x::Real) = reinterpret(UInt8, [x])

function to_tea_byte_array(x)::Vector{UInt8}
    out = IOBuffer()
    _write_tea(out, x)
    return out.data[1:out.size]
end

function _test_name_value(
    name::AbstractString,
    value::Union{Int32,Float64,AbstractString,Base.UUID}
)
    name_value = NameValue(name, value)
    out = IOBuffer()
    written_bytes = _write_tea(out, name_value)
    @test written_bytes == out.size
    @test written_bytes == ((4 + 3) + 4 + _tea_size(value))

    kind = if isa(value, Int32)
        Int32(1)
    elseif isa(value, Float64)
        Int32(2)
    elseif isa(value, AbstractString)
        Int32(3)
    elseif isa(value, Base.UUID)
        Int32(4)
    end

    @test out.data[1:written_bytes] == vcat(
        to_tea_byte_array(name),
        to_tea_byte_array(kind),
        to_tea_byte_array(value)
    )
end

function _test_section(section::AbstractSection)
    out = IOBuffer()
    written_bytes = _write_section(out, section)
    @test written_bytes == out.size
    @test written_bytes == 4 + 4 + _tea_size(section)

    @test out.data[1:written_bytes] == vcat(
        to_tea_byte_array(section_id(section)),
        to_tea_byte_array(_tea_size(section)),
        to_tea_byte_array(section)
    )
end

function _test_metadata(metadata::TeaFileMetadata)
    out = IOBuffer()
    written_bytes = write(out, metadata)
    @test written_bytes == out.size
    @test written_bytes == metadata.item_start

    # Work out the byte array for all sections present.
    sections_bytes = vcat(
        map(
            section -> vcat(
                to_tea_byte_array(section_id(section)),
                to_tea_byte_array(_tea_size(section)),
                to_tea_byte_array(section)
            ),
            metadata.sections
        )...
    )

    # Work out the amount of padding that should have been added.
    unpadded_length = (
        8 + 8 + 8 + 8 +
        if isempty(metadata.sections)
            0
        else
            sum(
                section -> (4 + 4 + _tea_size(section)),
                metadata.sections
            )
        end
    )
    padding_bytes = repeat([0x00], metadata.item_start - unpadded_length)

    @test out.data[1:written_bytes] == vcat(
        to_tea_byte_array(MAGIC_VALUE),
        to_tea_byte_array(metadata.item_start),
        to_tea_byte_array(metadata.item_end),
        to_tea_byte_array(length(metadata.sections)),
        sections_bytes,
        padding_bytes
    )
end

@testset "write" begin
    @testset "write_field" begin
        field = Field(1, 2, "hi!")
        out = IOBuffer()
        written_bytes = _write_tea(out, field)
        @test written_bytes == out.size
        @test written_bytes == (4 + 4 + (4 + 3))

        @test out.data[1:written_bytes] == UInt8[
            1, 0, 0, 0,  # 1::Int32
            2, 0, 0, 0,  # 2::Int32
            3, 0, 0, 0,  # 3::Int32
            0x68,  # "h"
            0x69,  # "i"
            0x21,  # "!"
            ]
    end

    @testset "write_name_value" begin
        @testset "int32" begin _test_name_value("moo", Int32(32)) end
        @testset "float64" begin _test_name_value("moo", 42.0) end
        @testset "string" begin _test_name_value("moo", "lowing") end
        @testset "uuid" begin _test_name_value("moo", UUIDs.uuid1()) end
    end

    @testset "write_item_section" begin
        _test_section(ItemSection("", Field[]))
        _test_section(ItemSection("Plop", _make_fields([Float64, Float64, Int32])))
        _test_section(ItemSection(
            "Mooo",
            _make_fields(["a" => Float64, "b" => Float64, "c" => Int32])
        ))
    end

    @testset "write_time_section" begin
        _test_section(TimeSection(0, 0, Int32[]))
        _test_section(TimeSection(
            719162,  # 1970-01-01
            86400,  # Seconds
            Int32[0]  # First field
        ))
    end

    @testset "write_content_description_section" begin
        _test_section(ContentDescriptionSection(""))
        _test_section(ContentDescriptionSection("Some non-empty description"))
    end

    @testset "write_name_value_section" begin
        _test_section(NameValueSection([]))
        _test_section(NameValueSection([NameValue("a", Int32(1))]))
        _test_section(NameValueSection([
            NameValue("a", Int32(1)),
            NameValue("b", Float64(42.0)),
            NameValue("c", "coo"),
            NameValue("d", UUIDs.uuid1()),
        ]))
    end

    @testset "write_tea_file_metadata" begin
        _test_metadata(TeaFileMetadata(200, 0, []))

        # This is the example in the specification.
        example_metadata = _get_example_metadata()
        _test_metadata(example_metadata)

        # We should pad up to the item_start
        @test write(IOBuffer(), example_metadata) == 200
        @test write(IOBuffer(), TeaFileMetadata(1000, 0, [])) == 1000
    end
end
