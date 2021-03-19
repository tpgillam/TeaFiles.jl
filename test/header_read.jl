using UUIDs

using TeaFiles.Header: ContentDescriptionSection, Field, ItemSection,
    NameValue, NameValueSection, TeaFileMetadata, TimeSection, MAGIC_VALUE,
    _read_tea, _write_tea

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
        @test_throws ArgumentError read(buf, TeaFileMetadata)
    end

    @testset "read_incorrect_magic" begin
        buf = IOBuffer()
        write(buf, 42)
        seekstart(buf)
        @test_throws ArgumentError read(buf, TeaFileMetadata)
    end

    @testset "read_string" begin
        for value in ("", "mooo")
            _test_rw_loop(value)
        end
    end

    @testset "read_field" begin
        for field_type_id in 1:10
            _test_rw_loop(Field(field_type_id, 0, "moo"))
        end
    end

    @testset "read_name_value" begin
        @testset "int32" begin _test_rw_loop(NameValue("moo", Int32(32))) end
        @testset "float64" begin _test_rw_loop(NameValue("moo", 42.0)) end
        @testset "string" begin _test_rw_loop(NameValue("moo", "lowing")) end
        @testset "uuid" begin _test_rw_loop(NameValue("moo", UUIDs.uuid1())) end
    end

    @testset "read_item_section" begin
        _test_rw_loop(ItemSection("", Field[]))
        _test_rw_loop(ItemSection("Plop", _make_fields([Float64, Float64, Int32])))
        _test_rw_loop(ItemSection(
            "Mooo",
            _make_fields(["a" => Float64, "b" => Float64, "c" => Int32])
        ))
    end

    @testset "read_time_section" begin
        _test_rw_loop(TimeSection(0, 0, Int32[]))
        _test_rw_loop(TimeSection(
            719162,  # 1970-01-01
            86400,  # Seconds
            Int32[0]  # First field
        ))
    end

    @testset "read_content_description_section" begin
        _test_rw_loop(ContentDescriptionSection(""))
        _test_rw_loop(ContentDescriptionSection("some description"))
    end

    @testset "read_name_value_section" begin
        _test_rw_loop(NameValueSection([]))
        _test_rw_loop(NameValueSection([NameValue("a", Int32(1))]))
        _test_rw_loop(NameValueSection([
            NameValue("a", Int32(1)),
            NameValue("b", Float64(42.0)),
            NameValue("c", "coo"),
            NameValue("d", UUIDs.uuid1()),
        ]))
    end

    @testset "read_metadata" begin
        # This is the example in the specification.
        example_metadata = TeaFileMetadata(200, 0, [
            ItemSection(
                "Tick",
                _make_fields(["Time" => Int64, "Price" => Float64, "Volume" => Int64])
            ),
            ContentDescriptionSection("ACME prices"),
            NameValueSection([NameValue("decimals", Int32(2))]),
            TimeSection(719162, 86400000, [0])
        ])
        _test_rw_loop(example_metadata)
    end
end
