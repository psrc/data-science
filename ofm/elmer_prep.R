library(data.table)
library(openxlsx)
library(tidyverse)
library(odbc)

dir <- "J:/OtherData/OFM/SAEP"
sub.dir <- "SAEP Extract_2018_11November02" # latest ofm delivery GEOID = GEOID10


# Initial data -------------------------------------------------------------


compile.all.ofm <- function(dir, sub.dir) {
  filename <- "ofm_saep.rds" 
  oraw <- readRDS(file.path(dir, sub.dir, filename)) %>% as.data.table
  cols <- c("COUNTYFP10", "GEOID10")
  attr <- c("POP", "HHP", "GQ", "HU", "OHU")
  selcols <- c(cols, colnames(oraw)[str_which(colnames(oraw), paste(paste0("^", attr), collapse = "|"))])
  orm <- melt.data.table(oraw[, ..selcols], 
                         id.vars = cols,
                         measure.vars = setdiff(selcols, cols),
                         variable.name = "colname",
                         value.name = "estimate")
  orm[, `:=` (year = str_extract(colname, "\\d+"), 
              attribute = str_extract(colname, "[[:alpha:]]+"))
      ][, attribute_desc := switch(attribute, 
                                   "POP" = "Total Population", 
                                   "HHP" = "Household Population", 
                                   "GQ" = "Group Quarter Population", 
                                   "HU" = "Housing Unit",
                                   "OHU" = "Household"),
        by = .(attribute)
        ][, county_name := switch(COUNTYFP10, "033" = "King", "035" = "Kitsap", "053" = "Pierce", "061" = "Snohomish"), by =.(COUNTYFP10)]
  ofm <- orm[, .(CountyID = COUNTYFP10, GEOID = GEOID10, Year = year, Attribute = attribute, AttributeDesc = attribute_desc, Estimate = estimate)]
  ofm[Year <= 2010, Dataset := "Intercensal"]
  ofm[Year > 2010, Dataset := "Postcensal"]
  return(ofm)
}

dt <- compile.all.ofm(dir, sub.dir)


# Connection --------------------------------------------------------------

elmer_connection <- dbConnect(odbc(),
                              driver = "SQL Server",
                              server = "AWS-PROD-SQL\\COHO",
                              database = "Sandbox",
                              trusted_connection = "yes")

dbWriteTable(elmer_connection, "tblOfmSaep", as.data.frame(dt), overwrite = TRUE)

dbDisconnect(elmer_connection)
