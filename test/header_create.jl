using Dates

using TeaFiles.Header: _duration_div, create_metadata

@testset "create" begin
    @testset "div_duration" begin
        @test _duration_div(Day(1), Hour(1)) == 24
        @test _duration_div(Day(1), Hour(2)) == 12
        @test _duration_div(Day(1), Minute(1)) == 24 * 60
        @test _duration_div(Day(1), Minute(10)) == 24 * 6
        @test _duration_div(Hour(2), Minute(2)) == 60
        @test_throws ErrorException _duration_div(Minute(3), Minute(4))
    end

    @testset "create_metadata" begin
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
