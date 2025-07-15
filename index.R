## Index: Calculate embeddings
## DONE: basic indexing setup
## TODO: runs slightly more than 1 sec/doc; but HDF5 doesn't seem to work with parallelization
## try batching files to parallel through embeddings
library(tidyverse)
library(pdftools)
library(ollamar)
library(furrr)

library(hdf5r)

library(here)
library(assertthat)
library(glue)
library(tictoc)

source(here('parameters.R'))

## index file ----
## Set up the embedding file, if necessary
if (!index_file$path_valid(c('index', 'embedding'))) {
    if (nrow(index_file$ls(recursive = TRUE)) > 0) {
        stop(glue('Embeddings not found, but index file {index_path} is not empty!'))
    }
    
    message(glue('Initializing new index {index_path}'))
    index = index_file$create_group('index')
    embed_ds = index$create_dataset(name = 'embeddings', 
                                    dtype = h5types$H5T_NATIVE_DOUBLE, 
                                    space = H5S$new(dims = c(0, embedding_dims), 
                                                    maxdims = c(Inf, embedding_dims)), 
                                    chunk_dim = c(1000, embedding_dims))
    meta_ds = index$create_dataset(name = 'metadata', 
                                   dtype = H5T_STRING$new(size = Inf)$set_cset('UTF-8'), 
                                   space = H5S$new(dims = c(0, 2), 
                                                   maxdims = c(Inf, 2)))
    
    h5attr(meta_ds, 'colnames') = c('doc_id', 'path')
} else {
    message(glue('Opening existing index file {index_path}'))
    open_index()
}


# Functions for wrangling filenames ----
subdir = \(x)(if_else(str_detect(x, '/'), 
                      str_split_i(x, '/', 1), 
                      '-') |> 
                  URLencode(reserved = TRUE))

doc_id = \(x)(x |> 
                  basename() |> 
                  tools::file_path_sans_ext())

embedding_exists = function(source_doc, .meta_ds = meta_ds) {
    embedded_docs = meta_ds[,1]
    doc_id(source_doc) %in% embedded_docs
}

embedding_loc = function(source_doc, .meta_ds = meta_ds) {
    embedded_docs = meta_ds[,1]
    which(doc_id(source_doc) == embedded_docs)
}

## List PDFs to index ----
pdfs = list.files(pdf_folder, 
                  pattern = '*.pdf', 
                  recursive = TRUE)

message(glue('Found {length(pdfs)} PDFs'))

## Do embedding ----
do_embedding = function(pdf_path, 
                        force = FALSE,
                        .pdf_folder = pdf_folder, 
                        .embed_model = embed_model,
                        .embed_ds = embed_ds, 
                        .meta_ds = meta_ds) {
    path = here::here(.pdf_folder, pdf_path)
    if (!file.exists(path)) {
        stop(glue::glue('{pdf_path} not found'))
    }
    if (!identical(.embed_ds$dims[1], .meta_ds$dims[1])) {
        message('Embeddings and metadata have different number of rows')
    }
    
    if (!force && embedding_exists(pdf_path)) {
        message(glue::glue('Embeddings found for {pdf_path}'))
        return(TRUE)
    }
    if (!embedding_exists(pdf_path)) {
        ## Append to bottom
        pos = .embed_ds$dims[1] + 1
    } else if (force && embedding_exists(pdf_path)) {
        ## Locate row to write over
        pos = embedding_loc(pdf_path)
        if (length(pos) > 1) {
            stop(glue('Multiple rows found for {pdf_path}'))
        }
    } else {
        stop('Something went wrong in embedding overwrite prevention')
    }
    
    id = doc_id(pdf_path)
    subdir = subdir(pdf_path)
    
    text = suppressMessages(pdftools::pdf_text(path)) |> 
        stringr::str_c(collapse = '\n')
    
    if (str_length(text) < 1) {
        message(glue::glue('No text found in {pdf_path}'))
        return(FALSE)
    }
    
    embedded = ollamar::embed(.embed_model, text, truncate = FALSE)[,1]
    
    ## Add to dataset
    .embed_ds[pos,] = embedded
    .meta_ds[pos,] = c(id, subdir)
    
    return(TRUE)
}

# debugonce(do_embedding)
# do_embedding(pdfs[5], force = TRUE)
# walk(pdfs[1:10], do_embedding, progress = TRUE)
# open_dataset(index_folder) |> 
#     select(!starts_with('D')) |> 
#     collect()

# plan(multisession, workers = 5)
tic()
walk(pdfs, ~ do_embedding(., force = TRUE), .progress = TRUE)
toc()
