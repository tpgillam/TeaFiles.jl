using TeaFiles

function _test_api(
    data::Vector{T},
    lower::Union{Nothing, TeaFiles.TimeLike},
    upper::Union{Nothing, TeaFiles.TimeLike}
) where T
    # Temporary file to use for experiments. We have to use a file to test memory mapping,
    # since this can't be used with a buffer.
    path = tempname()

    # TODO Also test writing items with different field offsets.
    # Write the data to a file by hand.
    metadata = create_metadata_julia_time(T)
    open(path; write=true) do io
        # Create the file and write the header and data to it.
        write(io, metadata)
        write(io, data)
    end

    # Write to a file with the table API
    path_table_api = tempname()
    table = _structs_to_namedtuples(data)
    TeaFiles.write(path_table_api, table)

    # Write to a buffer.
    buffer = IOBuffer()
    write(buffer, metadata)
    write(buffer, data)
    seekstart(buffer)

    result_file = TeaFiles.read(path; lower=lower, upper=upper)
    result_file_table_api = TeaFiles.read(path_table_api; lower=lower, upper=upper)
    result_buffer = TeaFiles.read(buffer; lower=lower, upper=upper)

    # Filter data by time field.
    expected_read_data = data
    i_time_field = nothing
    for i in 1:fieldcount(eltype(data))
        if fieldtype(eltype(data), i) == DateTime
            i_time_field = i
            break
        end
    end
    if !isnothing(lower)
        expected_read_data = [
            x for x in expected_read_data if getfield(x, i_time_field) >= lower
        ]
    end
    if !isnothing(upper)
        expected_read_data = [
            x for x in expected_read_data if getfield(x, i_time_field) < upper
        ]
    end

    namedtuple_data = _structs_to_namedtuples(expected_read_data)
    @test result_file == namedtuple_data
    @test result_file_table_api == namedtuple_data
    @test result_buffer == namedtuple_data

    # Necessary to remove any remnants of the memory mapping on windows, at least. Otherwise
    # we can find that the file remains open.
    GC.gc()
    GC.gc()
end

@testset "simple" begin
    some_data = [Tick(1000 + i, i, 2 * i) for i in 1:100]
    _test_api(some_data, nothing, nothing)
end

@testset "simple datetime" begin
    some_data = [
        DateTimeTick(DateTime(2000, 1, 1) + Day(i), 2 * i, 3 * i)
        for i in 1:100
    ]
    _test_api(some_data, nothing, nothing)
    _test_api(some_data, DateTime(1990, 1, 1), nothing)
    _test_api(some_data, DateTime(2000, 1, 1), nothing)
    _test_api(some_data, DateTime(2000, 3, 1), nothing)
    _test_api(some_data, DateTime(2000, 3, 1), DateTime(2100, 1, 1))
    _test_api(some_data, DateTime(2000, 3, 1), DateTime(2000, 4, 1))
end
