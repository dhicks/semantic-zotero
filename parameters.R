## Parameters ----
pdf_folder = '/Users/danhicks/Zotero_pdfs'

index_folder = here('index')

embed_model = 'snowflake-arctic-embed2'
context_size = 8000

assert_that(test_connection(logical = TRUE), 
            msg = 'Ollama is not available. Maybe you need to start it?')
assert_that(model_avail(embed_model))
