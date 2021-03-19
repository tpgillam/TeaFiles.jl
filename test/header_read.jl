using UUIDs

using TeaFiles.Header: ContentDescriptionSection, Field, ItemSection,
    NameValue, NameValueSection, TeaFileMetadata, TimeSection, MAGIC_VALUE,
    _read_tea, _write_tea, read_header

"""
Write the given value to a buffer, followed by some garbage, and check we read it back
correctly.
"""
function _test_rw_loop(value)
    buf = IOBuffer()
    _write_tea(buf, value)
    write(buf, 42)  # some garbage we should ignore
    seekstart(buf)
    @test _read_tea(buf, typeof(value)) == value
end

@testset "read" begin
    @testset "read_byte_swapped_magic" begin
        buf = IOBuffer()
        write(buf, bswap(MAGIC_VALUE))
        seekstart(buf)
        @test_throws ArgumentError read_header(buf)
    end

    @testset "read_incorrect_magic" begin
        buf = IOBuffer()
        write(buf, 42)
        seekstart(buf)
        @test_throws ArgumentError read_header(buf)
    end

    @testset "read_string" begin
        for value in ("", "mooo")
            _test_rw_loop(value)
        end
    end

    @testset "read_name_value" begin
        @testset "int32" begin _test_rw_loop(NameValue("moo", Int32(32))) end
        @testset "float64" begin _test_rw_loop(NameValue("moo", 42.0)) end
        @testset "string" begin _test_rw_loop(NameValue("moo", "lowing")) end
        @testset "uuid" begin _test_rw_loop(NameValue("moo", UUIDs.uuid1())) end
    end

    @testset "read_content_description_section" begin
        _test_rw_loop(ContentDescriptionSection(""))
        _test_rw_loop(ContentDescriptionSection("some description"))
    end
end
