## Index: Calculate embeddings
## let's try it with just vanilla matrices and CSVs
library(tidyverse)
library(pdftools)
library(ollamar)
library(furrr)

# library(hdf5r)

library(here)
library(assertthat)
library(glue)
library(tictoc)

source(here('parameters.R'))

# Functions for wrangling filenames ----
subdir = \(x)(if_else(str_detect(x, '/'), 
                      str_split_i(x, '/', 1), 
                      '-') |> 
                  URLencode(reserved = TRUE))

doc_id = \(x)(x |> 
                  basename() |> 
                  tools::file_path_sans_ext())

embedding_exists = function(source_doc, .meta_dir = meta_dir) {
    file.exists(here(.meta_dir, 
                     glue('{doc_id(source_doc)}.Rds')))
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
                        .embed_model = embed_model) {
    path = here::here(.pdf_folder, pdf_path)
    assert_that(file.exists(path))

    if (!force && embedding_exists(pdf_path)) {
        message(glue::glue('Embeddings found for {pdf_path}'))
        return(TRUE)
    }

    id = doc_id(pdf_path)
    
    ## Extract text and embed
    text = suppressMessages(pdftools::pdf_text(path)) |> 
        stringr::str_c(collapse = '\n')
    
    if (str_length(text) < 1) {
        message(glue::glue('No text found in {pdf_path}'))
        return(FALSE)
    }
    
    embedded = ollamar::embed(.embed_model, text, truncate = FALSE)[,1]
    
    ## Write embedding
    embedded |>
        matrix(nrow = 1) |> 
        magrittr::set_rownames(id) |> 
        write_rds(here(embeds_dir, glue('{id}.Rds')))
    
    ## Write metadata
    tibble(doc_id = id, 
           path = pdf_path) |> 
        write_rds(here(meta_dir, glue('{id}.Rds')))
    
    return(TRUE)
}

# debugonce(do_embedding)
# do_embedding(pdfs[1], force = TRUE)
# walk(pdfs[1:10], do_embedding, .progress = TRUE)
# open_dataset(index_folder) |> 
#     select(!starts_with('D')) |> 
#     collect()

plan(multisession, workers = 10)
tic()
future_walk(pdfs, ~ do_embedding(., force = FALSE), 
            seed = TRUE,
            .progress = TRUE)
toc()


## Accumulate ----
embeds = list.files(embeds_dir, pattern = '*.Rds',
                    full.names = TRUE) |>
    map(read_rds) |>
    reduce(rbind)
write_rds(embeds, embeds_file)

meta_df = list.files(meta_dir, pattern = '*.Rds',
           full.names = TRUE) |>
    map(read_rds) |>
    bind_rows()
write_rds(meta_df, meta_file)
