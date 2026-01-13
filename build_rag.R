library(tidyverse)
library(ollamar)
library(here)
library(glue)

source(here('parameters.R'))

threshold = .7
n_docs = 20

core_dir = '/Users/danhicks/Google Drive/Teaching/*phil sci/site/readings'
out_dir = '/Users/danhicks/Google Drive/Teaching/Phil Sci RAG 2026'

## Read core MD files and get embeddings ----
core_mds = list.files(core_dir, '.md', full.names = TRUE)

refs = list.files(core_dir, '.md')

core_text = map_chr(core_mds, read_file) |>
      str_squish() |>
      str_trunc(max_context * token_coef)

vecs = embed_text(core_text)

colnames(vecs) <- refs

## Load embeds and metadata ----
embeds = read_rds(embeds_file)
meta_df = read_rds(meta_file)

## Calculate similarities and identify docs ----
sims = embeds %*% vecs

rag_docs = lapply(1:ncol(sims), function(i) {
      col <- sims[, i]
      col <- col[col > threshold]
      names(sort(col, decreasing = TRUE)[1:min(4 * n_docs, length(col))])
}) |>
      set_names(refs) |>
      map(~ str_remove_all(., '\\|\\|[0-9]+')) |>
      map(unique) |>
      map(~ .[1:(n_docs + 1)])

rag_docs |>
      list_c() |>
      unique() |>
      length()

## Clean and copy RAG folder ----
docs_df = meta_df |>
      filter(doc_id %in% list_c(rag_docs))

list.files(out_dir) |>
      fs::path_ext_remove() |>
      setdiff(docs_df$doc_id) |>
      str_c('.pdf') %>%
      here(out_dir, .) |>
      fs::file_delete() |>
      print()

file.copy(here(pdf_folder, docs_df$path), out_dir, overwrite = FALSE)
