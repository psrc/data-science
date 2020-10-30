

# Load Libraries ----------------------------------------------------------

library(data.table)
library(tidyverse)
library(DT)
library(openxlsx)
library(odbc)
library(DBI)
library(Hmisc)

# Functions ----------------------------------------------------------------


## Read from Elmer

# Statistical assumptions for margins of error

missing_codes <- c('Missing: Technical Error', 'Missing: Non-response', 
                   'Missing: Skip logic', 'Children or missing', 'Prefer not to answer')

# connecting to Elmer
db.connect <- function() {
  elmer_connection <- dbConnect(odbc(),
                                driver = "SQL Server",
                                server = "AWS-PROD-SQL\\Sockeye",
                                database = "Elmer",
                                trusted_connection = "yes"
  )
}

# a function to read tables and queries from Elmer
read.dt <- function(astring, type =c('table_name', 'sqlquery')) {
  elmer_connection <- db.connect()
  if (type == 'table_name') {
    dtelm <- dbReadTable(elmer_connection, SQL(astring))
  } else {
    dtelm <- dbGetQuery(elmer_connection, SQL(astring))
  }
  dbDisconnect(elmer_connection)
  dtelm
}

# Code ----------------------------------------------------------

sql.query <- paste("SELECT * FROM HHSurvey.v_trips_2017_2019_public")
trips = read.dt(sql.query, 'sqlquery')

#Total trips by survey year
trips %>% group_by(survey_year) %>% 
  summarise(n = n(), sum_comb = sum(trip_wt_combined), sum_2017 = sum(trip_weight_revised, na.rm = TRUE), sum_2019 = sum(trip_wt_2019))

#2017 trips by hhgroup (or survey type)
trips %>% filter(survey_year ==2017) %>% group_by(hhgroup) %>% 
  summarise(n = n(), sum_comb = sum(trip_wt_combined), sum_2017 = sum(trip_weight_revised, na.rm = TRUE), sum_2019 = sum(trip_wt_2019))



