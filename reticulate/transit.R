library(reticulate)
library(data.table)
library(openxlsx)
library(magrittr)
library(stringr)
library(purrr)

dir <- "J:/Projects/reticulate"
filename <- "September_2018_Adjusted_Database.xlsx"

tabs <- getSheetNames(file.path(dir, filename))
sheets <- c("UPT", "VRH")

compile.transit <- function(sheets) {
  dts <- NULL # store tidy tables
  for (sheet in sheets) {
    d <-read.xlsx(file.path(dir, filename), sheet = sheet) %>% as.data.table
    months <- str_extract(colnames(d)[grep("\\d{2}$", colnames(d))], "[[:alpha:]]+") %>% unique
    meltcols <- grep("\\d{2}$", colnames(d), value = T)
    colnames(d)[1:2] <- c("digit.NTD.ID.5", "digit.NTD.ID.4")
    dmelt <- melt.data.table(d, 
                             id.vars = c(colnames(d)[which(!(colnames(d) %in% meltcols))]), 
                             measure.vars = grep("\\d{2}$", colnames(d), value = T),
                             variable.name = "columnname",
                             value.name = "estimate")
    dmelt[, `:=` (digit.NTD.ID.5 = as.character(str_pad(digit.NTD.ID.5, 5, "left", 0)),
                  digit.NTD.ID.4 = as.character(str_pad(digit.NTD.ID.4, 4, "left", 0)),
                  month = str_extract(columnname, "[[:alpha:]]+"), 
                  year = paste0("20", str_extract(columnname, "[[:digit:]]+")),
                  columnname = NULL)]
    d <- dmelt[!is.na(Agency), ][is.na(estimate), estimate := 0]
    dts[[sheet]] <- d
  }
  return(dts)  
}


summarize.transit <- function(table) {
  table[, lapply(.SD, sum), .SDcols = "estimate", by = c("digit.NTD.ID.5", "Modes", "Agency", "year")]
}

dts <- compile.transit(sheets)
sum.dts <- map(dts, summarize.transit)






