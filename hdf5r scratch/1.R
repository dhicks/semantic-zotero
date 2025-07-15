library(hdf5r)
test_filename <- tempfile(fileext = ".h5")
file.h5 <- H5File$new(test_filename, mode = "w")
file.h5

uint2_dt <- h5types$H5T_NATIVE_UINT32$set_size(1)$set_precision(2)$set_sign(h5const$H5T_SGN_NONE)
space_ds <- H5S$new(dims = c(10, 10), maxdims = c(Inf, 10))
ds_create_pl_nbit <- H5P_DATASET_CREATE$new()
ds_create_pl_nbit$set_chunk(c(10, 10))$set_fill_value(uint2_dt, 1)$set_nbit()

uint2.grp <- file.h5$create_group("uint2")
uint2_ds_nbit <- uint2.grp$create_dataset(name = "nbit_filter", space = space_ds,
                                          dtype = uint2_dt, dataset_create_pl = ds_create_pl_nbit, chunk_dim = NULL, gzip_level = NULL)


uint2_ds_nbit[, ] <- sample(0:3, size = 100, replace = TRUE)
## access using brackets
uint2_ds_nbit[,]
uint2_ds_nbit$get_storage_size()


## Close when finished
file.h5$close_all()

## Open it
file.h5 = H5File$new(test_filename, mode = 'r+')
## List the groups and datasets it contains
file.h5$ls(recursive = TRUE)

## Extract one to work with it
foo = file.h5[['uint2/nbit_filter']]
foo[,]

## Add a new row
foo[11,] = rep.int(1, 10)
## Confirm it's in there
foo[,]
## NB disk is updated automatically (or when calling close_all()?)

## Remove a row? 
## maybe not a thing? https://groups.google.com/g/h5py/c/UkDioVQwlWM?pli=1
foo[8,] = NULL
