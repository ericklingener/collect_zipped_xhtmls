# 0. Förberedelser ####
# rm(list=ls())


# Ladda paket
pacman::p_load(curl, dplyr, xml2, progress)
pacman::p_isloaded(curl, dplyr, xml2, progress)

# Indata-path för att hämta alla CSB-filer med nedladdningslänkar
in_path_file_links <- "/.../data_files/URLs" # Ange path där CSV-filerna med URLerna ligger sparade

#Utdata-path av den färdiga tabellen med årsredovisningar
out_path_arsredovisningar <- "/.../data_files/results/" # Ange path dit den färdiga tabellen med alla XHTML-rader kommer exporteras

# ####


# 1. Importera den lokalt sparade CSV-filen med alla URL-länkar ####
# Skapa en lista med alla CSV-filer i sökvägen som heter "file_links"
file_links_files <- list.files(path = in_path_file_links, pattern = "^file_links.*\\.csv$", full.names = TRUE)

# Gå igenom varje fil, läs in den, importera den, gör om till lista och behåll titeln
file_links_list <- list()  # Initiera en tom lista för att lagra varje data.frame
for (file in file_links_files) {  # Skapa loopen
  file_name <- tools::file_path_sans_ext(basename(file))  
  current_file_data <- read.csv2(file)
  file_links_list[[file_name]] <- current_file_data  # Spara varje data.frame i listan med motsvarande namn
}

# Namnen på de importerade CSV-filerna med URLs
print(names(file_links_list))

# Skriv ut de tre första raderna i den första dataframen för att se URLerna
file_links_list[[1]][1:3, ]

# ####


# 2. Välj gruppen av URL:er ####
# Välj listan med URL:er och döp dataframen till "download_df", till exempel...

# Exempel (de tre första raderna för år 2020): 
download_df <- file_links_list[[1]][1:3, ]

# 2020:  
# download_df <- file_links_list[[1]]

# 2021:  
# download_df <- file_links_list[[2]]

# 2022:  
# download_df <- file_links_list[[3]]

# 2023:  
# download_df <- file_links_list[[4]]

# 2024:  
# download_df <- file_links_list[[5]]

# 2025:  
# download_df <- file_links_list[[6]]

# ALLA:   
# download_df <- dplyr::bind_rows(file_links_list)

# ####


# 3. Hjälpfunktion: Rensning av XHTML-formatkod  ####
clean_xhtml_safely <- function(file_path) {
  # Läs in fil som HTML (xml2). Vid fel: returnera NA-placeringar.
  doc <- tryCatch(xml2::read_html(file_path, encoding = "UTF-8"),
                  error = function(e) return(list(text = NA_character_, title = NA_character_)))
  # Om funktionen redan fick tillbaka ett färdigt list-objekt -> returnera det (säkerhetsfall)
  if (is.list(doc) && all(c("text","title") %in% names(doc))) return(doc)
  
  # Ta bort <style>-noder (de innehåller layout, inte textinnehåll)
  nodes_style <- xml2::xml_find_all(doc, "//style")
  if (length(nodes_style) > 0) xml2::xml_remove(nodes_style)
  
  # Ta bort <script>-noder (JS är irrelevant för textinnehållet)
  nodes_script <- xml2::xml_find_all(doc, "//script")
  if (length(nodes_script) > 0) xml2::xml_remove(nodes_script)
  
  # Konvertera dokumentet till text (rå HTML-sträng) 
  html_txt <- as.character(doc)
  
  # Ta bort inbäddade base64-data-URIs
  html_txt <- gsub("data:[^;]+;base64,[A-Za-z0-9+/=]+", "", html_txt)
  
  # Läs HTML-strängen igen efter att inline-data tagits bort
  doc_clean <- tryCatch(xml2::read_html(html_txt, encoding = "UTF-8"),
                        error = function(e) return(list(text = NA_character_, title = NA_character_)))
  if (is.list(doc_clean) && all(c("text","title") %in% names(doc_clean))) return(doc_clean)
  
  # Extrahera textinnehållet från <body> (samla ihop alla body-noder och trimma whitespace)
  body_nodes <- xml2::xml_find_all(doc_clean, "//body")
  body_text <- ""
  if (length(body_nodes) > 0) {
    body_text <- paste(xml2::xml_text(body_nodes, trim = TRUE), collapse = " ")
    body_text <- gsub("\\s+", " ", body_text)
    body_text <- trimws(body_text)
  }
  
  # Hämta <title> om möjligt; annars använd filnamnet som fallback
  title_node <- xml2::xml_find_first(doc_clean, "//title")
  title_txt <- if (!is.na(title_node)) xml2::xml_text(title_node, trim = TRUE) else NA_character_
  if (is.na(title_txt) || nzchar(trimws(title_txt)) == FALSE) title_txt <- basename(file_path)
  list(text = body_text, title = title_txt)
}

# ####



# 4. Nedladdningsloop ####
# Normalisera listan med nedladdningslänkar 
urls <- as.character(download_df)

# Antal poster
n_items <- length(urls)

# Kontroll
if (n_items == 0L) {
  stop("download_df innehåller inga poster.")
}

# Förbered tabell för huvudloopen
results_list <- list()

# Huvudloop
for (idx in seq_len(n_items)) {
  url <- tryCatch(urls[idx], error = function(e) NA_character_)
  if (is.na(url) || nchar(url) == 0) {
    message("Hoppar över tom/saknad URL på index ", idx)
    next
  }
  cat(sprintf("(%d/%d) Startar nedladdning från: %s\n", idx, n_items, url))
  
  # Ladda ner och hoppar över vid fel
  main_zip <- tempfile(fileext = ".zip")
  ok_dl <- tryCatch({
    curl::curl_download(url, main_zip, quiet = FALSE)
    TRUE
  }, error = function(e) {
    message("Nedladdning misslyckades för index ", idx, ": ", conditionMessage(e))
    FALSE
  })
  if (!ok_dl) next
  
  exdir <- tempfile(pattern = "extracted_")
  dir.create(exdir)
  unzip(main_zip, exdir = exdir)
  
  # Extrahera zip-filer tills inga zip-filer återstår
  repeat {
    nested_zips <- list.files(exdir, pattern = "\\.zip$", recursive = TRUE, full.names = TRUE)
    if (length(nested_zips) == 0L) break
    
    # Extrahera varje zip direkt in i exdir och ta bort zip-filen efter extraktion.
    # Vid skadad zip fortgår kodn till nästa
    for (nested in nested_zips) {
      tryCatch({
        unzip(nested, exdir = exdir)
        unlink(nested)  # ta bort zip efter extraktion för att undvika återbearbetning
      }, error = function(e) {
        message("Misslyckades att extrahera nested zip: ", nested, " — ", conditionMessage(e))
        # fortsätt med nästa zip
      })
    }
  }
  
  xhtml_files <- list.files(exdir, pattern = "\\.xhtml?$", recursive = TRUE, full.names = TRUE)
  if (length(xhtml_files) > 0) {
    pb_inner <- progress::progress_bar$new(
      total = length(xhtml_files),
      format = "Läser XHTML :current/:total [:bar] :percent Tid: :elapsed ETA: :eta"
    )
    file_contents_list <- lapply(xhtml_files, function(f) {
      res <- tryCatch(clean_xhtml_safely(f), error = function(e) list(text = NA_character_, title = NA_character_))
      pb_inner$tick()
      res
    })
    
    texts <- vapply(file_contents_list, function(x) if (!is.null(x$text)) x$text else NA_character_, FUN.VALUE = character(1))
    titles <- vapply(file_contents_list, function(x) if (!is.null(x$title)) x$title else NA_character_, FUN.VALUE = character(1))
    
    df <- data.frame(
      file = xhtml_files,
      XHTML_doc_name = basename(xhtml_files),
      extracted_doc_name = titles,
      source_url = rep(url, length(xhtml_files)),
      content = texts,
      stringsAsFactors = FALSE
    )
    
    # Lägg till rader om rader hoppas över
    results_list[[length(results_list) + 1]] <- df
  } else {
    message("Inga XHTML-filer hittades för URL: ", url)
  }
  
  unlink(main_zip)
  unlink(exdir, recursive = TRUE)
  cat("Rensade temporära filer för URL", idx, " / ", n_items, "\n\n")
}

# Printa första raderna
print(head(final_df))

# 5. Exportera data till CSV-fil ####
out <- file.path(out_path_arsredovisningar, paste0("arsredovisningar_", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"), ".csv"))
write.csv2(final_df, file = out, row.names = FALSE, fileEncoding = "UTF-8")
