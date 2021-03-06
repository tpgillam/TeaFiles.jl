using Test

include("common.jl")

@testset "TeaFiles.jl" begin
    @testset "Header" begin
        include("header_core.jl")
        include("header_read.jl")
        include("header_write.jl")
        include("header_create.jl")
    end
    @testset "Body" begin
        include("body_read.jl")
    end
    @testset "API" begin
        include("api.jl")
    end
    @testset "Example" begin
        include("example.jl")
    end
end
