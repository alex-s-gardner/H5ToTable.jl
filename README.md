# H5ToTables
[![Build Status](https://github.com/alex-s-gardner/H5ToTable.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/alex-s-gardner/H5ToTable.jl/actions/workflows/CI.yml?query=branch%3Amain)

H5ToTables reads HDF5 vector variables and attributes and places them into a Tables 
compliant NamedTuple. H5ToTables supports subsetting by min and max variable values 
and by stride (i.e. returns only every nth element, where n = stride)

H5ToTables exports two types (`H5var` & `H5att`) and one function (`h5table`)

`H5var` & `H5att` are types that hold the `parent` (i.e. root) location and the `item` name 
for variables and attributes, respectively. `H5att` are returned as [FillArrays](https://github.com/JuliaArrays/FillArrays.jl), allowing 
them to behave as vectors without duplication.

`h5table(file, items)` accepts a path or HDF5.File and a Tuple of Symbol => H5var/H5att 
pairs and returns a Tables compliant NamedTuple with Symbols assigned as keys.

# It's easiest to learn through example

Install
```julia
]add H5ToTables
]add DataFrames
```

Load package to specify path to HDF5 file
```julia
using H5ToTables
using DataFrames

# path to hdf5 file
path2file = "/Users/gardnera/Documents/GitHub/H5ToTable.jl/data/ATL06_20200309231615_11340602_005_01.h5"
```

Define a variable and attribute and read using h5table
```julia
# define Tuble of Pairs{Symbol, H5var/H5att}
items = (
    :latitude => H5var(parent="/gt1l/land_ice_segments", item="latitude"),
    :height => H5var(parent="/gt1l/land_ice_segments", item="h_li"),
    :spot_number => H5att(parent="/gt1l", item="atlas_spot_number"),
    )

nt = h5table(path2file, items)
df = DataFrame(nt)

6052×3 DataFrame
  Row │ latitude  height        spot_number 
      │ Float64   Float32       String      
──────┼─────────────────────────────────────
    1 │  50.8921    3.40282e38  6
    2 │  50.8923    3.40282e38  6
```

Subset variables using min/max range. 
NOTE: if a variables is not sorted the encompassing range may include data > max and < min.

```julia
items = (
    :latitude => H5var(parent="/gt1l/land_ice_segments", item="latitude"; min = 54.0, max = 56.0),
    :height => H5var(parent="/gt1l/land_ice_segments", item="h_li"),
    :spot_number => H5att(parent="/gt1l", item="atlas_spot_number"),
    )

nt = h5table(path2file, items)
df = DataFrame(nt)

# Note: only 1119 vs. 6052 rows when not subset
1119×3 DataFrame
  Row │ latitude  height         spot_number 
      │ Float64   Float32        String      
──────┼──────────────────────────────────────
    1 │  54.0024  1658.76        6
    2 │  54.0101  3.40282e38     6
```

Subset on two variables and only read every 10th value (stride = 10)
```julia
items = (
    :latitude => H5var(parent="/gt1l/land_ice_segments", item="latitude"; min = 54.0, max = 56.0),
    :longitude => H5var(parent="/gt1l/land_ice_segments", item="longitude", min = -128., max = -127.1),
    :height => H5var(parent="/gt1l/land_ice_segments", item="h_li"),
    :spot_number => H5att(parent="/gt1l", item="atlas_spot_number"),
    )

# set `stride` equal to 10
stride = 10;

nt = h5table(path2file, items; stride)
df = DataFrame(nt)

109×4 DataFrame
 Row │ latitude  longitude  height         spot_number 
     │ Float64   Float64    Float32        String      
─────┼─────────────────────────────────────────────────
   1 │  54.1861   -127.106  1002.91        6
   2 │  54.2259   -127.113  3.40282e38     6
   3 │  54.2417   -127.115  1505.02        6
```