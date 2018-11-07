library(data.table)
library(tidyverse)

# Read all raw files and assign to list. List names are based on filename
read.assessor.files <- function(county, year, foldername) { 
  base.dir <- "J:/Projects/UrbanSim/NEW_DIRECTORY/Databases/Access/Parcels"
  dir <- file.path(base.dir, county, year, foldername)
  
  txtfiles <- list.files(dir, pattern = "\\.txt|\\.csv")
  
  dlist <- NULL
  for (file in txtfiles) {
    tname <- str_extract(file, "\\w+")
    ext <- str_extract(file, "(?<=\\.)\\w+$")
    
    if (ext == "txt") {
      t <- fread(file.path(dir, file), header = TRUE, sep = '\t')
    } else if (ext == "csv") {
      t <- fread(file.path(dir, file), header = TRUE, sep = ",")
    }
    
    dlist[[tname]] <- t
  }
  return(dlist)
}

# print column names and structure for each table in datalist
print.table.structure <- function(datalist) {
  for (t in 1:length(datalist)) {
    print(cat("\nTable: ", names(datalist)[t], "\n"))
    print(str(datalist[t]))
  }
}


