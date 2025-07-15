## Index: Calculate embeddings
## TODO: arrow is very slow and memory-inefficient for this use case, where we basically just need a numeric matrix and metadata
## consider HDF5, per this Claude chat: <https://claude.ai/chat/79395582-d46d-48fc-82c8-9f39b1ece774>
library(tidyverse)
library(pdftools)
library(ollamar)
library(furrr)

library(arrow)

library(here)
library(assertthat)
library(glue)

source(here('parameters.R'))

## Functions for wrangling filenames ----
subdir = \(x)(if_else(str_detect(x, '/'), 
                      str_split_i(x, '/', 1), 
                      '-') |> 
                  URLencode(reserved = TRUE))

doc_id = \(x)(x |> 
                  basename() |> 
                  tools::file_path_sans_ext())

embedding_exists = function(source_doc, 
                          .index_folder = index_folder) {
    here(.index_folder, 
         glue('subdir={subdir(source_doc)}'), 
         glue('doc_id={doc_id(source_doc) |> 
              URLencode(reserved = TRUE)}')) |> 
        file.exists()
}

## List PDFs to index ----
pdfs = list.files(pdf_folder, 
                  pattern = '*.pdf', 
                  recursive = TRUE)

message(glue('Found {length(pdfs)} PDFs'))

## Do some embedding ----
do_embedding = function(pdf_path, 
                        force = FALSE,
                        .pdf_folder = pdf_folder, 
                        .index_folder = index_folder,
                        .existing = existing, .embed_model = embed_model) {
    path = here::here(.pdf_folder, pdf_path)
    if (!file.exists(path)) {
        stop(glue::glue('{pdf_path} not found'))
    }
    
    if (!force && embedding_exists(pdf_path)) {
        message(glue::glue('Embeddings found for {pdf_path}'))
        return(TRUE)
    }
    
    id = doc_id(pdf_path)
    subdir = subdir(pdf_path)
    
    text = pdftools::pdf_text(path) |> 
        stringr::str_c(collapse = '\n')
    
    if (str_length(text) < 1) {
        message(glue::glue('No text found in {pdf_path}'))
        return(FALSE)
    }
    
    embedded = ollamar::embed(.embed_model, text, truncate = FALSE)[,1] |> 
        magrittr::set_names(str_c('D', 1:1024)) |> 
        tibble::as_tibble_row()
    
    dataf = tibble::tibble(subdir, id, path) |> 
        dplyr::bind_cols(embedded) |> 
        dplyr::group_by(subdir, id)
    
    arrow::write_dataset(dataf, .index_folder, format = 'parquet')
    
    invisible(dataf)
}

# debugonce(do_embedding)
# do_embedding(pdfs[26], force = FALSE)
# walk(pdfs[1:10], do_embedding, force = TRUE)
# open_dataset(index_folder) |> 
#     select(!starts_with('D')) |> 
#     collect()

plan(multisession, workers = 5)
future_walk(pdfs, do_embedding, .progress = TRUE)
