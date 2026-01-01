## TODO: try <https://ragnar.tidyverse.org/>

## Index: Calculate embeddings
library(tidyverse)
# library(pdftools) ## Using pymupdf via multi_column.R and multi_column.py
library(ollamar)
library(furrr)
plan(multisession, workers = 14)

library(here)
library(assertthat)
library(glue)
library(tictoc)

source(here('parameters.R'))
source(here('multi_column.R'))

## Functions for wrangling filenames ----
subdir = \(x) {
      (if_else(str_detect(x, '/'), str_split_i(x, '/', 1), '-') |>
            URLencode(reserved = TRUE))
}

doc_id = \(x) {
      (x |>
            basename() |>
            tools::file_path_sans_ext())
}

embedding_exists = function(
      source_doc,
      .embeds_dir = embeds_dir,
      .meta_dir = meta_dir
) {
      file.exists(here(.embeds_dir, glue('{doc_id(source_doc)}.csv'))) &
            file.exists(here(.meta_dir, glue('{doc_id(source_doc)}.Rds')))
}

## List PDFs to index ----
pdfs = list.files(pdf_folder, pattern = '*.pdf', recursive = TRUE)

message(glue('Found {length(pdfs)} PDFs'))

## Do embedding ----
## Store embeddings for each PDF as k x max_dims matrix
do_embedding = function(
      pdf_path,
      force = FALSE,
      .pdf_folder = pdf_folder,
      verbose = FALSE,
      truncate = TRUE,
      pad = 500,
      ...
) {
      if (verbose) {
            message(pdf_path)
      }
      path = here::here(.pdf_folder, pdf_path)
      assert_that(file.exists(path))

      if (!force && embedding_exists(pdf_path)) {
            if (verbose) {
                  message(glue::glue('Embeddings found for {pdf_path}'))
            }
            return(TRUE)
      }

      id = doc_id(pdf_path)

      ## Extract text
      # text = suppressMessages(pdftools::pdf_text(path)) |>
      text = extract_text(path, ...) |>
            stringr::str_squish() |>
            ## Corner case: sequences like . . . . . . that are tokenized coarsely
            stringr::str_remove_all('( \\.)+')
      if (str_length(text) < 1) {
            cli::cli_alert_danger('No text found in {path}')
            return(FALSE)
      }

      ## Split into "pages" based on context width
      pages = split_string(text, max_context * token_coef)
      num_pages = length(pages)
      if (verbose) {
            message(glue('{num_pages} pages'))
      }

      str_length(pages) |>
            max() |>
            magrittr::is_weakly_less_than(max_context * token_coef) |>
            assertthat::assert_that(
                  msg = 'Some pages are larger than max context length'
            )

      ## Embed all pages
      ## num_pages x embedding_dims output matrix
      embedded = pages |>
            map(
                  ~ embed_text(.x, truncate = truncate, pad = pad),
                  .progress = id
            ) |>
            reduce(cbind) |>
            t() |>
            magrittr::set_rownames(str_c(id, '||', 1:num_pages))

      ## Write embedding
      write.csv(embedded, here(embeds_dir, glue('{id}.csv')))

      ## Write metadata
      tibble(doc_id = id, path = pdf_path) |>
            write_rds(here(meta_dir, glue('{id}.Rds')))

      return(embedded)
}

# debugonce(do_embedding)
# mirai::daemons(NULL)
# mirai::daemons(5)
# tic()
# debugonce(extract_text)
# extract_text(
#       here(
#             pdf_folder,
#             'Singh/Singh-Handbook of Recidivism RiskNeeds Assessment Tools.pdf'
#       )
# )
# do_embedding(
#       pdfs[11807],
#       truncate = TRUE,
#       force = FALSE,
#       verbose = TRUE,
#       pad = 3000
# ) |>
#       str()
# toc()

{
      # plan(multisession, workers = 14) # `futures` approach
      # mirai::daemons(NULL) # `purrr` 1.1.0 approach; tests indicate parallelization doesn't run any faster
      tic()
      walk(
            cli::cli_progress_along(
                  pdfs,
                  format = '{cli::pb_spin} Document {cli::pb_current} / {cli::pb_total}: {pdfs[cli::pb_current]}'
            ),
            ~ do_embedding(
                  pdfs[.],
                  truncate = TRUE,
                  verbose = FALSE,
                  pad = 1000
            ),
            # .progress = TRUE
      )
      toc()
}


## Accumulate ----
## Combine the matrices and metadata across all documents
## ~30 sec
tic()
embeds = list.files(embeds_dir, pattern = '*.csv', full.names = TRUE) |>
      read_csv(
            progress = TRUE,
            col_types = str_c('c', strrep('d', embedding_dims)),
            num_threads = parallel::detectCores() - 1
      ) |>
      column_to_rownames('...1') |>
      as.matrix()
toc()
write_rds(embeds, embeds_file)

## ~2 sec
tic()
meta_df = list.files(meta_dir, pattern = '*.Rds', full.names = TRUE) |>
      future_map(read_rds, .progress = TRUE) |>
      bind_rows()
toc()
write_rds(meta_df, meta_file)
