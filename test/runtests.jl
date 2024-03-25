using H5ToTables
using Test
using DataFrames
using HDF5

@testset "H5ToTables.jl" begin

    # ensure test data is present
    testdir = @__DIR__
    datadir = joinpath(testdir, "data")
    isdir(datadir) || mkdir(datadir)

    function download_artifact(version, source_filename)
        local_path = joinpath(datadir, source_filename)
        url = "https://github.com/evetion/SpaceLiDAR-artifacts/releases/download/v$version/$source_filename"
        isfile(local_path) || Downloads.download(url, local_path)
        return local_path
    end

    ATL06_fn = download_artifact(v"0.3", "ATL06_20220404104324_01881512_006_02.h5")

    @testset "from path" begin
        # test reading from path
        items = (
            :latitude => H5var(parent="/gt1l/land_ice_segments", item="latitude"),
            :height => H5var(parent="/gt1l/land_ice_segments", item="h_li"),
            :spot_number => H5att(parent="/gt1l", item="atlas_spot_number"),
        )

        nt = h5table(ATL06_fn, items)
        df1 = DataFrame(nt)

        @test nrow(df1) == 33725
        @test ncol(df1) == 3
        @test names(df1) == [(String.(getindex.(items, 1)))...]
    end

    @testset "from HDF.File" begin
        # test reading from HDF.File
        file = h5open(ATL06_fn)
        nt = h5table(file, items)
        df2 = DataFrame(nt)
        @test df1 == df2
    end

    @testset "subsetting" begin 
        items = (
            :latitude => H5var(parent="/gt1l/land_ice_segments", item="latitude"; min= -79.0, max=-75.0),
            :longitude => H5var(parent="/gt1l/land_ice_segments", item="longitude", min = -109., max = -106.),
            :height => H5var(parent="/gt1l/land_ice_segments", item="h_li"),
            :spot_number => H5att(parent="/gt1l", item="atlas_spot_number"),
            )

        nt = h5table(file, items)
        df2 = DataFrame(nt)

        @test maximum(df2.latitude) < -75.
        @test minimum(df2.latitude) > -79.0
        @test maximum(df2.longitude) < -106.0
        @test minimum(df2.longitude) > -109.0
        @test nrow(df2) == 18148
        @test names(df2) == [(String.(getindex.(items, 1)))...]
    end

    @testset "step" begin 
        stride = 10
        nt1 = h5table(file, items; stride)
        df3 = DataFrame(nt1)
        @test ceil(nrow(df2) / stride) == nrow(df3)
    end

    @testset "empty" begin 
        items = (
            :latitude => H5var(parent="/gt1l/land_ice_segments", item="latitude"; min=-54.0, max=-56.0),
            :longitude => H5var(parent="/gt1l/land_ice_segments", item="longitude", min=1000, max=1000),
            :height => H5var(parent="/gt1l/land_ice_segments", item="h_li"),
            :spot_number => H5att(parent="/gt1l", item="atlas_spot_number"),
        )
        nt2 = h5table(file, items; stride)
        @test typeof(nt1) == typeof(nt2)
    end
    
    @testset "only attributes" begin
        items = (
            :beam_type => H5att(parent="/gt1l", item="atlas_beam_type"),
            :groundtrack => H5att(parent="/gt1l", item="groundtrack_id"),
            :atmosphere_profile => H5att(parent="/gt1l", item="atmosphere_profile"),
            :spot_number => H5att(parent="/gt1l", item="atlas_spot_number"),
        )
        nt = h5table(file, items)
        df4 = DataFrame(nt)
        @test nrow(df4) == 1
        @test names(df4) == [(String.(getindex.(items, 1)))...]
    end
end