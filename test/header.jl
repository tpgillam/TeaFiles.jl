using UUIDs

using TeaFiles.Header: AbstractSection, ContentSection, Field, ItemSection, NameValue,
    NameValueSection, TimeSection, _tea_size, _write_tea, make_fields, section_id

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
    written_bytes = write(out, name_value)
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
    written_bytes = write(out, section)
    @test written_bytes == out.size
    @test written_bytes == 4 + 4 + _tea_size(section)

    @test out.data[1:written_bytes] == vcat(
        to_tea_byte_array(section_id(section)),
        to_tea_byte_array(_tea_size(section)),
        to_tea_byte_array(section)
    )
end

@testset "Header" begin
    @testset "write_field" begin
        field = Field(1, 2, "hi!")
        out = IOBuffer()
        written_bytes = write(out, field)
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
        _test_section(ItemSection("Plop", make_fields([Float64, Float64, Int32])))
        _test_section(ItemSection(
            "Mooo",
            make_fields(["a" => Float64, "b" => Float64, "c" => Int32])
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
end
