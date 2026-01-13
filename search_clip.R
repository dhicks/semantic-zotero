setwd(this.path::here())
text = clipr::read_clip(allow_non_interactive = TRUE) |>
      stringr::str_c(collapse = '\n')

source('parameters.R')

if (check_file(text)) {
      cli::cli_alert_info('Treating clipboard text as file path')
      system2(command = 'Rscript', args = c('search.R', text, '-f'))
} else {
      cli::cli_alert_info('Treating clipboard text as text')
      text = text |>
            shQuote() |>
            shQuote()
      system2(command = 'Rscript', args = c('search.R', text))
}

# glue::glue('"{shQuote(text)}"')))
