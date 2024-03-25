# H5ToTables

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
]add Downloads
```

Load package to specify path to HDF5 file
```julia
using H5ToTables
using DataFrames
using Downloads

# download an example HDF5 file if it does not already exist
url = "https://github.com/evetion/SpaceLiDAR-artifacts/releases/download/v0.3.0/ATL06_20220404104324_01881512_006_02.h5"
local_path = joinpath(@__DIR__, "data", splitdir(url)[end])
isfile(local_path) || Downloads.download(url, local_path)
```

Define a variable and attribute and read using h5table
```julia
# define Tuple of Pairs{Symbol, H5var/H5att}
items = (
    :latitude => H5var(parent="/gt1l/land_ice_segments", item="latitude"),
    :height => H5var(parent="/gt1l/land_ice_segments", item="h_li"),
    :spot_number => H5att(parent="/gt1l", item="atlas_spot_number"),
    )

nt = h5table(local_path, items)
df = DataFrame(nt)

33725×3 DataFrame
   Row │ latitude  height     spot_number 
       │ Float64   Float32    String      
───────┼──────────────────────────────────
     1 │ -79.0058  1752.1     1
     2 │ -79.0056  1752.14    1
```

Subset variables using min/max range. 
NOTE: if a variables is not sorted the encompassing range may include data > max and < min.
```julia
items = (
    :latitude => H5var(parent="/gt1l/land_ice_segments", item="latitude"; min= -79.0, max=-75.0),
    :height => H5var(parent="/gt1l/land_ice_segments", item="h_li"),
    :spot_number => H5att(parent="/gt1l", item="atlas_spot_number"),
    )

nt = h5table(local_path, items)
df = DataFrame(nt)

# Note: number of rows have been reduced from 33725 to 22765
22765×3 DataFrame
   Row │ latitude  height      spot_number 
       │ Float64   Float32     String      
───────┼───────────────────────────────────
     1 │ -79.0     1751.18     1
     2 │ -78.9998  1751.13     1
```

Subset on two variables and only read every 10th value (stride = 10)
```julia
items = (
    :latitude => H5var(parent="/gt1l/land_ice_segments", item="latitude"; min= -79.0, max=-75.0),
    :longitude => H5var(parent="/gt1l/land_ice_segments", item="longitude", min = -109., max = -106.),
    :height => H5var(parent="/gt1l/land_ice_segments", item="h_li"),
    :spot_number => H5att(parent="/gt1l", item="atlas_spot_number"),
    )

# set `stride` equal to 10
stride = 10;

nt = h5table(local_path, items; stride)
df = DataFrame(nt)

1815×4 DataFrame
  Row │ latitude  longitude  height         spot_number 
      │ Float64   Float64    Float32        String      
──────┼─────────────────────────────────────────────────
    1 │ -78.1915   -106.0    1518.21        1
    2 │ -78.1897   -106.002  1518.32        1
```