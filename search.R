## Search
library(tidyverse)
library(pdftools)

library(ollamar)
library(arrow)
library(here)
library(assertthat)

source(here('parameters.R'))

## Inputs ----
input_text = pdf_text('/Users/danhicks/Google Drive/Teaching/Phil Sci RAG/Kovaka-Evaluating community science.pdf') |> 
    str_c(collapse = '\n')

k = 15

## Load index ----
index_ar = open_dataset(index_folder)

meta_ar = index_ar |> 
    select(id, path)

embeddings = index_ar |> 
    select(id, starts_with('D')) |> 
    collect() |> 
    column_to_rownames(var = 'id') |> 
    as.matrix()

## Embed input text and get k closest values ----
vec = embed(embed_model, input_text, truncate = FALSE)

prod = {embeddings %*% vec}[,1]

prod[order(prod, decreasing = TRUE)[1:k]] |> 
    enframe() |> 
    rename(id = name) %>%
    right_join(meta_ar, ., by = 'id') |> 
    arrange(desc(value)) |> 
    collect()
