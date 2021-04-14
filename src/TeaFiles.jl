module TeaFiles

using Dates

# Times in TeaFiles can either be a Julia DateTime or just a real number.
TimeLike = Union{Real, DateTime}

module Header
include("header/core.jl")
include("header/read.jl")
include("header/write.jl")
include("header/create.jl")
end  # Header

module Body
include("body/read.jl")
end  # Body

include("api.jl")

end  # TeaFiles
