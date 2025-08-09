## Check mean similarity across "pages" within each document
library(tidyverse)
# library(ollamar)

library(here)
library(assertthat)
library(glue)

source(here('parameters.R'))

## k x max_dim matrix of document section embeddings
## for each doc, 1 row = 1 "page" in indexing
embeds = read_rds(embeds_file)

## Split matrix by doc ----
# Extract document identifiers
doc_ids <- sub("\\|\\|.*$", "", rownames(embeds))

# Split matrix rows by doc ID
result <- tapply(seq_len(nrow(embeds)), doc_ids, 
                 function(idx) embeds[idx, , drop = FALSE], 
                 simplify = FALSE)


## Within-doc similarities ----
sims_df = result |> 
    keep(~ nrow(.x) > 1) |>     ## Only docs w/ multiple pages
    map(~ tcrossprod(.x)) |> 
    map(~ .x[upper.tri(.x, diag = FALSE)]) |> 
    map(~ tibble(sims = list(.x), 
                 mean = mean(.x), 
                 sd = sd(.x), 
                 n = length(.x))) |> 
    bind_rows(.id = 'doc') |> 
    select(doc, mean, sd, n, sims)

## Median of mean within-doc similarity is about 0.25; very few have mean > 0.5
sims_df |> 
    dplyr::pull(mean) |> 
    summary()

ggplot(sims_df, aes(mean)) +
    geom_rug() +
    stat_density()
    # stat_ecdf()

## Mean of sd is somewhere around 0.1
## lots of non-finite SDs because a 2x2 will only have 1 off-diagonal element
ggplot(sims_df, aes(sd)) +
    geom_rug() +
    stat_density()
