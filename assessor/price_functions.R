library(data.table)
library(tidyverse)

# Convert selected columns to character
convert.columns.to.char <- function(table, columnnames) {
  columns <- columnnames
  cols <- columns[which(columns %in% colnames(table))]
  table[, (cols) := lapply(.SD, as.character), .SDcols = cols]
}

# Convert selected columns to date
convert.columns.to.date <- function(table, columnnames) {
  columns <- columnnames
  cols <- columns[which(columns %in% colnames(table))]
  table[, (cols) := lapply(.SD, lubridate::mdy), .SDcols = cols]
}

# Read all raw files and assign to list. List names are based on filename
read.assessor.files <- function(county, year, foldername) { 
  base.dir <- "J:/Projects/UrbanSim/NEW_DIRECTORY/Databases/Access/Parcels"
  dir <- file.path(base.dir, county, year, foldername)
  
  txtfiles <- list.files(dir, pattern = "\\.txt|\\.csv")
  
  dlist <- NULL
  for (file in txtfiles) {
    tname <- str_extract(file, "\\w+")
    ext <- str_extract(file, "(?<=\\.)\\w+$")
    
    if (county == "Kitsap") {
      if (ext == "txt") {
        t <- fread(file.path(dir, file), header = TRUE, sep = '\t', quote = "")
      } else if (ext == "csv") {
        t <- fread(file.path(dir, file), header = TRUE, sep = ",")
      }
      convert.columns.to.char(t, c("rp_acct_id", "LRSN", "property_class"))
      convert.columns.to.date(t, "Sale_Dt")
    } else if (county == "Pierce") {
      if (ext == "txt") {
        t <- fread(file.path(dir, file), header = TRUE, sep = '|', quote = "")
      } else if (ext == "csv") {
        t <- fread(file.path(dir, file), header = TRUE, sep = ",")
      }
      if (all(c("parcel_number") %in% colnames(t))) {
        t[, PIN := str_pad(as.character(parcel_number), 10, side = "left", pad = "0")]
      } else {
      }
      convert.columns.to.date(t, "sale_date")
    } # end county
   
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




