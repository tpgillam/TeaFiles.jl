using Dates
using Mmap

using TeaFiles

function _read_all_items_mmap(
    ::Type{T},
    io::IOStream,
    metadata::TeaFileMetadata
)::Vector{T} where T
    # Memory map the file from the start of the item section
    seek(io, metadata.item_start)
    map = Mmap.mmap(io)

    num_items = get_num_items(sizeof(map), metadata)

    # Output buffer for the items that we're going to read.
    item_vector = Vector{T}(undef, num_items)

    # NOTE - one can gain some performance by using unsafe_copyto!
    item_vector .= reinterpret(T, map)
    return item_vector
end

function _read_all_items_syscall(
    ::Type{T},
    io::IOStream,
    metadata::TeaFileMetadata
)::Vector{T} where T
    seek(io, metadata.item_start)
    num_items = get_num_items(io, metadata)
    # In practice one may want to define "read" for type T
    item_vector = Vector{T}(undef, num_items)
    unsafe_read(io, Ref(item_vector, 1), sizeof(T) * num_items)
    return item_vector
end

function _test_write_read(data::Vector{T}; metadata_kwargs...) where T
    # Temporary file to use for experiments. We have to use a file to test memory mapping,
    # since this can't be used with a buffer.
    path = tempname()

    metadata = create_metadata(T; metadata_kwargs...)

    open(path; write=true) do io
        # Create the file and write the header and data to it.
        write(io, metadata)
        write(io, data)
    end

    result_mmap, result_syscall = open(path; read=true) do io
        # Read the file.
        read_metadata = read(io, TeaFileMetadata)
        @test read_metadata == metadata

        result_mmap = _read_all_items_mmap(Item, io, metadata)
        result_syscall = _read_all_items_syscall(Item, io, metadata)
        return result_mmap, result_syscall
    end

    @test result_mmap == data
    @test result_syscall == data

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
    _test_write_read(some_data)
    _test_write_read(some_data; time_fields=[:time])
end
