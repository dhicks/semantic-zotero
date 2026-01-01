## Use PyMuPDF to extract text in multicolumn formats

## https://github.com/pymupdf/PyMuPDF-Utilities/blob/master/text-extraction/multi_column.py
## https://artifex.com/blog/extract-text-from-a-multi-column-document-using-pymupdf-inpython

# library(purrr)
# library(stringr)
library(reticulate)

## Setup Python environment ----
use_condaenv("pymupdf_env", required = TRUE)

py_config() # Should show your pymupdf_env
py_module_available("pymupdf")

pymupdf <- import("pymupdf")
multi_column <- import("multi_column")

## Pull text out of bounding boxes on the given page ----
get_text = function(page, bboxes) {
      map(bboxes, ~ page$get_text(clip = .x, sort = TRUE))
}

## Core function ----
extract_text = function(
      pdf_path,
      ocr = FALSE,
      page_sep = '\n\n'
) {
      doc = pymupdf$open(pdf_path)
      pages = as_iterator(doc) |>
            iterate()
      bboxes = map(
            pages,
            ~ multi_column$column_boxes(
                  .x,
                  header_margin = 10,
                  no_image_text = TRUE
            ),
            .progress = pdf_path
      )
      text = map2(pages, bboxes, get_text) |>
            list_c() |>
            str_squish() |>
            stringr::str_c(collapse = page_sep)

      ## If the result's empty, fallback to pdftools
      ## Seems to happen with OCRed docs
      if (str_length(text) < 1) {
            cli::cli_alert_warning('Empty text in {pdf_path}; trying pdftools')
            text = suppressMessages(pdftools::pdf_text(pdf_path)) |>
                  str_squish() |>
                  stringr::str_c(collapse = page_sep)
      }
      ## Can also fallback to OCR; default is to skip this
      if (str_length(text) < 1 && ocr) {
            cli::cli_alert_warning('Trying tesseract')
            text = pdftools::pdf_ocr_text(pdf_path)
      }
      if (str_length(text) < 1) {
            cli::cli_alert_danger('No text found in {pdf_path}')
            return(FALSE)
      }
      return(text)
}

# extract_text('sample.pdf')
