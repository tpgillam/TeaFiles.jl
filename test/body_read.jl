using TeaFiles.Body: seek_to_time

@testset "read" begin
    @testset "seek to time" begin
        @testset "simple" begin
            buf = IOBuffer()
            written_bytes = write(buf, 1, 2, 3, 4, 5)
            @test written_bytes == position(buf)
            @test position(buf) == 5 * sizeof(Int64)
            seekstart(buf)

            seek_to_time(buf, 0, 5 * sizeof(Int64), Int32(sizeof(Int64)), Int32(0), 3)
            @test position(buf) == 2 * sizeof(Int64)
        end

        @testset "padded item" begin
            # Use a structure with some less trivial padding...
            struct Moo
                a::UInt8
                time::Int64
            end
            item_size = Int32(sizeof(Moo))
            @test item_size == 16  # Expecting :a to be padded
            time_field_offset = Int32(fieldoffset(Moo, 2))
            @test time_field_offset == 8

            buf = IOBuffer()
            written_bytes = write(
                buf, [Moo('a', 10), Moo('a', 10), Moo('b', 20), Moo('c', 30), Moo('d', 40)]
            )
            @test written_bytes == position(buf)
            @test written_bytes == 5 * sizeof(Moo)

            function test_seek(time::Int64, expected_index::Int)
                seek_to_time(
                    buf, 0, written_bytes, item_size, time_field_offset, time
                )
                expected_position = (expected_index - 1) * item_size
                @test position(buf) == expected_position
            end

            test_seek(0, 1)  # This time is before any data that we have
            test_seek(10, 1)
            test_seek(20, 3)
            test_seek(30, 4)
            test_seek(40, 5)
            test_seek(50, 6)  # End-of-file at this point
            test_seek(60, 6)
        end
    end
end