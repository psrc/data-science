# This script will create a new directory and sub-directories for new OFM SAEP data. Data will be downloaded and unzipped.

library(tidyverse)

sub_dir <- paste0("SAEP Extract_", "2024-10-16")
# sub_dir <- paste0("SAEP Extract_", Sys.Date())

# Does it exist in the base dir?
base_dir <- "J:/OtherData/OFM/SAEP"

if(file.exists(file.path(base_dir, sub_dir)) == FALSE) {
  dir.create(file.path(base_dir, sub_dir))
  
  dirs <- c('original', 'parcelized', 'quality_check')
  walk(dirs, ~dir.create(file.path(base_dir, sub_dir, .x)))
  
  # add published to 'quality_check' dir
}

url <- "https://ofm.wa.gov/sites/default/files/public/dataresearch/pop/smallarea/data/xlsx/saep_block20.zip"
hu_url <- "https://ofm.wa.gov/sites/default/files/public/dataresearch/pop/april1/ofm_april1_housing.xlsx"
pop_url <- "https://ofm.wa.gov/sites/default/files/public/dataresearch/pop/april1/ofm_april1_population_final.xlsx"  

# Specify the file name and location where you want to save the file
file_name <- basename(url)
file_path <- file.path(base_dir, sub_dir)
out_file_path <- file.path(base_dir, sub_dir, 'original')

# download file
download.file(url, file.path(out_file_path, file_name, sep = ""), mode = "wb")

# extract file
zip_file <- file.path(out_file_path, file_name)
unzip(zip_file, exdir= out_file_path)

