using Test

@testset "TeaFiles.jl" begin
    @testset "Header" begin
        include("header_read.jl")
        include("header_write.jl")
    end
end
