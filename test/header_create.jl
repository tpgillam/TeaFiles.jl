using Dates

using TeaFiles.Header: create_metadata

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
    end
end
