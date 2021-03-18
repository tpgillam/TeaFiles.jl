using TeaFiles.Header: Field, NameValue

to_byte_array(x) = reinterpret(UInt8, [x])

function _test_name_value(value::Union{Int32, Float64})
    name_value = NameValue("moo", value)
    out = IOBuffer()
    written_bytes = write(out, name_value)
    @test written_bytes == out.size
    @test written_bytes == ((4 + 3) + 4 + sizeof(value))

    kind = if isa(value, Int32)
        Int32(1)
    elseif isa(value, Float64)
        Int32(2)
    end

    @test out.data[1:written_bytes] == vcat(
        UInt8[
            3, 0, 0, 0,  # 3::Int32
            0x6d,  # m
            0x6f,  # o
            0x6f,  # o
        ],
        to_byte_array(kind),
        to_byte_array(value)
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
        @testset "int32" begin
            _test_name_value(Int32(32))
        end

        @testset "float64" begin
            _test_name_value(42.0)
        end

        @testset "string" begin
            # TODO
        end

        @testset "uuid" begin
            # TODO
        end
    end
end
