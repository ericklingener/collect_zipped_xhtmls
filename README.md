# collect_zipped_xhtmls
This program is created to download and extract bulks of Årsredovisningar in ZIP-files within the internal memory. The program is set up as two scripts: 

## 01_URL_links: Fetch URL links
Docker and RSelenium are used to collect all URL-links that contain the zipped XHTML-files of Årsredovisningar. If the very latest version is not needed, simply use the provided CSV-files in folder URL (one CSV-file per year). Docker must be installed locally to run this code. 

(Note: This operation could most definately be done using RVest, I chose Docker and RSelenium due to a learning operation.)

## 02_fetch_docs_clean_SWE: Fetch the documents
All links contain zipped XHTML-files. The script downloads the ZIP-files to the *internal* memory where the XTHML-files are unpacked. All XHTML-documents are then stripped off of their format-code and pasted into a table. Each row consists of one document.  

## Folder structure
- **Arsredovisningar/**
  - `code/`
  - `data_files/`
    - `URLs/`
      - `file_links_2025.csv`
    - `results/`
      - `arsredovisningar_2025-10-26_12-00-00.csv`

