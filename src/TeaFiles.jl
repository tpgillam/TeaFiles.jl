module TeaFiles

module Header
include("header/core.jl")
include("header/read.jl")
include("header/write.jl")
end  # Header

module Body
include("body/read.jl")
end  # Body

end  # TeaFiles
