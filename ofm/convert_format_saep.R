# This script will take original ofm saep format, subset for the Central Puget Sound Region if necessary, and convert to various formats used at PSRC
#  Written by Christy Lam 2018-11-02

library(foreign)
library(data.table)
library(openxlsx)
library(stringr)

base.dir <- "J:/OtherData/OFM/SAEP"
dir <- "SAEP Extract_2020-10-02"
data.dir <- file.path(dir, "original")
filename <- "saep_block10_j.dbf"
# filename <- "PSRC_SAEP_BLK2010-2019.xlsx"

# functions ---------------------------------------------------------------


filter.for.psrc <- function(table) {
  cols <- c("STATEFP10", "COUNTYFP10", "TRACTCE10", "BLOCKCE10", "GEOID10")
  counties <- c("033", "035", "053", "061")
  table[, (cols) := lapply(.SD, as.character), .SDcols = cols]
  dt <- table[COUNTYFP10 %in% counties, ]
}

convert.file <- function(filename, inputfileformat, outputfileformat){
  if (inputfileformat == "dbf")   df <- read.dbf(file.path(base.dir, data.dir, filename)) %>% as.data.table
  if (inputfileformat == "xlsx") df <- read.xlsx(file.path(base.dir, data.dir, filename)) %>% as.data.table
  if (inputfileformat == "csv")   df <- fread(file.path(base.dir, data.dir, filename))
  
  # # 2019 data in different format (orig as xlsx Mike M version)
  # setnames(df, str_subset(colnames(df), "County|Block"), c("COUNTYFP10", "GEOID10"))
  # colnames(df) <- str_to_upper(colnames(df))
  # dt <- df[, COUNTYFP10 := switch(COUNTYFP10, 'KING' = '033', 'KITSAP' = '035', 'PIERCE' = '053', 'SNOHOMISH' = '061'), by = 'COUNTYFP10']
  # # dt <- filter.for.psrc(df)
  
  # 2020 data format (orig as shp dbf, Tom version)
  id_cols <- c("STATEFP10", "COUNTYFP10", "TRACTCE10", "BLOCKCE10", "GEOID10", "Version")
  attributes <- c("POP", "HHP","GQ", "HU", "OHU")
  years <- c(as.character(2010:2020))
  cols <- apply(expand.grid(attributes, years), 1, function(x) paste0(x[1], x[2]))
  allcols <- c(id_cols, cols)
  dt <- df[, ..allcols]
  colnames(dt) <- str_to_upper(colnames(dt))
  dt <- filter.for.psrc(dt)

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
  hucols <- grep("Total\\.Housing\\.Units$", colnames(hudt), value = T)
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
  ofm <- readRDS(file.path(base.dir, dir, "ofm_saep.rds")) %>% as.data.table
  attributes <- c("POP", "HHP","GQ", "HU", "OHU")
  cols <- apply(expand.grid(attributes, years), 1, function(x) paste0(x[1], x[2]))
  allcols <- c("COUNTYFP10", cols)
  odt <- ofm[, allcols, with = F]
  dt <- melt.data.table(odt, id.vars = "COUNTYFP10", measure.vars = cols, variable.name = "variable", value.name = "estimate")
  dt[, `:=` (attribute = str_extract(variable, "[[:alpha:]]+"), YEAR = str_extract(variable, "[[:digit:]]+"))]
  dtsum <- dt[, lapply(.SD, sum), .SDcols = "estimate", by = .(COUNTY = COUNTYFP10, attribute, YEAR)]
  dtcast <- dcast.data.table(dtsum, COUNTY + YEAR ~ attribute, value.var = "estimate")
  setcolorder(dtcast, c("COUNTY", "YEAR", attributes))
  d <- dtcast[order(YEAR, COUNTY)][, COUNTYNAME := switch(COUNTY, "033" = "King", "035" = "Kitsap", "053" = "Pierce", "061" = "Snohomish"), by = COUNTY]
  
  pdata <- read.published.ofm.data()
  p <- pdata[year %in% years, ]
  d[p, on = c("COUNTYNAME" = "County", "YEAR" = "year"), `:=`(POP_pub = i.POP_pub, HU_pub = i.HU_pub)]
  d[, `:=`(POP_diff = (POP - POP_pub), HU_diff = (HU - HU_pub))]
  setcolorder(d, c("COUNTY", "COUNTYNAME", "YEAR", attributes, "POP_pub", "HU_pub", "POP_diff", "HU_diff"))
  return(d)
}


# convert.file(filename, inputfileformat = "xlsx", outputfileformat = "rds")
# convert.file(filename, inputfileformat = "xlsx", outputfileformat = "dbf")

convert.file(filename, inputfileformat = "dbf", outputfileformat = "rds")

# QC ----------------------------------------------------------------------


# years <- c(as.character(2010:2018))
# dt <- qc.rds(years)
# print(dt)
# write.xlsx(dt, file.path(base.dir, dir, "quality_check", paste0("ofm_saep_qc_", Sys.Date(), "_2.xlsx")))


