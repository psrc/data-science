#Household Travel Survey - Telecommute - Socio-economic modeling

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
library(MASS)
library(lubridate)
library(MASS)
library(ggpubr)
library(gmapsdistance)
library(broom)
library(clipr)

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
    return (0)
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

sql.query <- paste("SELECT * FROM HHSurvey.v_persons_2017_2019_in_house WHERE worker <> 'No jobs'")
person = read.dt(sql.query, 'sqlquery')

sql.query <- paste("SELECT * FROM HHSurvey.v_households_2017_2019_in_house")
household = read.dt(sql.query, 'sqlquery')

# Data Prep ----------------------------------------------------------------

#creating a new column for telework time
days_telecom = days %>% mutate(upd_telework_time = 0)

for (i in 1:nrow(days)){
  days_telecom$upd_telework_time[i] = time_parse(days$telework_time[i])
}
days_telecom = days_telecom %>% filter(!is.na(telework_time))

#join person

days_telecom_person = left_join(days_telecom, person, by = c("personid" = "person_id"))
days_telecom_person_hh = left_join(days_telecom_person, household, by = c("hhid" = "household_id"))



# data prep for ordered logit model

telework_day = days_telecom %>% filter(!is.na(upd_telework_time),upd_telework_time != "None") %>% 
  mutate(
    telework_cat = case_when(
      (as.numeric(upd_telework_time) == 0)  ~ "None",
      (as.numeric(upd_telework_time) > 0 & as.numeric(upd_telework_time) <= 60)  ~ "Less than 1 hr",
      (as.numeric(upd_telework_time) > 60 & as.numeric(upd_telework_time) < 360) ~ "Part-time", # 1 - 6 hrs
      as.numeric(upd_telework_time) >= 360 & as.numeric(upd_telework_time) <= 720 ~ "Full-time or greater", # 6 - 12 hrs
      TRUE ~"Other")) %>%  # more than 12 hrs 
  filter ( telework_cat != "Other") 

#joins

telework_day_person = left_join(telework_day, person, by = c("personid" = "person_id"))
telework_day_person_hh = left_join(telework_day_person, household, by = c("hhid" = "household_id"))

# telework category as ordered factor

telework_day_person_hh$telework_cat = factor(telework_day_person_hh$telework_cat, levels = c("None", "Less than 1 hr", "Part-time", "Full-time or greater"))##, ordered = TRUE)

telework_day_person_hh$hhincome_detailed = factor(telework_day_person_hh$hhincome_detailed, 
                                              levels = c("Under $10,000", "$10,000-$24,999", "$25,000-$34,999", 
                                                         "$35,000-$49,999", "$50,000-$74,999","$75,000-$99,999",
                                                         "$100,000-$149,999", "$150,000-$199,999", "$200,000-$249,999", "$250,000 or more", "Prefer not to answer"))# , ordered = TRUE )

telework_day_person_hh$age = factor(telework_day_person_hh$age, 
                                                  levels = c("18-24 years", "25-34 years", "35-44 years", 
                                                             "45-54 years", "55-64 years","65-74 years",
                                                             "75-84 years", "85 or years older"))#, ordered = TRUE )

df2 <- data.frame(var=c("Associates degree","Bachelor degree", "Graduate/post-graduate degree", "High school graduate", 
                        "Less than high school","Missing: Skip logic","Some college", "Vocational/technical training"), 
                  upd_var=c("Some college, Associates, or Vocational/technical training","Bachelor degree", "Graduate/post-graduate degree", "High school or less", 
                            "High school or less","Missing: Skip logic","Some college, Associates, or Vocational/technical training", "Some college, Associates, or Vocational/technical training"))

telework_day_person_hh$education_upd <- df2$upd_var[match(telework_day_person_hh$education,df2$var)]

telework_day_person_hh$education_upd = factor(telework_day_person_hh$education_upd, 
                                    levels = c("High school or less", "Some college, Associates, or Vocational/technical training",  
                                               "Bachelor degree", "Graduate/post-graduate degree"))#, ordered = TRUE )


# Linear Model ----------------------------------------------------------------
#include to the model: income, age, gender, jobs_count, education, license, race_category,
model1 = lm(upd_telework_time~hhincome_broad+age+ gender+education+license+race_category,data = days_telecom_person_hh )
summary(model1)

model2 = lm(upd_telework_time~hhincome_detailed+age+ gender+education+license+race_category+employment,data = days_telecom_person_hh )
summary(model2)

# Ordered Logit Model ----------------------------------------------------------------
ord_logit_model1 = polr(telework_cat ~ hhincome_broad+age+ gender+education_upd+race_category , data = telework_day_person_hh, Hess = TRUE)

ord_logit_model1%>%
  tidy()%>%
  write_clip()


# Data Prep for another model ----------------------------------------------------------------
telework_day_person_hh= telework_day_person_hh %>% 
                        mutate(hhincome_detailed_refined = case_when(
                          hhincome_detailed == '$150,000-$199,999'~'$150,000 or more',
                          hhincome_detailed == '$200,000-$249,999'~'$150,000 or more',
                          hhincome_detailed == '$250,000 or more'~'$150,000 or more',
                          hhincome_detailed == '$25,000-$34,999'~'Under $49,999',
                          hhincome_detailed == '$35,000-$49,999'~'Under $49,999',
                          hhincome_detailed == 'Under $10,000'~'Under $49,999',
                          hhincome_detailed == '$10,000-$24,999'~'Under $49,999',
                          TRUE ~ as.character(hhincome_detailed)),
                        age_refined = case_when(
                          age == "65-74 years" ~ "65 years or older",
                          age == "75-84 years" ~ "65 years or older",
                          age == "85 or years older" ~ "65 years or older",
                          age == "25-34 years" ~ "18-34 years",
                          age == "18-24 years" ~ "18-34 years",
                          age == "35-44 years" ~ "35-65 years",
                          age == "45-54 years" ~ "35-65 years",
                          age == "55-64 years" ~ "35-65 years",
                          TRUE ~ 'other')) %>% 
                        filter (gender %in% c('Female', 'Male')) %>% 
                        mutate(license_upd = case_when(
                          license == 'Yes, has a learner's permit' ~ 'Yes',
                          license == 'Yes, has an intermediate or unrestricted license' ~ 'Yes',
                          TRUE ~ as.character(license)))

telework_day_person_hh$hhincome_detailed_refined = factor(telework_day_person_hh$hhincome_detailed_refined, 
                                                  levels = c("$150,000 or more", "Under $49,999", 
                                                             "$50,000-$74,999","$75,000-$99,999",
                                                             "$100,000-$149,999", "Prefer not to answer"))# , ordered = TRUE )

telework_day_person_hh$race_category = factor(telework_day_person_hh$race_category, 
                                              levels = c('White Only', 'African American', 'Asian', 'Hispanic', 'Missing', 'Other' ))

telework_day_person_hh$employment = factor(telework_day_person_hh$race_category, 
                                              levels = c('White Only', 'African American', 'Asian', 'Hispanic', 'Missing', 'Other' ))





ord_logit_model_income_refined = polr(telework_cat ~ hhincome_detailed_refined+age_refined+ gender+education_upd+license_upd+race_category+employment , data = telework_day_person_hh, Hess = TRUE)
summary(ord_logit_model_income_refined)

ord_logit_model_income_refined2 = polr(telework_cat ~ hhincome_detailed_refined+age_refined+ education_upd+license_upd+race_category+employment , data = telework_day_person_hh, Hess = TRUE)
summary(ord_logit_model_income_refined2)

#proportional odds ratios and CI

#ci <- confint(ord_logit_model_income_refined)

#exp(cbind(OR = coef(ord_logit_model_income_refined2), ci))
exp(coef(ord_logit_model_income_refined2))


# Trip Behavior Model ----------------------------------------------------------------

#temp = trips %>% filter(personid == '1710024801')

temp_postprocess = trips %>% 
  mutate(car_trip_dist =ifelse (mode_simple == 'Drive', trip_path_distance, 0),
         car_trips = ifelse(mode_simple == 'Drive', 1, 0),
         transit_trip_dist =ifelse (mode_simple == 'Transit', trip_path_distance, 0),
         walk_bike_trip_dist =ifelse ((mode_simple == 'Bike' | mode_simple == 'Walk'), trip_path_distance, 0),
         active_trips = ifelse(mode_simple %in% c('Walk','Bike','Transit'), 1, 0),
         time_arr_upd = parse_date_time(arrival_time_hhmm, '%I:%M %p'),
         time_depart_upd = parse_date_time(depart_time_hhmm, '%I:%M %p'),
         peak_time_arr = 
           ifelse((time_arr_upd > parse_date_time("06:00:00 AM", '%I:%M:%S %p') &
                     time_arr_upd < parse_date_time("09:00:00 AM", '%I:%M:%S %p')) | (time_arr_upd > parse_date_time("03:00:00 PM", '%I:%M:%S %p') & 
                                                                                        time_arr_upd < parse_date_time("06:00:00 PM", '%I:%M:%S %p')), 1, 0),
         peak_time_depart = ifelse((time_depart_upd > parse_date_time("06:00:00 AM", '%I:%M:%S %p') & time_depart_upd < parse_date_time("09:00:00 AM", '%I:%M:%S %p')) |
                                     (time_depart_upd > parse_date_time("03:00:00 PM", '%I:%M:%S %p') & time_depart_upd < parse_date_time("06:00:00 PM", '%I:%M:%S %p')) , 1, 0),
         peak_trip = ifelse(peak_time_arr == 1 | peak_time_depart == 1,1,0)) %>% 
  group_by(person_id,daynum) %>% 
  summarise(num_trips = n(), 
            tot_dist = sum(trip_path_distance, na.rm = TRUE),
            tot_car_dist = sum(car_trip_dist, na.rm = TRUE),
            tot_transit_dist = sum(transit_trip_dist, na.rm = TRUE),
            tot_walk_bike_dist = sum(walk_bike_trip_dist, na.rm = TRUE),
            num_car_trips = sum(car_trips, na.rm = TRUE),
            num_active_trips = sum(active_trips, na.rm = TRUE),
            num_peak_trips = sum(peak_trip)
            )



model_data = telework_day_person_hh %>% 
  dplyr::select (personid, daynum, telework_cat, hhincome_broad, gender, license_upd, benefits_3) %>% 
  right_join(temp_postprocess, by = c("personid" = "person_id", "daynum")) %>% 
  mutate (telework_none = ifelse( telework_cat == 'None', 1, 0),
          telework_part_time = ifelse( (telework_cat == 'Less than 1 hr' | telework_cat == 'Part-time') , 1, 0),
          telework_ft = ifelse( telework_cat == 'Full-time or greater', 1, 0),
          transit_benefits = case_when(
            benefits_3 == "Not offered" ~ "Not offered",
            benefits_3 == "Offered, and I use" ~ "Offered, Using",
            benefits_3 == "Offered, but I don't use" ~ "Offered, not Using",
            TRUE ~ "Missing or Other or I don't know"
          )) %>% 
  filter(!is.na(telework_cat), tot_dist < 300)

model_data$telework_cat = factor(model_data$telework_cat, 
                                             levels = c("None", "Less than 1 hr", "Part-time", "Full-time or greater", ordered = FALSE))

model_data$transit_benefits = factor(model_data$transit_benefits, 
                                 levels = c("Not offered", "Offered, Using", "Offered, not Using", "Missing or Other or I don't know"))

str(model_data)
summary(model_data)

summary(model_num_trips <- glm.nb(num_trips ~ telework_part_time + telework_ft+  hhincome_broad + gender + license_upd, data = model_data))
summary(model_num_trips2 <- glm.nb(num_trips ~ telework_part_time + telework_none+  hhincome_broad + gender + license_upd, data = model_data))


summary(model_num_car_trips <- glm.nb(num_car_trips ~ telework_part_time + telework_ft+  hhincome_broad + gender + license_upd, data = model_data))

summary(model_num_active_trips <- glm.nb(num_active_trips ~ telework_part_time + telework_ft+  hhincome_broad + gender + license_upd, data = model_data))

summary(model_num_peak_trips <- glm.nb(num_peak_trips ~ telework_part_time + telework_ft+  hhincome_broad + gender + license_upd, data = model_data))
summary(model_num_peak_trips2 <- glm.nb(num_peak_trips ~ telework_none + telework_ft+  hhincome_broad + gender + license_upd, data = model_data))

summary(model_total_distance <- lm(log(1+model_data$tot_dist) ~ telework_part_time + telework_ft+  hhincome_broad + gender + license_upd+transit_benefits, data = model_data))
(exp(coef(model_total_distance))-1)*100

summary(model_total_distance_car <- lm(log(1+model_data$tot_car_dist) ~ telework_part_time + telework_ft+  hhincome_broad + gender + license_upd+transit_benefits, data = model_data))
(exp(coef(model_total_distance_car))-1)*100

summary(model_total_distance_transit <- lm(log(1+model_data$tot_transit_dist) ~ telework_part_time + telework_ft+  hhincome_broad + gender + license_upd+transit_benefits, data = model_data))
(exp(coef(model_total_distance_transit))-1)*100

summary(model_total_distance_walk_bike <- lm(log(1+model_data$tot_walk_bike_dist) ~ telework_part_time + telework_ft+  hhincome_broad + gender + license_upd+transit_benefits, data = model_data))
(exp(coef(model_total_distance_walk_bike))-1)*100

#-------------------------------------------------------------------------





