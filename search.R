## Search
library(tidyverse)
library(pdftools)

library(ollamar)
# library(arrow)
library(here)
library(assertthat)

source(here('parameters.R'))

## Inputs ----
# input_text = pdf_text('/Users/danhicks/Google Drive/Teaching/Phil Sci RAG/Kovaka-Evaluating community science.pdf') |> 
#     str_c(collapse = '\n')
input_text = read_file('/Users/danhicks/Google Drive/Coding/*ST text mining/paper/paper.qmd')

k = 15

## Load embeds and metadata ----
embeds = read_rds(embeds_file)
meta_df = read_rds(meta_file)

## Embed input text and get k closest values ----
vec = embed(embed_model, input_text, truncate = FALSE)

prod = {embeds %*% vec}[,1]

prod[order(prod, decreasing = TRUE)[1:k]] |> 
    enframe() |> 
    rename(doc_id = name)  |> 
    left_join(meta_df, by = 'doc_id')
