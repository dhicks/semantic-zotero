## Index: Calculate embeddings
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
                        .embed_model = embed_model, 
                        verbose = FALSE) {
    if (verbose) message(pdf_path)
    path = here::here(.pdf_folder, pdf_path)
    assert_that(file.exists(path))

    if (!force && embedding_exists(pdf_path)) {
        message(glue::glue('Embeddings found for {pdf_path}'))
        return(TRUE)
    }

    id = doc_id(pdf_path)
    
    ## Extract text
    text = suppressMessages(pdftools::pdf_text(path)) |> 
        stringr::str_c(collapse = '\n') |> 
        stringr::str_squish()
    
    if (str_length(text) < 1) {
        message(glue::glue('No text found in {pdf_path}'))
        return(FALSE)
    }
    
    ## Split into "pages" and "blocks"
    ## "page": 1 context width
    ## "block": set of "pages" to pass to ollama simultaneously
    # num_pages = str_length(text) %>%
    #     {. / (max_context * token_coef)} |> 
    #     ceiling()
    pages = split_string(text, max_context * token_coef)
    num_pages = length(pages)
    if (verbose) message(glue('{num_pages} pages'))
    
    str_length(pages) |> 
        max() |> 
        magrittr::is_weakly_less_than(max_context * token_coef) |> 
        assertthat::assert_that(msg = 'Some pages are larger than max context length')
    
    block_assignment = 1:num_pages |> 
        magrittr::subtract(1) |> 
        magrittr::divide_by_int(block_size) |> 
        magrittr::add(1)
    num_blocks = max(block_assignment)
    if (verbose) message(glue('{num_blocks} blocks'))

    embed_block = function(block,
                           .block_assignment = block_assignment, 
                           .pages = pages, 
                           .num_blocks = num_blocks) {
        assertthat::assert_that(block <= .num_blocks)
        block %>% 
            {which(.block_assignment == .)} %>%
            {.pages[.]} |> 
            embed_text() |> 
            t()
    }
    
    ## Embed all blocks
    ## num_pages x embedding_dims output matrix
    embedded = map(1:num_blocks, embed_block, .progress = TRUE) |> 
        reduce(rbind) |> 
        magrittr::set_rownames(str_c(id, '||', 1:num_pages))
    
    ## Write embedding
    write_rds(embedded, here(embeds_dir, glue('{id}.Rds')))

    ## Write metadata
    tibble(doc_id = id, 
           path = pdf_path) |> 
        write_rds(here(meta_dir, glue('{id}.Rds')))
    
    return(embedded)
}

# debugonce(do_embedding)
do_embedding(pdfs[4], force = TRUE, verbose = TRUE) |>
    str()
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
