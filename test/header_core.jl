using Dates

using TeaFiles.Header: TimeSection, _duration_div, field_type, get_section,
    get_primary_time_field, get_time_fields

@testset "core" begin
    @testset "get_section" begin
        metadata = _get_example_metadata()
        time_section = get_section(metadata, TimeSection)
        @test isa(time_section, TimeSection)
        @test time_section.epoch == 719162
    end

    @testset "get_time_fields" begin
        metadata = _get_example_metadata()
        time_fields = get_time_fields(metadata)
        @test length(time_fields) == 1
        time_field = only(time_fields)
        @test time_field == get_primary_time_field(metadata)

        @test field_type(time_field) == Int64
        @test time_field.offset == 0
    end

    @testset "div_duration" begin
        @test _duration_div(Day(1), Hour(1)) == 24
        @test _duration_div(Day(1), Hour(2)) == 12
        @test _duration_div(Day(1), Minute(1)) == 24 * 60
        @test _duration_div(Day(1), Minute(10)) == 24 * 6
        @test _duration_div(Hour(2), Minute(2)) == 60
        @test_throws ArgumentError _duration_div(Minute(3), Minute(4))
    end

end
