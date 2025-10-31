## collect_zipped_xhtmls
Scapes and loops bulks of documents.  

The program is set up as two scripts: 

# 1. Fetch URL links
Docker and RSelenium are used to collect all URL-links that contain the zipped XHTML-files of Årsredovisningar. If the very latest version is not needed, simply use the provided CSV-files in folder URL.

# 2. Fetch Årsredovisningar
All links contain zipped XHTML-files. The script downloads the ZIP-files to the *internal* memory where the XTHML-files are unpacked. All XHTML-documents are then stripped off of their format-code and pasted into a table. Each row consists of one document.  

# Folder structure
- **Arsredovisningar/**
  - `code/`
  - `data_files/`
    - `URLs/`
      - `file_links_2025.csv`
    - `results/`
      - `arsredovisningar_2025-10-26_12-00-00.csv`

