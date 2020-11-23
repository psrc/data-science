#Household Travel Survey - Telecommute

#Analysis to-do: 

#Telecommuting - travel days - 
#When the people telecommute, how much their travel reduced - in terms of number fo trips or travel time; 
#trip freq by purpose and trip distance

#Frequency - usually, and not telecommute; and compare number of trips and trip length. 

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

create_table_one_var = function(var1, table_temp,table_type ) {
  #table_temp = recategorize_var_upd(var2,table_temp)
  #print(table_temp)
  if (table_type == "household" | table_type == "person" ) {
    weight_2017 = "hh_wt_revised"
    weight_2019 = "hh_wt_2019"
    weight_comb = "hh_wt_combined"
  } else if (table_type == "trip") {
    weight_2017 = "trip_weight_revised"
    weight_2019 = "trip_wt_2019"
    weight_comb = "trip_wt_combined"  
  } 
  
  temp = table_temp %>% select(!!sym(var1), all_of(weight_2017), all_of(weight_2019), all_of(weight_comb)) %>% 
    filter(!.[[1]] %in% missing_codes, !is.na(.[[1]])) %>% 
    group_by(!!sym(var1)) %>%  
    summarise(n=n(),sum_wt_comb = sum(.data[[weight_comb]],na.rm = TRUE),sum_wt_2017 = sum(.data[[weight_2017]],na.rm = TRUE),sum_wt_2019 = sum(.data[[weight_2019]],na.rm = TRUE)) %>% 
    mutate(perc_comb = sum_wt_comb/sum(sum_wt_comb)*100, perc_2017 = sum_wt_2017/sum(sum_wt_2017)*100, perc_2019 = sum_wt_2019/sum(sum_wt_2019)*100,delta = perc_2019-perc_2017) %>% 
    ungroup() %>%  mutate(MOE=z*(p_MOE/sum(n))^(1/2)*100) %>% arrange(desc(perc_comb))
  return(temp)
}

create_table_one_var_trip = function(var1, table_temp,table_type ) {
  #table_temp = recategorize_var_upd(var2,table_temp)
  #print(table_temp)
  if (table_type == "household" | table_type == "person" ) {
    weight_2017 = "hh_wt_revised"
    weight_2019 = "hh_wt_2019"
    weight_comb = "hh_wt_combined"
  } else if (table_type == "trip") {
    weight_2017 = "trip_weight_revised"
    weight_2019 = "trip_wt_2019"
    weight_comb = "trip_wt_combined"  
  } 
  
  trip_wt = "shop_trip"
  
  temp = table_temp %>% select(!!sym(var1), all_of(weight_2017), all_of(weight_2019), all_of(weight_comb)) %>% 
    filter(!.[[1]] %in% missing_codes, !is.na(.[[1]])) %>% 
    group_by(!!sym(var1)) %>% 
    summarise(n=n(),sum_wt_comb = sum(.data[[weight_comb]]*.data[[trip_wt]],na.rm = TRUE),sum_wt_2017 = sum(.data[[weight_2017]],na.rm = TRUE),sum_wt_2019 = sum(.data[[weight_2019]],na.rm = TRUE)) %>% 
    mutate(perc_comb = sum_wt_comb/sum(sum_wt_comb)*100, perc_2017 = sum_wt_2017/sum(sum_wt_2017)*100, perc_2019 = sum_wt_2019/sum(sum_wt_2019)*100,delta = perc_2019-perc_2017) %>% 
    ungroup() %>%  mutate(MOE=z*(p_MOE/sum(n))^(1/2)*100) %>% arrange(desc(perc_comb))
  return(temp)
}

create_table = function(var1,var2, table_temp ) {
  #table_temp = recategorize_var_upd(var2,table_temp)
  #print(table_temp)
  temp = table_temp %>% select(!!sym(var1), !!sym(var2),hh_wt_revised,hh_wt_2019, hh_wt_combined) %>% 
    filter(!.[[1]] %in% missing_codes, !is.na(.[[1]]),!is.na(.[[2]]),!.[[2]] %in% missing_codes) %>% 
    group_by(!!sym(var1), !!sym(var2)) %>% 
    summarize(n=n(),sum_wt_comb = sum(hh_wt_combined,na.rm = TRUE),sum_wt_2017 = sum(hh_wt_revised,na.rm = TRUE),sum_wt_2019 = sum(hh_wt_2019,na.rm = TRUE)) %>% 
    group_by(!!sym(var2)) %>%  
    mutate(perc_comb = sum_wt_comb/sum(sum_wt_comb)*100, perc_2017 = sum_wt_2017/sum(sum_wt_2017)*100, perc_2019 = sum_wt_2019/sum(sum_wt_2019)*100,delta = perc_2019-perc_2017) %>% 
    ungroup() %>%  mutate(MOE=1.65*(0.25/sum(n))^(1/2)*100)
  return(temp)
  
  
}

# Analysis ----------------------------------------------------------------
sql.query <- paste("SELECT * FROM HHSurvey.v_trips_2017_2019_public")
trips = read.dt(sql.query, 'sqlquery')

#loading day table

sql.query <- paste("SELECT * FROM HHSurvey.v_days_2017_2019_public")
days = read.dt(sql.query, 'sqlquery')

#checking the categories of telework_time

temp = days %>% group_by(telework_time) %>% tally()

#function to parse time categories (characters) to number of minutes (int)
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

#creating a new column 
days_telecom = days %>% mutate(upd_telework_time = 0)

for (i in 1:nrow(days)){
  days_telecom$upd_telework_time[i] = time_parse(days$telework_time[i])
}


#creating a table with ppl who telework by filtering out NAs and including all ppl-days that have any telework-time
telework_day = days_telecom %>% filter(!is.na(upd_telework_time),upd_telework_time != "None") %>% 
  mutate(
    telework_cat = case_when(
    (as.numeric(upd_telework_time) > 0 & as.numeric(upd_telework_time) <= 60)  ~ "Less than 1 hr",
    (as.numeric(upd_telework_time) > 60 & as.numeric(upd_telework_time) <= 240) ~ "Part-time",
    as.numeric(upd_telework_time) > 240 & as.numeric(upd_telework_time) <= 720 ~ "Full-time or greater",
    TRUE ~"Other"
    ))


telework_day = days_telecom %>% filter(!is.na(upd_telework_time),upd_telework_time != "None") %>% 
  mutate(
    telework_cat = case_when(
      (as.numeric(upd_telework_time) > 0 & as.numeric(upd_telework_time) <= 60)  ~ "Less than 1 hr",
      (as.numeric(upd_telework_time) > 60 & as.numeric(upd_telework_time) < 360) ~ "Part-time",
      as.numeric(upd_telework_time) >= 360 & as.numeric(upd_telework_time) <= 720 ~ "Full-time or greater",
      TRUE ~"Other"
    ))

##creating a table with ppl who don't telework 
#by including all ppl-days that have indicated "None" in telework time variable
no_telework_day = days_telecom %>% filter(upd_telework_time == "None")

#join day tables and trips table

#left join - days with trips
telework_day_trips = left_join(telework_day, trips, by = c("personid", "daynum"))

no_telework_day_trips = left_join(no_telework_day, trips, by = c("personid", "daynum"))

#how to check the join?

#number of trips per person

#using this table to cross check the numbe of ppl in each telework group
days_telecom_ppl_weight = days_telecom %>% 
  mutate(tele_dumb = case_when(upd_telework_time == "None" ~ "None",  is.na(upd_telework_time) ~ "Missing", TRUE ~ "Telework")) %>% 
  group_by(tele_dumb) %>% 
  summarise(n = n(), sum_wt = sum(hh_day_wt_combined))



#for ppl who telework
#dividing sum of all trip weights by number of ppl (sum of  day weights from day table)

sum(telework_day_trips$trip_wt_combined,na.rm = TRUE)/sum(telework_day$hh_day_wt_combined)


#by telework category

ppl_groupby_cat = telework_day %>% group_by(telework_cat) %>% summarise(n_pplday=n(), sum_ppl_wt = sum(hh_day_wt_combined))

temp = telework_day_trips %>% group_by(telework_cat) %>% summarise(n_trips = n(), sum_wt_trip = sum(trip_wt_combined,na.rm = TRUE)) %>% 
  left_join(ppl_groupby_cat, by = "telework_cat") %>% mutate(trips_per_person = sum_wt_trip/sum_ppl_wt)

write.csv(temp)

#for ppl who dont telework
sum(no_telework_day_trips$trip_wt_combined,na.rm = TRUE)/sum(no_telework_day$hh_day_wt_combined)


#analysis by trip destination category - number of work trips

#for ppl who teleworked

sum(telework_day_trips[telework_day_trips$dest_purpose_simple == 'Work',]$trip_wt_combined,na.rm = TRUE)/sum(telework_day$hh_day_wt_combined)


#by teleworking category
temp = telework_day_trips %>% filter(dest_purpose_simple == "Work") %>% group_by(telework_cat) %>% summarise(n = n(), sum_wt_trip = sum(trip_wt_combined,na.rm = TRUE)) %>% 
  left_join(ppl_groupby_cat, by = "telework_cat") %>% mutate(trips_per_person = sum_wt_trip/sum_ppl_wt)
write.csv(temp)

#for ppl who didnt telework
sum(no_telework_day_trips[no_telework_day_trips$dest_purpose_simple == 'Work',]$trip_wt_combined,na.rm = TRUE)/sum(no_telework_day$hh_day_wt_combined)

#summaries for destination purpose
no_telework_day_trips %>% group_by(dest_purpose_simple) %>% 
  summarise(n = n(), weight = sum(trip_wt_combined, na.rm = TRUE)) %>% mutate(share = weight/sum(weight)*100)

telework_day_trips %>% group_by(dest_purpose_simple) %>% 
  summarise(n = n(), weight = sum(trip_wt_combined, na.rm = TRUE)) %>% mutate(share = weight/sum(weight)*100)


#checking number of trips by workers/non workers
sql.query <- paste("SELECT * FROM HHSurvey.v_persons_2017_2019_public")
person = read.dt(sql.query, 'sqlquery')
ppl_wt = person %>% group_by(worker) %>% summarise(sum_ppl_wt = sum(hh_wt_combined))
trips_person = merge(trips,person, by.x = "personid", by.y = "person_id")
temp = trips_person %>% group_by(worker) %>% summarise(trip_wt = sum(trip_wt_combined)) %>% 
  left_join(ppl_wt) %>% mutate(num_trips_p = trip_wt/sum_ppl_wt)

write.csv(temp)


#not weighted counts

fulltime_work_trips = telework_day_trips %>% filter(telework_cat == "Full-time or greater", dest_purpose_simple == 'Work') %>% 
  group_by(personid) %>%
  summarise(n = n(), wt_trips = sum(trip_wt_combined)) %>% arrange(desc(wt_trips))

#distr of work trips for full time teleworkers
temp = fulltime_work_trips %>% 
  group_by(n) %>% summarise(num_trips_count = n())
write.csv(temp)

# number of full-time teleworkers (people count) - 
temp = telework_day_trips %>% filter(telework_cat == "Full-time or greater") %>% 
       select( personid, dayofweek.x, hh_day_wt_combined.x, trip_wt_combined)%>% 
       group_by(personid) %>%
       summarise(n = n(), wt_trips = sum(trip_wt_combined))
df_unique = unique(temp$personid)
length(df_unique)
