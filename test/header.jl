using UUIDs

using TeaFiles.Header: Field, NameValue, _tea_size, _write_tea

to_tea_byte_array(x::Real) = reinterpret(UInt8, [x])

function to_tea_byte_array(x)::Vector{UInt8}
    out = IOBuffer()
    _write_tea(out, x)
    return out.data[1:out.size]
end

function _test_name_value(
    name::AbstractString,
    value::Union{Int32, Float64, AbstractString, Base.UUID}
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
            _test_name_value("moo", Int32(32))
        end

        @testset "float64" begin
            _test_name_value("moo", 42.0)
        end

        @testset "string" begin
            _test_name_value("moo", "lowing")
        end

        @testset "uuid" begin
            _test_name_value("moo", UUIDs.uuid1())
        end
    end
end
