library(hdf5r)

index_path = 'index.h5'
index_file = H5File$new(index_path, mode = 'w')

index = index_file$create_group('index')
embed_ds = index$create_dataset(name = 'embeddings', 
                                dtype = h5types$H5T_NATIVE_DOUBLE, 
                                space = H5S$new(dims = c(0, 100), 
                                                maxdims = c(Inf, 100)), 
                                chunk_dim = c(1000,100))
meta_ds = index$create_dataset(name = 'metadata', 
                               dtype = H5T_STRING$new(size = Inf), 
                               space = H5S$new(dims = c(0, 2), 
                                               maxdims = c(Inf, 2)))

# index$link_delete('embeddings')
index$ls()

index_file$close_all()
