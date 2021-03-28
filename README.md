# TeaFiles

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://tpgillam.github.io/TeaFiles.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://tpgillam.github.io/TeaFiles.jl/dev)
[![Build Status](https://github.com/tpgillam/TeaFiles.jl/workflows/CI/badge.svg)](https://github.com/tpgillam/TeaFiles.jl/actions)
[![Coverage](https://codecov.io/gh/tpgillam/TeaFiles.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/tpgillam/TeaFiles.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

Implement the [TeaFile format](http://discretelogics.com/resources/teafilespec/) for binary timeseries data.

**NB: This module is not affiliated with DiscreteLogics**

**NB: This package is not yet functional - WIP :-)**

## Notes

* We define the epoch relative to 0001-01-01. 
The specification states that the reference is 0000-01-01, however this seems to be an error. 
The example given within the spec, and Python & .NET implementations by DiscreteLogics, are consistent with a reference of 0001-01-01. 
* The specification makes no mention of time zones, and therefore work with naive `DateTime` objects in Julia.
Users are recommended to store times in UTC to avoid ambiguities around DST changepoints.