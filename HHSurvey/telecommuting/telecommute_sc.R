library(dplyr)
library(data.table)
library(tidyverse)
library(DT)
library(openxlsx)
library(odbc)
library(DBI)
library(Hmisc)
library(stringr)
library(lubridate)
library(sqldf)
library(stargazer)

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

#function to parse time categories (characters) to number of minutes (int)
time_parse = function (value) {
  
  if (is.na(value) == TRUE ) {
    return (0)
  } else if (value == 0 ){
    return (0)
  }
    else if (value =='None'){
      return(0)
    }
  
  temp = str_split (value, " ")[[1]]
 
  if (length(temp) == 4 ) {
    return ( as.numeric(temp[1]) *60 + as.numeric(temp[3])/60)
  } else if (temp[2] == "hour") {
    return(60)
  } else if (temp[2] == "hours") {
    return( 60 * as.numeric(temp[1]))
  } else if (temp[2] == "minutes") {
    return( as.numeric(temp[1])/60)
  }
  
}





sql.query <- paste("SELECT * FROM HHSurvey.v_trips_2017_2019_public")
trips = read.dt(sql.query, 'sqlquery')



#loading day table

sql.query <- paste("SELECT * FROM HHSurvey.v_days_2017_2019_public")
days = read.dt(sql.query, 'sqlquery')


days_telecom = days %>% mutate(upd_telework_time = 0)
for (i in 1:nrow(days)){
  days_telecom$upd_telework_time[i] = time_parse(days$telework_time[i])
}

# filter down to workers only
sql.query <- paste("SELECT * FROM HHSurvey.v_persons_2017_2019_public")
person = read.dt(sql.query, 'sqlquery')

workers = person %>% filter(worker!='No jobs')
sum(workers$hh_wt_combined)
#2180589

days_telecom_wtd <- days_telecom %>% filter(hh_day_wt_combined>0)

workers_telework_time_days = merge(workers, days_telecom_wtd, by.x='person_id', by.y='personid')

sum(workers_telework_time_days$hh_day_wt_combined.x, na.rm=TRUE)

workers_no_telework_time_days = workers_telework_time_days %>% filter(upd_telework_time==0)

sum(workers_no_telework_time_days$hh_day_wt_combined.x, na.rm=TRUE)
#1685797

workers_telework_time_days = workers_telework_time_days %>% filter(upd_telework_time!=0)
sum(workers_telework_time_days$hh_day_wt_combined.x, na.rm=TRUE)
#494972

workers_telework_time_days_ft = workers_telework_time_days %>% filter(upd_telework_time>=360)

sum(workers_telework_time_days_ft$hh_day_wt_combined.x, na.rm=TRUE)
#210841

trips_no_telework = merge(workers_no_telework_time_days, trips, by.x = c("person_id", "daynum"),
                              by.y=c("personid", 'daynum'))
sum(trips_no_telework$trip_wt_combined)

trips_telework = merge(workers_telework_time_days, trips, by.x = c("person_id", "daynum"),
                          by.y=c("personid", 'daynum'))
sum(trips_telework$trip_wt_combined)

trips_telework_ft = merge(workers_telework_time_days_ft, trips, by.x = c("person_id", "daynum"),
                       by.y=c("personid", 'daynum'))
sum(trips_telework_ft$trip_wt_combined)

#eliminate outliers
# went to primary work place
# distribution

work_trips = trips %>% filter(d_purp_cat == 'Work')


work_trips_no_telework = merge(workers_no_telework_time_days, work_trips, by.x = c("person_id", "daynum"),
                          by.y=c("personid", 'daynum'))
sum(work_trips_no_telework$trip_wt_combined)

work_trips_telework = merge(workers_telework_time_days, work_trips, by.x = c("person_id", "daynum"),
                       by.y=c("personid", 'daynum'))
sum(work_trips_telework$trip_wt_combined)

work_trips_telework_ft = merge(workers_telework_time_days_ft, work_trips, by.x = c("person_id", "daynum"),
                          by.y=c("personid", 'daynum'))
sum(work_trips_telework_ft$trip_wt_combined)

driver_trips = trips %>% filter(driver == 'Driver')


driver_trips_no_telework = merge(workers_no_telework_time_days, driver_trips, by.x = c("person_id", "daynum"),
                               by.y=c("personid", 'daynum'))
driver_trips_no_telework$weighted_distance=driver_trips_no_telework$trip_wt_combined*driver_trips_no_telework$trip_path_distance
driver_trips_no_telework=driver_trips_no_telework%>% replace(is.na(.), 0)


sum(driver_trips_no_telework$weighted_distance)

#53034076

driver_trips_telework_ft= merge(workers_telework_time_days_ft, driver_trips, by.x = c("person_id", "daynum"),
                                 by.y=c("personid", 'daynum'))
driver_trips_telework_ft$weighted_distance=driver_trips_telework_ft$trip_wt_combined*driver_trips_telework_ft$trip_path_distance
driver_trips_telework_ft=driver_trips_telework_ft%>% replace(is.na(.), 0)


sum(driver_trips_telework_ft$weighted_distance)




