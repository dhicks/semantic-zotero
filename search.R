## Search
suppressMessages({
      library(tidyverse)
      library(pdftools)
      library(ollamar)

      library(argparser)
      library(here)
      library(assertthat)
      library(glue)

      source(here('parameters.R'))
})

## Inputs ----
parser = arg_parser('Semantic search of my Zotero library', hide.opts = TRUE) |>
      add_argument('text', help = 'text to search against', default = 'foo') |>
      add_argument(
            '-f',
            help = 'flag to indicate text is a file',
            flag = TRUE
      ) |>
      add_argument(
            '--threshold',
            default = .6,
            short = '-t',
            help = 'similarity threshold'
      ) |>
      add_argument(
            '-k',
            default = 15,
            help = 'number of results to return when threshold is not met'
      )

if (interactive()) {
      input_text = pdf_text(
            '/Users/danhicks/Zotero_pdfs/Hilligardt/Hilligardt-Partisan science and the democratic legitimacy ide.pdf'
      ) |>
            str_c(collapse = '\n')
      # input_text = 'implicature and racist dogwhistles'
      threshold = .6
      k = 15
} else {
      argv = parse_args(parser)
      if (!argv$f) {
            input_text = argv$text
      } else {
            path = argv$text
            assert_that(file.exists(path))
            type = tools::file_ext(path)
            if (type == 'pdf') {
                  input_text = path |>
                        pdf_text() |> ## TODO: pass this through multi_column.R::extract_text() instead
                        str_c(collapse = '\n')
            } else {
                  input_text = read_file(path)
            }
            assert_that(length(input_text) > 0)
      }
      threshold = argv$threshold
      k = argv$k
}


## Load embeds and metadata ----
embeds = read_rds(embeds_file)
meta_df = read_rds(meta_file)

## Embed input text and get k closest values ----
vec = input_text |>
      str_squish() %>%
      # str_c('query: ', .) |>
      str_trunc(max_context * token_coef) |>
      embed_text()

prod = {
      embeds %*% vec
}[, 1]

results = keep(prod, ~ . > threshold)
if (length(results) < 1) {
      message(glue('No hits above threshold; returning top {k}'))
      results = prod[order(prod, decreasing = TRUE)[1:k]]
}

results |>
      enframe() |>
      separate_wider_delim(name, delim = '||', names = c('doc_id', 'part')) |>
      summarize(value = max(value), part = list(part), .by = doc_id) |>
      top_n(k, value) |>
      arrange(desc(value)) |>
      left_join(meta_df, by = 'doc_id')
