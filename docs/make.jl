using TeaFiles
using Documenter

DocMeta.setdocmeta!(TeaFiles, :DocTestSetup, :(using TeaFiles); recursive=true)

makedocs(;
    modules=[TeaFiles],
    authors="Thomas Gillam <tpgillam@googlemail.com> and contributors",
    repo="https://github.com/tpgillam/TeaFiles.jl/blob/{commit}{path}#{line}",
    sitename="TeaFiles.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://tpgillam.github.io/TeaFiles.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/tpgillam/TeaFiles.jl",
    devbranch="main",
)
