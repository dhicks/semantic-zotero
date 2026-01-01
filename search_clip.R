## Check if text is a file, possibly removing a wrapping pair of single quotes
check_file = function(text) {
      text |>
            stringr::str_remove('^\'') |>
            stringr::str_remove('\'$') |>
            file.exists()
}


setwd(this.path::here())
text = clipr::read_clip(allow_non_interactive = TRUE) |>
      stringr::str_c(collapse = '\n')

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
