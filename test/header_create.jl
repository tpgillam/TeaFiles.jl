using Dates
using Setfield

using TeaFiles.Header: create_metadata, create_metadata_julia_time

@testset "create" begin
    @testset "create_metadata" begin
        @testset "non bits type" begin
            struct Invalid
                a::Array
                b::UInt8
            end
            @test !isbitstype(Invalid)
            @test_throws ArgumentError create_metadata(Invalid)
        end

        @testset "invalid duration" begin
            struct Moo2 a::Int end
            # should not throw
            create_metadata(Moo2)
            create_metadata(Moo2; tick_duration=Day(1))
            @test_throws ArgumentError create_metadata(Moo2; tick_duration=Day(2))
        end

        @testset "example" begin
            metadata = create_metadata(
                Tick;
                time_fields=[:time],
                content_description="ACME prices",
                name_values=NameValue[NameValue("decimals", Int32(2))]
            )
            reference_metadata = _get_example_metadata()
            @test metadata == reference_metadata
        end

        @testset "example namedtuple" begin
            namedtuple_tick = NamedTuple{
                (:time, :price, :volume),
                Tuple{Int64, Float64, Int64}
            }
            metadata = create_metadata(
                namedtuple_tick;
                time_fields=[:time],
                content_description="ACME prices",
                name_values=NameValue[NameValue("decimals", Int32(2))]
            )
            reference_metadata = _get_example_metadata()
            item_section = get_section(reference_metadata, ItemSection)
            item_section = @set item_section.item_name = "NamedTuple"
            _replace_section!(reference_metadata, item_section)
            @test metadata == reference_metadata
        end
    end

    @testset "create_metadata_julia_time" begin
        @testset "example" begin
            metadata = create_metadata_julia_time(
                DateTimeTick;
                content_description="ACME prices",
                name_values=NameValue[NameValue("decimals", Int32(2))]
            )
            reference_metadata = _get_example_datetime_metadata()
            @test metadata == reference_metadata
        end
    end
end
