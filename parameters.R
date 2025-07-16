## Parameters ----
pdf_folder = '/Users/danhicks/Zotero_pdfs'
# pdf_folder = '/Users/danhicks/Google Drive/Teaching/Phil Sci RAG'

## Ollama ----
embed_model = 'snowflake-arctic-embed2'
embedding_dims = 1024

assertthat::assert_that(ollamar::test_connection(logical = TRUE), 
            msg = 'Ollama is not available. Maybe you need to start it?')
assertthat::assert_that(ollamar::model_avail(embed_model))

## HDF5 index ----
# index_path = 'index.h5'
# index_file = H5File$new(index_path, mode = 'a')
# 
# open_index = function(.index_file = index_file) {
#     index <<- .index_file[['index']]
#     embed_ds <<- index_file[['index']][['embeddings']]
#     meta_ds <<- index_file[['index']][['metadata']]
# }
# 
# trim_last_row = function(.meta_ds = meta_ds, .embed_ds = embed_ds) {
#     idx = nrow(embed_ds[,])
#     .meta_ds$set_extent(c(idx - 1, 2))
#     .embed_ds$set_extent(c(idx - 1, embedding_dims))
# }

## Vanilla R datatypes ----
data_dir = here('data')
if (!dir.exists(data_dir)) dir.create(data_dir)


embeds_dir = here(data_dir, 'embeds')
if (!dir.exists(embeds_dir)) dir.create(embeds_dir)
embeds_file = here(data_dir, 'embeds.Rds')

meta_dir = here(data_dir, 'meta')
if (!dir.exists(meta_dir)) dir.create(meta_dir)
meta_file = here(data_dir, 'meta.Rds')

