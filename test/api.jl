using TeaFiles

function _test_api(data::Vector{T}; metadata_kwargs...) where T
    # Temporary file to use for experiments. We have to use a file to test memory mapping,
    # since this can't be used with a buffer.
    path = tempname()

    # TODO Switch to official writing API when available.
    # TODO Also test writing items with different field offsets.
    metadata = create_metadata_julia_time(T; metadata_kwargs...)

    # Write the data to a file, as well as an in-memory buffer.
    open(path; write=true) do io
        # Create the file and write the header and data to it.
        write(io, metadata)
        write(io, data)
    end

    buffer = IOBuffer()
    write(buffer, metadata)
    write(buffer, data)
    seekstart(buffer)

    result_file = TeaFiles.read(path)
    result_buffer = TeaFiles.read(buffer)

    namedtuple_data = _structs_to_namedtuples(data)
    @test result_file == namedtuple_data
    @test result_buffer == namedtuple_data

    # Necessary to remove any remnants of the memory mapping on windows, at least. Otherwise
    # we can find that the file remains open.
    GC.gc()
    GC.gc()
end

@testset "simple" begin
    struct Item
        time::Int64
        a::Int32
        b::Float64
    end

    some_data = [
        Item(1000 + i, i, 2 * i)
        for i in 1:100
    ]
    _test_api(some_data)
end

@testset "simple datetime" begin
    some_data = [
        DateTimeTick(DateTime(2000, 1, 1) + Day(i), 2 * i, 3 * i)
        for i in 1:100
    ]
    _test_api(some_data)
end
