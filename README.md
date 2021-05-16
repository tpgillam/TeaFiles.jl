# TeaFiles

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://tpgillam.github.io/TeaFiles.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://tpgillam.github.io/TeaFiles.jl/dev)
[![Build Status](https://github.com/tpgillam/TeaFiles.jl/workflows/CI/badge.svg)](https://github.com/tpgillam/TeaFiles.jl/actions)
[![Coverage](https://codecov.io/gh/tpgillam/TeaFiles.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/tpgillam/TeaFiles.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

Implement the [TeaFile](http://discretelogics.com/resources/teafilespec/) format.
It is row-oriented, binary, and primarily intended for time-series data.

The primary API is compatible with the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface.

## Example

We create the following toy dataset:

```julia
using Dates
using DataFrames
x = DataFrame(t=[DateTime(2000), DateTime(2001), DateTime(2002)], a=[1, 2, 3], b=[10.0, 20.0, 30.0])
```

This produces the following table:
```
3×3 DataFrame
 Row │ t                    a      b       
     │ DateTime             Int64  Float64 
─────┼─────────────────────────────────────
   1 │ 2000-01-01T00:00:00      1     10.0
   2 │ 2001-01-01T00:00:00      2     20.0
   3 │ 2002-01-01T00:00:00      3     30.0
```

To write this to disk, we use `TeaFiles.write`.
A tea file contains a header with various metadata, including column names and types which are automatically inferred from the table's schema.
Other supported metadata can be specified with optional arguments to `TeaFiles.write`.

Note that the first column of `DateTime` type, if present, is used as the primary index for the tea file.
As such the values therein *must* be non-decreasing in order to comply with the specification.

```julia
using TeaFiles
TeaFiles.write("moo.tea", x)
```

The data can be read back with `TeaFiles.read`, which returns a `Tables`-compatible object.
We can pipe this into the `DataFrame` constructor to get an object that is equal to the origianl.

```julia
TeaFiles.read("moo.tea") |> DataFrame
```

### Reading a sub-interval
If there is a time column, it is guaranteed that its values will be non-decreasing.
We can therefore efficiently read a small time interval in a large file by performing a binary search to find the start point.
One can specify this interval as an argument to `TeaFiles.read`, for example:

```julia
y = TeaFiles.read("moo.tea"; lower=DateTime(2001)) |> DataFrame
println(y)
```
gives:
```
2×3 DataFrame
 Row │ t                    a      b       
     │ DateTime             Int64  Float64 
─────┼─────────────────────────────────────
   1 │ 2001-01-01T00:00:00      2     20.0
   2 │ 2002-01-01T00:00:00      3     30.0
```


## Notes

* We define the epoch relative to 0001-01-01. 
The specification states that the reference is 0000-01-01, however this seems to be an error. 
The example given within the specification, and Python & .NET implementations by DiscreteLogics, are consistent with a reference of 0001-01-01. 

* The specification makes no mention of time zones, and therefore we work with time-zone naive `DateTime` objects in Julia.
Users are recommended to store times in UTC to avoid ambiguities around DST changepoints.

* We do not plan to support the .NET decimal type (type code `0x200` in the standard).