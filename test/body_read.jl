using TeaFiles.Body: seek_to_time

@testset "read" begin
    @testset "seek to time" begin
        buf = IOBuffer()
        written_bytes = write(buf, 1, 2, 3, 4, 5)
        @test written_bytes == position(buf)
        @test position(buf) == 5 * sizeof(Int64)
        seekstart(buf)

        seek_to_time(buf, 0, 5 * sizeof(Int64), Int32(sizeof(Int64)), Int32(0), 3)
        @test position(buf) == 2 * sizeof(Int64)
        # TODO more tests required!
    end
end
