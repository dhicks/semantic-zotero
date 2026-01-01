setwd(this.path::here())
text = clipr::read_clip(allow_non_interactive = TRUE) |>
      stringr::str_c(collapse = '\n') |>
      shQuote() |>
      shQuote()
system2(command = 'Rscript', args = c('search.R', text))
# glue::glue('"{shQuote(text)}"')))
