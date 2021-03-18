using TeaFiles.Header: Field, _size_on_disk

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
end
