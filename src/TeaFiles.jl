module TeaFiles

module Header
include("header/core.jl")
include("header/read.jl")
include("header/write.jl")
include("header/create.jl")
end  # Header

module Body
include("body/read.jl")
end  # Body

using .Body: get_num_items
using .Header: TeaFileMetadata, create_metadata

export TeaFileMetadata, create_metadata, get_num_items

end  # TeaFiles
