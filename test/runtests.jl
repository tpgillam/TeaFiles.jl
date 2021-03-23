using Test

include("common.jl")

@testset "TeaFiles.jl" begin
    @testset "Header" begin
        include("header_core.jl")
        include("header_read.jl")
        include("header_write.jl")
    end
    @testset "Body" begin
        include("body_read.jl")
    end
end
