module H5ToTables

    using HDF5
    using FillArrays

    export H5att
    export H5var
    export h5table

    """
        H5var(parent::String, item::String, min::Real = -Inf, max::Real = +Inf)

    Type containing the `parent`` (a.k.a. root) path to the HDF5 variable `item`. Optional `min` 
    and `max` arguments for subsetting all requested variables
    """
    Base.@kwdef mutable struct H5var
        parent::String
        item::String
        min::Real = -Inf
        max::Real = +Inf
    end

    """
        H5att(parent::String, item::String)

    Type containing the `parent` (a.k.a. root) path to the HDF5 attribute `item`
    """
    Base.@kwdef mutable struct H5att
        parent::String
        item::String
    end

    """
        h5table(file, items::Tuple; stride = 1, check_length=true)

    Returns a NamedTuple of item values that is DataFrames complient given an hdf5 file and 
    a Tuple of Pair{Symbol, H5var/H5att}. 

    If rquested hdf5 variables include user supplied min and max values then all rquested hdf5 
    variables will be subset to include data range that encompases the first and last values 
    meeting the min/max critria. NOTE: if a variables is not sorted then the encompassing range 
    may include data >max and <min.

    Options: 
        stride: only return every `stride` value in series 
        check_length: check that all requested variables have the same number of elements
    """
    function h5table(file::HDF5.File, items::Tuple; stride=1, check_length=true)

        # find all requested variables
        isvar = [isa.(getindex.(items, 2), Ref(H5var))...]

        if !any(isvar)
            # no variables requested, return attributes with length 1
            start = 1
            stop = 1
            nt = (; (vname => _read_h5item(file,item,start,stride,stop) for (vname, item) in items)...)
        else
            # variables requested

            # check that all variables are of the same length
            if check_length
                var_length = [length(file[item.parent][item.item]) for (vname, item) in items[isvar]]
                var_length = unique(var_length)

                if length(var_length) > 1
                    error("requested variables do not have the same length and therefor can't be placed into a table")
                else
                    var_length = var_length[1]
                end
            else
                item = items[findfirst(isvar)]
                var_length = length(file[item.parent][item.item])
            end

            # initialize read start and stop 
            start = 1
            stop = var_length

            # find all variables with min/max bounds used for subsetting all variables
            hasbounds = falses(size(isvar))
            hasbounds[isvar] = [!(isinf(item.max) .& isinf(item.min)) for (vname, item) in items[isvar]]

            if any(hasbounds)
                # subsetting requested
                nt = (; (vname => _read_h5item(file,item,start,stride,stop) for (vname, item) in items[hasbounds])...)
                
                for (var, item) = zip(nt,items[hasbounds])
                    ind = (var .> item[2].min) .& (var .< item[2].max)

                    if any(ind)
                        start = max(start, findfirst(ind)*stride)
                        stop = min(stop, findlast(ind)*stride)
                    end

                    if !any(ind) || ((stop-start+1)/stride) <= 1
                        # create empty table
                        nt = (; (vname => _emptycolumn_h5item(file, item) for (vname, item) in items)...)
                        return nt
                    end
                end

                # read `hasbounds` variables from NamedTuple, read others from file
                nt = (; (hb ? 
                    item[1] => _read_h5item(nt,item[1],start,stride,stop) : 
                    item[1] => _read_h5item(file,item[2],start,stride,stop) 
                    for (item, hb) in zip(items, hasbounds))...)
                return nt
            else
                # no subsetting requested
                nt = (; (vname => _read_h5item(file,item,start,stride,stop) for (vname, item) in items)...)
                return nt
            end
        end
    end

    function h5table(path2file::String, items::Tuple; stride = 1, check_length = true)
        file = HDF5.h5open(path2file, "r");
        h5table(file, items; stride, check_length)
    end

    function _read_h5item(
        file::HDF5.File,
        item::H5var,
        start::Int,
        stride::Int,
        stop::Int,
    )

        itm = file[item.parent][item.item][start:stride:stop]
        return itm
    end

    function _read_h5item(
        file::HDF5.File,
        item::H5att,
        start::Int,
        stride::Int,
        stop::Int,
    )
        n = ceil(Int64, (stop - start + 1) / stride)
        itm = Fill(read(attributes(file[item.parent])[item.item]), n)
        return itm
    end

    function _read_h5item(
        nt::NamedTuple,
        vname::Symbol,
        start::Int,
        stride::Int,
        stop::Int,
    )
        start = Int64(start/stride)
        stop = Int64(stop / stride)
        itm = nt[vname][start:stop]
        return itm
    end

    function _emptycolumn_h5item(
        file::HDF5.File,
        item::H5var,
    )

        type = eltype(file[item.parent][item.item])[]
        return type
    end

    function _emptycolumn_h5item(
        file::HDF5.File,
        item::H5att,
    )

        type = Fill(read(attributes(file[item.parent])[item.item]), 0)
        return type
    end
end