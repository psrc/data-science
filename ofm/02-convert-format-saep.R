# After running 01-download-saep.R, this script will take original ofm saep format, subset for the Central Puget Sound Region if necessary, 
# and convert to various formats used at PSRC
#  revised by Christy Lam 2024-10-17

# For QC (comparing April 1 to Block estimates), download from here and save to sub-dir "quality_check/published": https://ofm.wa.gov/washington-data-research/population-demographics/population-estimates/april-1-official-population-estimates

library(foreign)
library(data.table)
library(openxlsx)
library(tidyverse)

base.dir <- "J:/OtherData/OFM/SAEP"
dir <- "SAEP Extract_2024-10-16"
data.dir <- file.path(dir, "original")
filename <- "saep_block20.csv"

id.cols <- c("STATEFP", "COUNTYFP", "TRACTCE", "BLOCKCE", "GEOID20")
counties <- c("33", "35", "53", "61")
years <- c(as.character(2020:2024))
version <- 'September 17, 2024' # taken from OFM block metadata

# functions ---------------------------------------------------------------


filter.for.psrc <- function(table) {
  table[, (id.cols) := lapply(.SD, as.character), .SDcols = id.cols]
  dt <- table[COUNTYFP %in% counties, ]
  attributes <- c("POP", "HHP","GQ", "HU", "OHU")
  cols <- apply(expand.grid(attributes, years), 1, function(x) paste0(x[1], x[2])) # create all combinations of years & attributes
  allcols <- c(id.cols, cols)
  dt <- dt[, ..allcols][, VERSION := version]
}

convert.file <- function(filename, inputfileformat, outputfileformat){

  if (inputfileformat == "dbf")   df <- read.dbf(file.path(base.dir, data.dir, filename)) %>% as.data.table()
  if (inputfileformat == "xlsx") df <- read.xlsx(file.path(base.dir, data.dir, filename)) %>% as.data.table()
  if (inputfileformat == "csv")   df <- fread(file.path(base.dir, data.dir, filename)) %>% as.data.table()
  
  # 2020-24 data format
  dt <- filter.for.psrc(df)
 
  if (outputfileformat == "dbf") write.dbf(dt, file.path(base.dir, dir, "ofm_saep.dbf"))
  if (outputfileformat == "rds") saveRDS(dt, file.path(base.dir, dir, "ofm_saep.rds"))
  if (outputfileformat == "csv") write.csv(dt, file.path(base.dir, dir, "ofm_saep.csv"), row.names = FALSE)
}

read.published.ofm.data <- function() {
  pub.dir <- file.path(base.dir, dir, "quality_check/published")
  counties <- c("King", "Kitsap", "Pierce", "Snohomish")
  filter <- 1
  
  hu <- read.xlsx(file.path(pub.dir, "ofm_april1_housing.xlsx"), sheet = "Housing Units", startRow = 4) %>% as.data.table
  hudt <- hu[County %in% counties & Filter %in% filter, ]
  hucols <- grep("Total\\.Housing\\.Units.*$", colnames(hudt), value = T)
  all.hucols <- c("County", hucols)
  h <- hudt[, all.hucols, with = F]
  hmelt <- melt.data.table(h, id.vars = "County", measure.vars = hucols, variable.name = "variable", value.name = "HU")
  hmelt[, variable := as.character(variable)][, year := str_extract(variable, "[[:digit:]]+")][, variable := NULL]
  
  pop <- read.xlsx(file.path(pub.dir, "ofm_april1_population_final.xlsx"), sheet = "Population", startRow = 5) %>% as.data.table
  pdt <- pop[County %in% counties & Filter %in% filter, ]
  pcols <- grep("^\\d+", colnames(pdt), value = T)
  all.pcols <- c("County", pcols)
  p <- pdt[, all.pcols, with = F]
  pmelt <- melt.data.table(p, id.vars = "County", measure.vars = pcols, variable.name = "variable", value.name = "POP")
  pmelt[, variable := as.character(variable)][, year := str_extract(variable, "[[:digit:]]+")][, variable := NULL]
  
  pmelt[hmelt, on = c("County", "year"), HU := i.HU]
  setnames(pmelt, c("POP", "HU"), c("POP_pub", "HU_pub"))
  new.cols <- c("POP_pub", "HU_pub")
  dt <- pmelt[, (new.cols) := lapply(.SD, as.numeric), .SDcols = new.cols]
  return(dt)
}

qc.rds <- function(years) {
  ofm <- readRDS(file.path(base.dir, dir, "ofm_saep.rds")) %>% as.data.table()
  attributes <- c("POP", "HHP","GQ", "HU", "OHU")
  cols <- apply(expand.grid(attributes, years), 1, function(x) paste0(x[1], x[2]))
  allcols <- c("COUNTYFP", cols)
  odt <- ofm[, allcols, with = F]
  dt <- melt.data.table(odt, id.vars = "COUNTYFP", measure.vars = cols, variable.name = "variable", value.name = "estimate")
  dt[, `:=` (attribute = str_extract(variable, "[[:alpha:]]+"), YEAR = str_extract(variable, "[[:digit:]]+"))]
  dtsum <- dt[, lapply(.SD, sum), .SDcols = "estimate", by = .(COUNTY = COUNTYFP, attribute, YEAR)]
  dtcast <- dcast.data.table(dtsum, COUNTY + YEAR ~ attribute, value.var = "estimate")
  setcolorder(dtcast, c("COUNTY", "YEAR", attributes))
  d <- dtcast[order(YEAR, COUNTY)][, COUNTYNAME := switch(COUNTY, "33" = "King", "35" = "Kitsap", "53" = "Pierce", "61" = "Snohomish"), by = COUNTY]
  
  pdata <- read.published.ofm.data()
  p <- pdata[year %in% years, ]
  d[p, on = c("COUNTYNAME" = "County", "YEAR" = "year"), `:=`(POP_pub = i.POP_pub, HU_pub = i.HU_pub)]
  d[, `:=`(POP_diff = (POP - POP_pub), HU_diff = (HU - HU_pub))]
  setcolorder(d, c("COUNTY", "COUNTYNAME", "YEAR", attributes, "POP_pub", "HU_pub", "POP_diff", "HU_diff"))
  return(d)
}


convert.file(filename, inputfileformat = "csv", outputfileformat = "rds")

# QC ----------------------------------------------------------------------

# df <- readRDS(file.path(base.dir, dir, "ofm_saep.rds"))

# years <- c(as.character(2020:2024))
# dt <- qc.rds(years)
# dt
# write.xlsx(dt, file.path(base.dir, dir, "quality_check", paste0("ofm_saep_qc_", Sys.Date(), "_2.xlsx")))


