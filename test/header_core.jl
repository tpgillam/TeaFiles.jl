using TeaFiles.Header: TimeSection, field_type, get_section, get_primary_time_field,
    get_time_fields

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
end
