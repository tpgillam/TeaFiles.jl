using TeaFiles.Body: ItemIOBlock, _first_position_ge_time, read_columns, read_items

# TODO These tests could be refactored a bit

function _test_impl_simple(
    times::Vector{Int64},
    func::Function,
    time::Int64,
    expected_index::Int
)
    buf = IOBuffer()
    written_bytes = write(buf, times)
    @test written_bytes == position(buf)
    @test position(buf) == length(times) * sizeof(Int64)

    # The only field is the time.
    block = ItemIOBlock{Int64}(buf, 0, buf.size, sizeof(Int64), 0)

    pos = func(block, time)
    expected_position = (expected_index - 1) * sizeof(Int64)
    @test pos == expected_position
end

struct Moo
    a::UInt8
    time::Int64
end

function _test_impl_padded(
    times::Vector{Int64},
    func::Function,
    time::Int64,
    expected_index::Int
)
    item_size = Int32(sizeof(Moo))
    @test item_size == 16  # Expecting :a to be padded
    time_field_offset = Int32(fieldoffset(Moo, 2))
    @test time_field_offset == 8

    items = [Moo('a', time) for time in times]

    buf = IOBuffer()
    written_bytes = write(buf, items)
    @test written_bytes == position(buf)
    @test position(buf) == length(times) * sizeof(Moo)

    # Use the field offset
    block = ItemIOBlock{Int64}(buf, 0, buf.size, sizeof(Moo), time_field_offset)

    pos = func(block, time)
    expected_position = (expected_index - 1) * sizeof(Moo)
    @test pos == expected_position
end

"""
Test block search with the example metadata.
"""
function _test_impl_example(
    times::Vector{Int64},
    func::Function,
    time::Int64,
    expected_index::Int
)
    metadata = _get_example_metadata()

    buf = IOBuffer()
    metadata_size = write(buf, metadata)
    items = [Tick(time, 10.0, 1) for time in times]
    written_bytes = write(buf, items)
    @test written_bytes == length(times) * sizeof(Tick)

    # The time field offset should be zero
    @test fieldoffset(Tick, 1) == 0

    # item_start is the same as metadata_size.
    block = ItemIOBlock{Int64}(buf, metadata_size, buf.size, sizeof(Tick), 0)

    pos = func(block, time)
    expected_position = metadata_size + (expected_index - 1) * sizeof(Tick)
    @test pos == expected_position
end

function _test_block_search(
    times::Vector{Int64},
    func::Function,
    time::Int64,
    expected_index::Int
)
    @testset "simple" begin _test_impl_simple(times, func, time, expected_index) end
    @testset "padded" begin _test_impl_padded(times, func, time, expected_index) end
    @testset "example" begin _test_impl_example(times, func, time, expected_index) end
end

@testset "read" begin
    @testset "_first_position_ge_time" begin
        @testset "empty" begin
            function _test(time, expected_index)
                times = Int64[]
                return _test_block_search(
                    times, _first_position_ge_time, time, expected_index
                )
            end
            # Regardless of the time we search for, we should find the start of the
            # item block.
            _test(0, 1)
            _test(1, 1)
            _test(2, 1)
        end

        @testset "nonempty" begin
            function _test(time, expected_index)
                times = [10, 10, 20, 30, 50, 50]
                return _test_block_search(
                    times, _first_position_ge_time, time, expected_index
                )
            end
            _test(0, 1)  # This time is before any data we have
            _test(10, 1)
            _test(20, 3)
            _test(30, 4)
            _test(40, 5)
            _test(50, 5)
            _test(60, 7)  # Strictly after all times, so point to end of block
            _test(70, 7)
        end
    end

    @testset "read_items" begin
        # Write the example to the buffer.
        metadata = _get_example_metadata()

        expected_times = [10, 20, 30, 40, 50]
        expected_prices = [12.0, 22.0, 32.0, 42.0, 52.0]
        expected_volumes = [1, 2, 3, 4, 5]

        expected_items = [
            Tick(time, price, volume)
            for (time, price, volume) in zip(
                expected_times, expected_prices, expected_volumes
            )
        ]

        buf = IOBuffer()
        write(buf, metadata)
        write(buf, expected_items)

        @test read_items(Tick, buf, metadata) == expected_items
        @test read_items(Tick, buf, metadata; lower=20) == expected_items[2:end]
        @test read_items(Tick, buf, metadata; lower=40) == expected_items[4:end]
        @test read_items(Tick, buf, metadata; lower=10, upper=40) == expected_items[1:3]
        @test read_items(Tick, buf, metadata; lower=40, upper=41) == expected_items[4:4]
        @test read_items(Tick, buf, metadata; lower=41, upper=42) == Tick[]

        # Verify that an incompatible item type results in an error.
        struct IncompatibleTick
            time::Int64
            price::Float32  # In `Tick`, this is a Float64
            volume::Int64
        end
        @test_throws ArgumentError read_items(IncompatibleTick, buf, metadata)
    end

    @testset "read_columns" begin
        # Write the example to the buffer.
        metadata = _get_example_metadata()

        expected_times = [10, 20, 30, 40, 50]
        expected_prices = [12.0, 22.0, 32.0, 42.0, 52.0]
        expected_volumes = [1, 2, 3, 4, 5]

        expected_items = [
            Tick(time, price, volume)
            for (time, price, volume) in zip(
                expected_times, expected_prices, expected_volumes
            )
        ]

        buf = IOBuffer()
        write(buf, metadata)
        write(buf, expected_items)

        times, prices, volumes = read_columns(buf, metadata)
        @test times == expected_times
        @test prices == expected_prices
        @test volumes == expected_volumes

        @test only(read_columns(buf, metadata; columns=[1])) == expected_times
        @test only(read_columns(buf, metadata; columns=[2])) == expected_prices
        @test only(read_columns(buf, metadata; columns=[3])) == expected_volumes

        @test (
            read_columns(buf, metadata; columns=[1, 2])
            == [expected_times, expected_prices]
        )
        @test (
            read_columns(buf, metadata; columns=[1, 3])
            == [expected_times, expected_volumes]
        )
        @test (
            read_columns(buf, metadata; columns=[2, 3])
            == [expected_prices, expected_volumes]
        )
    end
end
