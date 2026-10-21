# This script will create a new directory and sub-directories for new OFM SAEP data. Data will be downloaded and unzipped.

library(tidyverse)

# Store original setting
old_timeout <- getOption("timeout")

options(timeout = max(600, old_timeout))

sub_dir <- paste0("SAEP Extract_", "2024-10-22")
# sub_dir <- paste0("SAEP Extract_", Sys.Date())

# Does it exist in the base dir?
base_dir <- "J:/OtherData/OFM/SAEP"

if(file.exists(file.path(base_dir, sub_dir)) == FALSE) {
  dir.create(file.path(base_dir, sub_dir))
  
  dirs <- c('original', 'parcelized', 'quality_check')
  walk(dirs, ~dir.create(file.path(base_dir, sub_dir, .x)))
}

# add published to 'quality_check' dir
pub_dir <- file.path(base_dir, sub_dir, "quality_check", "published")

if(file.exists(pub_dir) == FALSE) {
  dir.create(pub_dir)
}

# function for downloading, data dependent
download_data_file <- function(name = c("saep", "apr_hu", "apr_pop")) {

  saep_url <- "https://ofm.wa.gov/wp-content/uploads/sites/default/files/public/dataresearch/pop/smallarea/data/xlsx/saep_block20.zip"
  hu_url <- "https://ofm.wa.gov/sites/default/files/public/dataresearch/pop/april1/ofm_april1_housing.xlsx"
  pop_url <- "https://ofm.wa.gov/sites/default/files/public/dataresearch/pop/april1/ofm_april1_population_final.xlsx"  
  
  url <- switch(name, "saep" = saep_url, "apr_hu" = hu_url, "apr_pop" = pop_url)
  
  # Specify the file name and location where you want to save the file
  file_name <- basename(url)
  file_path <- file.path(base_dir, sub_dir)
  
  if(name == "saep") {
    out_file_path <- file.path(base_dir, sub_dir, 'original')
  } else {
    out_file_path <- file.path(base_dir, sub_dir, 'quality_check/published')
  }
  
  # download file
  download.file(url, file.path(out_file_path, file_name, sep = ""), mode = "wb")
  
}

download_data_file("saep")
download_data_file("apr_hu")
download_data_file("apr_pop")

# # extract file
# zip_file <- file.path(out_file_path, file_name)
# unzip(zip_file, exdir= out_file_path) # Very slow! just extract manually in Explorer

# Always restore the original setting
options(timeout = old_timeout)
