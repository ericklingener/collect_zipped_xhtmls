# rm(list=ls())

# 0. Load required packages ####
pacman::p_load(dplyr, lubridate, parallel, RSelenium, httr, curl)
pacman::p_isloaded(dplyr, lubridate, parallel, RSelenium, httr, curl)

# ####
# 1. Access RSelenium through Docker ####
# Start Docker program 
system('open -a "Docker"')

# Wait x seconds for the program to start
Sys.sleep(30) 

# Open a container in Docker and store the ID of the Docker container
container_id <- system('docker run -d -p 4444:4444 -p 7900:7900 --shm-size="2g" selenium/standalone-firefox:4.8.3',
                       intern = TRUE)

# Wait x seconds for the container to start
Sys.sleep(5) 

# Or:
# In Terminal, run: open -a "Docker"
# In Terminal, run: docker run -d -p 4444:4444 -p 7900:7900 --shm-size="2g" selenium/standalone-firefox:4.8.3

# Connect to the RSelenium remote driver
remDr <- remoteDriver(
  remoteServerAddr = "localhost",
  port = 4444L,
  browserName = "firefox"
)

# Go to localhost:7900 and enter password "secret"

# Open the session, verify connection, and set the window size
remDr$open()
remDr$getStatus()
remDr$setWindowSize(1000, 800)

# ####

# 2. Collect the URL-links ####

# Define first and last years of årsredovisningar
first_year <- 2020
last_year <- 2025

# Go to the website
remDr$navigate("https://vardefulla-datamangder.bolagsverket.se/arsredovisningar/")
Sys.sleep(3) # Let initial elements load

# Define years and their corresponding div positions
years <- last_year:first_year
file_links_list <- list()

for (year in years) {
  # Calculate div position: 2 + (last_year - year) * 2
  div_position <- 2 + (last_year - year) * 2
  css_selector <- sprintf("div.file-list:nth-child(%d)", div_position)
  
  # Find hidden file list for the year
  file_list <- remDr$findElements(using = "css selector", css_selector)
  
  if(length(file_list) == 0) {
    message(paste("Skipping", year, "- div not found"))
    next
  }
  
  # Extract links from hidden div
  files <- file_list[[1]]$findChildElements(using = "css selector", "a")
  file_links <- sapply(files, function(x) x$getElementAttribute("href")[[1]])
  
  # Store links with year as key
  file_links_list[[as.character(year)]] <- file_links
  
  message(paste("Successfully processed", year, "-", length(file_links), "links found"))
}

# 3. Export all links to separate CSV files ####
path <- "/Users/beatrice.hedlund/Desktop/R program/07_Arsredovisningar/data_files/URLs/"
timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")

# Save each year's links to CSV-flies
for (year in names(file_links_list)) {
  file_name <- paste0("file_links_", year, "_", timestamp, ".csv")
  write.csv2(data.frame(links = file_links_list[[year]]),
             file = paste0(path, file_name),
             row.names = FALSE)
}


# 4. Close the session and exit the Docker container ####
# Close the RSelenium session
remDr$close()

# Stop the container using the saved container ID
system(paste("docker stop", container_id))

# ####
