library(data.table)
library(openxlsx)
library(tidyverse)
library(odbc)

dir <- "J:/OtherData/OFM/SAEP"
sub.dir <- "SAEP Extract_2018_11November02" # latest ofm delivery


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
                                   "POP" = "total population", 
                                   "HHP" = "household population", 
                                   "GQ" = "group quarter population", 
                                   "HU" = "housing unit",
                                   "OHU" = "household"),
        by = .(attribute)
        ][, county_name := switch(COUNTYFP10, "033" = "King", "035" = "Kitsap", "053" = "Pierce", "061" = "Snohomish"), by =.(COUNTYFP10)]
  ofm <- orm[, .(countyfp10 = COUNTYFP10, geoid10 = GEOID10, year, attribute, attribute_desc, estimate)]
  ofm[year <= 2010, dataset := "intercensal"]
  ofm[year > 2010, dataset := "postcensal"]
  return(ofm)
}

dt <- compile.all.ofm(dir, sub.dir)


# Connection --------------------------------------------------------------

elmer_connection <- dbConnect(odbc(),
                              driver = "SQL Server",
                              server = "sql2016\\DSADEV",
                              database = "Sandbox",
                              trusted_connection = "yes")

# dbWriteTable(elmer_connection, "ofm_saep", as.data.frame(dt))

dbDisconnect(elmer_connection)
