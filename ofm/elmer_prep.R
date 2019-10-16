# This script will read-in a vintage of OFM SAEP estimates from ofm_saep.rds and reformat it to write to Elmer.
# The most current vintage will be written to Sandbox as Christy.tblOfmSaep and include intercensal data since 2000 based on 2010 geographies  

library(data.table)
library(openxlsx)
library(tidyverse)
library(odbc)
library(DBI)

dir <- "J:/OtherData/OFM/SAEP"
sub.dir <- "SAEP Extract_2019-10-15" # latest ofm delivery GEOID = GEOID10
outdt.name <- "tblOfmSaep"
# sub.dir <- "SAEP Extract_2018_11November02" # Vintage 
# outdt.name <- "tblOfmSaepVintage2018"
# sub.dir <- "SAEP Extract_2017_10October03" # Vintage
# outdt.name <- "tblOfmSaepVintage2017"

db.connect <- function(adatabase){
  elmer_connection <- dbConnect(odbc(),
                                driver = "SQL Server",
                                server = "AWS-PROD-SQL\\COHO",
                                database = adatabase,
                                trusted_connection = "yes")
}

read.dt <- function(dbconnect, atable) {
  dtelm <- dbReadTable(dbconnect, SQL(atable))
  setDT(dtelm)
}

compile.ofmfile <- function(dir, sub.dir) {
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

compile.inter.and.post.censal <- function(){
  # this function assumes the ofm_saep.rds process contains only years since 2010 
  dt <- compile.ofmfile(dir, sub.dir)
  working.dbtable <- "Christy.tblOfmSaep"
  elmer_connection <- db.connect("Sandbox")
  dtelm <- read.dt(elmer_connection, working.dbtable)
  dtinter <- dtelm[Year < 2010]
  dtall <- rbindlist(list(dtinter, dt))
  # qc <- dtall[, lapply(.SD, sum), .SDcols = c('Estimate'), by = c('Year', 'AttributeDesc')]
  dbWriteTable(elmer_connection, outdt.name, as.data.frame(dtall), overwrite = TRUE)
}

compile.as.is <- function(){
  # this function assumes the ofm_saep.rds process contains all years since 2000 
  dt <- compile.ofmfile(dir, sub.dir)
  elmer_connection <- db.connect("Sandbox")
  dbWriteTable(elmer_connection, outdt.name, as.data.frame(dt), overwrite = TRUE) # export latest and greatest
}

compile.inter.and.post.censal()
dbDisconnect(elmer_connection)
