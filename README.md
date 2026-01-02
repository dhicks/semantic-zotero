This project leverages Ollama (and `ollamar`, an R package providing a convenient API to Ollama) to implement a basic semantic search for a folder for PDF files (e.g., the folder for PDF storage used by one's Zotero installation). All steps of the process are run locally. 

# Hardware requirements

I developed and have only even tried running this on a 2024 MacBook Pro M4. This machine has something like a GPU (it's integrated into the CPU in a way I don't fully understand). This is probably important for running the embedding model at anything like a reasonable speed. 

# Project organization

Because I've basically just been tinkering around with this as a proof-of-concept for the last six months, the project files are quite disorganized. It's also wildly underdocumented for the same reason. 

- `parameters.R`: Specifies various folder locations and parameters used for the embedding model. 
- `index.R`: Indexes the PDFs found in the target folder, searched recursively. The indexing files are written to a `data` folder and two of its children; these are created if they don't exist. 
- `search.R`: Conducts the semantic search, given input text. 
- `search_clip.R`: A wrapper around `search.R` that gets the input text off the system clipboard. 
- `multi_column.py` and `multi_column.R`: A Python package and R script that calls it (via `reticulate`) to handle multicolumn PDF formats. 

# Setup

You'll need to install [Ollama](https://ollama.com/) and an embedding model. I found that [bge-m3](https://ollama.com/library/bge-m3) has a decent max context window for academic articles and books, did pretty well in a document self-similarity test (i.e., on average how similar is each document chunk to every other chunk from the same document), and didn't run too slowly. 

You'll also need to set up an Anaconda environment `pymupdf_env` with the Python `pymupdf` package (and its dependencies) installed. Finally, you'll need to install the R package `pdftools`; depending on your system [this might require manually installing `poppler`](https://ropensci.r-universe.dev/pdftools). 

Within `parameters.R`, specify the top-level folder containing the PDFs you want to index (`pdf_folder`), and the embedding model, its context window, and number of embedding dimensions. 

Within `index.R`, adjust the number of workers in the `plan()` call on line 8 to a number that makes sense for your machine. These workers are used late in the script, to aggregate the large number of `csv` files that contain the embeddings (one for each document). They are *not* used in constructing embeddings. At least on my machine, trying to parallelize embedding inference did not result in any speed gains, and usually created fragilities or memory issues when indexing was interrupted. 

# Indexing

I recommend running `index.R` in an IDE such as RStudio or Positron. You'll almost certainly encounter indexing issues and it's extremely useful to be able to jump in to debugging or manually run embedding on a single document before resuming the loop. The core indexing function `do_embedding()` creates an embedding file and metadata file for each individual document, making it pretty painless to resume the loop after an interruption. 

One very common indexing error is an `HTTP 400` response from Ollama. IME this always means the input text is longer than the allowed context length (specified in the call to Ollama, not the model's intrinsic max context length). Documents are chunked into sections that should be well below the max context; but this can go wrong if the section includes tables of numbers, OCR errors, and other things that are treated very granularly by the tokenizer. (One limitation of Ollama is that [we don't have easy access to a model's tokenizer](https://github.com/ollama/ollama/issues/12031).) The `pad` argument to `do_embedding()` extends the context length in the Ollama call; bumping this up to 1000-2000 often handles problem texts. 

The indexing function extracts text from PDF files using two tools. The first is a Python package, `pymupdf`, via a script that is aware of the layout of text boxes on each page of the PDF. It uses this to handle multicolumn layouts. (PDFs generally don't include information on the reading order for text boxes, so in particular don't have a clear indication that multicolumn formats are indeed arranged in multiple columns.) However, this approach doesn't seem to pick up OCRed text correctly. As a fallback, `poppler` is used via the R package `pdftools`. A third option is to OCR the PDF using `tesseract`, but by default this option is disabled. Instead you'll see a warning in the R session about empty text. 

# Searching

`search.R` is set up to be run either from a command line using `Rscript` or in an interactive IDE session. `Rscript search.R -h` will print documentation for the command line options. You can pass the input text either directly or as a path to a PDF file. 

`search_clip.R` grabs the input text off the system clipboard and passes it to `search.R` via a command line call. This is useful for, e.g., creating a very simple shell script for BBEdit's scripts menu: 

```
#!/bin/zsh
export LC_ALL=en_US.UTF-8
Rscript '/Users/danhicks/Google Drive/Coding/semantic zotero/search_clip.R'
```

Note that, as of 2026-01-02, `search.R` just uses `pdftools` to extract text from PDF files, and so won't handle multicolumn formats correctly. It also doesn't work with any other file formats. 