## Parameters ----
pdf_folder = '/Users/danhicks/Zotero_pdfs'
# pdf_folder = '/Users/danhicks/Google Drive/Teaching/Phil Sci RAG'

## Ollama ----
## This model runs *extremely* slow; ~80 sec *per page* w/ token_coef = 3
# ## <https://ollama.com/eradeo/inf-retriever-v1-1.5B-causal-F16>
# ## <https://huggingface.co/infly/inf-retriever-v1-1.5b>
# embed_model = 'ollama.com/eradeo/inf-retriever-v1-1.5B-causal-F16'
# max_context = 32768
# embedding_dims = 1536
embed_model = 'snowflake-arctic-embed2'
max_context = 8192
embedding_dims = 1024


# token_coef = 5 * 3/4 ## assumed avg. characters per token
token_coef = 3     ## empirically, seems to be about what we can manage?
## Seems faster to parallelize via map() rather than multiple inputs
block_size = 10    ## num. text segments to send to ollama per call

assertthat::assert_that(ollamar::test_connection(logical = TRUE), 
            msg = 'Ollama is not available. Maybe you need to start it?')
assertthat::assert_that(ollamar::model_avail(embed_model))

# embed_text = purrr::partial(ollamar::embed, 
#                             model = embed_model, 
#                             temperature = 0, ## not sure this matters for embed() though? 
#                             num_ctx = max_context
#                             )

embed_text = function(text, ...) {
    base_embed = purrr::partial(ollamar::embed, 
                                model = embed_model, 
                                temperature = 0, ## not sure this matters for embed() though? 
                                num_ctx = max_context)
    
    tryCatch({
        base_embed(text, ...)
    }, error = function(e) {
        beepr::beep(9)
        message("Error: ", e$message)
        message("Text was:", stringr::str_trunc(text, 300), "\n")
        stop(e)  # or return(NULL) if you prefer
    })
}

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


## File locations ----
data_dir = here('data')
if (!dir.exists(data_dir)) dir.create(data_dir)

embeds_dir = here(data_dir, 'embeds')
if (!dir.exists(embeds_dir)) dir.create(embeds_dir)
embeds_file = here(data_dir, 'embeds.Rds')

meta_dir = here(data_dir, 'meta')
if (!dir.exists(meta_dir)) dir.create(meta_dir)
meta_file = here(data_dir, 'meta.Rds')


## Utility functions ----
#' Split `string` into pieces of length `n`
split_string <- function(string, n) {
    n = floor(n)
    string_length <- stringr::str_length(string)
    if (string_length <= n) {
        return(string)
    }
    # Where to split
    start_positions <- seq(1, string_length, by = n)
    end_positions <- pmin(start_positions + n - 1, string_length)
    
    stringr::str_sub(string, start_positions, end_positions)
}
