#Household Travel Survey - Telecommute - VMT

# Load Libraries ----------------------------------------------------------

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

# Functions ----------------------------------------------------------------


## Read from Elmer

# Statistical assumptions for margins of error
p_MOE <- 0.5
z<-1.645
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

time_parse = function (value) {
  
  if (is.na(value) == TRUE ) {
    return (NA)
  } else if (value == "None"){
    return ("None")
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

# Loading the data ----------------------------------------------------------------
sql.query <- paste("SELECT * FROM HHSurvey.v_trips_2017_2019_in_house")
trips = read.dt(sql.query, 'sqlquery')

sql.query <- paste("SELECT * FROM HHSurvey.v_days_2017_2019_public")
days = read.dt(sql.query, 'sqlquery')

sql.query <- paste("SELECT * FROM HHSurvey.v_persons_2017_2019_public")
person = read.dt(sql.query, 'sqlquery')

# Data Prep ----------------------------------------------------------------

#creating a new column for telework time
days_telecom = days %>% mutate(upd_telework_time = 0)

for (i in 1:nrow(days)){
  days_telecom$upd_telework_time[i] = time_parse(days$telework_time[i])
}


#creating a table with ppl who telework by filtering out NAs and including all ppl-days that have any telework-time

telework_day = days_telecom %>% filter(!is.na(upd_telework_time),upd_telework_time != "None") %>% 
  mutate(
    telework_cat = case_when(
      (as.numeric(upd_telework_time) > 0 & as.numeric(upd_telework_time) <= 60)  ~ "Less than 1 hr",
      (as.numeric(upd_telework_time) > 60 & as.numeric(upd_telework_time) < 360) ~ "Part-time",
      as.numeric(upd_telework_time) >= 360 & as.numeric(upd_telework_time) <= 720 ~ "Full-time or greater",
      TRUE ~"Other"
    ))

trips_filt = trips %>%
  mutate(wt_distance = trip_path_distance*trip_wt_combined) %>% 
  filter(trip_path_distance < 200) 

#left join - days with trips
telework_day_trips = left_join(telework_day, trips_filt, by = c("personid" ="person_id", "daynum"))

full_time_telework = telework_day_trips %>% filter(telework_cat == "Full-time or greater")

no_telework_day_trips = left_join(no_telework_day, trips_filt, by = c("personid" ="person_id", "daynum"))

##creating a table with ppl who don't telework 
#by including all ppl-days that have indicated "None" in telework time variable
no_telework_day = days_telecom %>% filter(upd_telework_time == "None")

trips = trips %>% mutate(wt_distance = trip_path_distance*trip_wt_combined)

# VMT Calculations ----------------------------------------------------------------

#choose only Driver trips
driver_trips = trips %>% filter(driver == 'Driver' & trip_path_distance < 200) 

driver_trips_no_telework = merge(no_telework_day, driver_trips, by.x = c("personid", "daynum"),
                                 by.y=c("personid", 'daynum')) 
driver_trips_no_telework$weighted_distance=driver_trips_no_telework$trip_wt_combined*driver_trips_no_telework$trip_path_distance
#driver_trips_no_telework=driver_trips_no_telework%>% replace(is.na(.), 0)


sum(driver_trips_no_telework$weighted_distance,na.rm = TRUE)

#48671875
workers_telework_time_days_ft = telework_day %>% filter(telework_cat == "Full-time or greater")
driver_trips_telework_ft= merge(workers_telework_time_days_ft, driver_trips, by.x = c("personid", "daynum"),
                                by.y=c("personid", 'daynum'))
driver_trips_telework_ft$weighted_distance=driver_trips_telework_ft$trip_wt_combined*driver_trips_telework_ft$trip_path_distance
#driver_trips_telework_ft=driver_trips_telework_ft%>% replace(is.na(.), 0)


sum(driver_trips_telework_ft$weighted_distance, na.rm = TRUE)
#3862749

# Person Miles Traveled Calculations ----------------------------------------------------------------

#person miles traveled by mode for all people, workers who didn't telework, and workers who teleworked 6-12 hours

all_ppl_miles = trips_filt %>% 
  right_join(days, by = c("person_id"="personid", "daynum")) %>% 
  group_by(person_id,daynum,main_mode) %>% 
  summarise(sum_trip_miles = sum(wt_distance), ppl_wt = sum(hh_day_wt_combined.y,na.rm = TRUE)) %>% 
  #left_join(person, by = c("personid" = "person_id")) %>% 
  group_by(main_mode) %>% 
  summarise(sum_wt_trips = sum(sum_trip_miles,na.rm = TRUE), sum_wt_ppl = sum(ppl_wt,na.rm = TRUE)) %>% 
  mutate(all_ppl_mi_traveled =sum_wt_trips/sum_wt_ppl )
write.csv(all_ppl_miles)
#workers who didn't telework
no_tele_ppl_miles = no_telework_day_trips %>% group_by(personid,daynum,main_mode) %>% 
  summarise(sum_trip_miles = sum(wt_distance), ppl_wt = sum(hh_day_wt_combined.x)) %>% 
  #left_join(person, by = c("personid" = "person_id")) %>% 
  group_by(main_mode) %>% 
  summarise(sum_wt_trips = sum(sum_trip_miles,na.rm = TRUE), sum_wt_ppl = sum(ppl_wt,na.rm = TRUE)) %>% 
  mutate(no_telework_ppl_mi_traveled =sum_wt_trips/sum_wt_ppl )
write.csv(no_tele_ppl_miles)

#workers who teleworked 6-12 hours

ft_ppl_miles = full_time_telework %>% group_by(personid,daynum,main_mode) %>% 
  summarise(n=n(),sum_trip_miles = sum(wt_distance), ppl_wt = sum(hh_day_wt_combined.x)) %>% 
  #left_join(person, by = c("personid" = "person_id")) %>% 
  group_by(main_mode) %>% 
  summarise(sum_n= sum(n),sum_wt_trips = sum(sum_trip_miles,na.rm = TRUE), sum_wt_ppl = sum(ppl_wt,na.rm = TRUE),n_ppl = n()) %>% 
  mutate(telework_ppl_mi_traveled =sum_wt_trips/sum_wt_ppl )
write.csv(ft_ppl_miles)

joined_ppl_miles = all_ppl_miles %>% 
  left_join(no_tele_ppl_miles, by = "main_mode") %>% 
  left_join(ft_ppl_miles, by = "main_mode") %>% 
  select(main_mode, all_ppl_mi_traveled,no_telework_ppl_mi_traveled, telework_ppl_mi_traveled)
write.csv(joined_ppl_miles)

#closer look at bike travel for full-time teleworkers
full_time_telework %>% 
  filter(main_mode == "Bike") %>% 
  group_by(dest_purpose_simple) %>% 
  summarise(sum_miles =sum(wt_distance,na.rm = TRUE), sum_wt_ppl = sum(hh_day_wt_combined.x,na.rm = TRUE)) %>% 
  mutate(telework_ppl_mi_traveled =sum_miles/sum_wt_ppl )