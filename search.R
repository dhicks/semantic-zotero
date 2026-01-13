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
if (interactive()) {
      input_text = '/Users/danhicks/Zotero_pdfs/Cartwright/Cartwright-The\ Truth\ Doesn\'t\ Explain\ Much.pdf'
      # input_text = 'implicature and racist dogwhistles'
      threshold = .7
      k = 15
      argv = list(f = FALSE, json = FALSE) ## dummy for argument parser
} else {
      parser = arg_parser(
            'Semantic search of my Zotero library',
            hide.opts = TRUE
      ) |>
            add_argument(
                  'text',
                  help = 'text to search against',
                  default = 'foo'
            ) |>
            add_argument(
                  '-f',
                  help = 'flag to indicate text is a file',
                  flag = TRUE
            ) |>
            add_argument(
                  '--threshold',
                  default = .7,
                  short = '-t',
                  help = 'similarity threshold'
            ) |>
            add_argument(
                  '-k',
                  default = 15,
                  help = 'number of results to return when threshold is not met'
            ) |>
            add_argument(
                  '--json',
                  help = 'output JSON rather than printing the results table',
                  flag = TRUE
            )

      argv = parse_args(parser)
      input_text = argv$text
      threshold = argv$threshold
      k = argv$k
}

if (argv$f || check_file(input_text)) {
      type = tools::file_ext(input_text)
      cli::cli_alert_info('Treating input text as file path')
      if (identical(type, 'pdf')) {
            source('multi_column.R')
            input_text = input_text |>
                  extract_text(input_text)
      } else {
            input_text = read_file(input_text)
      }
      assert_that(length(input_text) > 0)
} else {
      cli::cli_alert_info('Treating input text as text')
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

prod = (embeds %*% vec)[, 1]

results = keep(prod, ~ . > threshold)
if (length(results) < 1) {
      cli::cli_alert_warning('No hits above threshold; returning top {k}')
      results = prod[order(prod, decreasing = TRUE)[1:(3 * k)]]
}

results_df = results |>
      enframe() |>
      separate_wider_delim(name, delim = '||', names = c('doc_id', 'part')) |>
      summarize(value = max(value), part = list(part), .by = doc_id) |>
      top_n(k, value) |>
      arrange(desc(value)) |>
      left_join(meta_df, by = 'doc_id') |>
      mutate(path = here(pdf_folder, path))

if (!argv$json) {
      print(results_df)
} else {
      jsonlite::toJSON(results_df)
}
