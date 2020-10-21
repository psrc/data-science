#Household Travel Survey - Shopping trips and delivery analysis

#Author: Polina Butrina

#Analysis to-do: Trends in Shopping Trips Who is doing the deliveries; were is the distribution; shopping trip rates

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

# The following variables were identified as relevant to shopping and deliveries:
#   Shopping:
# * Teleshop time on travel day
# * Destination/origin purpose is shop (d_purp_cat (or o_purp_cat) = "Shop")
# Delivery:
# * deliver_package (day) - Packages delivered on travel day
# * deliver_grocery (day) - Groceries delivered on travel day
# * deliver_food (day) - Food/meal prep delivered on travel day
# * deliver_work (day) - Services delivered on travel day
# * delivery_food_freq (day) - Number of food/meal prep deliveries on travel day
# * delivery_grocery_freq (day) - Number of grocery deliveries on travel day
# * delivery_pkgs_freq (day) - Number of package deliveries on travel day
# * delivery_work_freq (day) - Number of service deliveries on travel day

# Trip analysis - selecting shopping trips =================================
sql.query <- paste("SELECT * FROM HHSurvey.v_trips_2017_2019_public")
trips = read.dt(sql.query, 'sqlquery')


d_shop = trips[trips$d_purp_cat == "Shop",]
o_shop = trips[trips$o_purp_cat == "Shop",]


#loading day table

sql.query <- paste("SELECT * FROM HHSurvey.v_days_2017_2019_public")
days = read.dt(sql.query, 'sqlquery')

#there are shopping trips per person per day

sum(d_shop$trip_wt_combined)/sum(days$hh_day_wt_combined)

#shopping rate per household per day
# to calculate household shopping trip rate, we need to know how many shopping trips were done per each household.
#in some cases, there are multiple people in the household doing a shopping trip (in trip table it will be separate trips)
#to count multi-hh member shopping trips as one trip, I decided to create a new weight that we will use to adjust trip weight


shop_trip_per_hh = d_shop %>%
  #first, we have to filter the trip data where travelers_hh are missing
  filter(travelers_hh > 0, travelers_hh < 20) %>% 
  mutate(shop_trip = if_else(d_purp_cat == "Shop", 1/travelers_hh,0)) %>% 
  group_by(hhid) %>% 
  summarise(n = n(), weight_comb = sum(trip_wt_combined*shop_trip ))

#in the denominator we will need to have a number of all households in the region

days_hh_weight = days %>% group_by(hhid) %>% slice(which.max(hh_wt_combined))

sum(shop_trip_per_hh$weight_comb)/sum(days_hh_weight$hh_wt_combined)



# Socio-economic characteristics of people who went shopping 

#join shopping trips and person view
sql.query <- paste("SELECT * FROM HHSurvey.v_households_2017_2019_public")
household = read.dt(sql.query, 'sqlquery')

hh_shopping_join = d_shop %>% left_join(household, by = c("hhid" = "hhid") )

#adding a shopping trip weight for a household
hh_shopping_join = hh_shopping_join %>% 
  mutate(shop_trip = if_else(d_purp_cat == "Shop", 1/travelers_hh,0))

#join days and household

hh_days = merge(days, household, by.x='hhid', by.y='hhid')

#income

shop_trips_income = hh_shopping_join %>% 
                    group_by(hhincome_broad) %>% 
                    summarise(n=n(),sum_wt_comb = sum(trip_wt_combined * shop_trip)) %>% 
                    mutate(perc_comb = sum_wt_comb/sum(sum_wt_comb)*100) %>% 
                    ungroup() %>%  mutate(MOE=z*(p_MOE/sum(n))^(1/2)*100) %>% arrange(desc(perc_comb))


person_day_income <- hh_days %>% group_by(hhincome_broad) %>%
  summarise(n=n(), day_combined = sum(hh_day_wt_combined.x))

day_shop_trips_income <- merge(shop_trips_income, person_day_income, by.x = 'hhincome_broad', by.y = 'hhincome_broad')
day_shop_trips_income %>% mutate(trip_rate = sum_wt_comb/day_combined) %>% select(hhincome_broad,trip_rate)



#hh size

shop_trips_hhsize = hh_shopping_join %>% 
  group_by(hhsize) %>% 
  summarise(n=n(),sum_wt_comb = sum(trip_wt_combined * shop_trip)) %>% 
  mutate(perc_comb = sum_wt_comb/sum(sum_wt_comb)*100) %>% 
  ungroup() %>%  mutate(MOE=z*(p_MOE/sum(n))^(1/2)*100)


person_day_hhsize <- hh_days %>% group_by(hhsize) %>%
  summarise(n=n(), day_combined = sum(hh_day_wt_combined.x))

day_shop_trips_hhsize <- merge(shop_trips_hhsize, person_day_hhsize, by.x = 'hhsize',by.y = 'hhsize')
day_shop_trips_hhsize %>% mutate(trip_rate = sum_wt_comb/day_combined) %>% select(hhsize,trip_rate)


# Delivery analysis - selecting people that received deliveries =================================

sql.query <- paste("SELECT * FROM HHSurvey.v_households_2017_2019_public")
hh = read.dt(sql.query, 'sqlquery')

day_upd = days %>% 
  mutate(delivery_pkgs_freq_upd = case_when(delivery_pkgs_freq == "0 (none)" ~ 0,
                                           delivery_pkgs_freq == "1" ~ 1,
                                           delivery_pkgs_freq == "2" ~ 1,
                                           delivery_pkgs_freq == "3" ~ 1,
                                           delivery_pkgs_freq == "4" ~ 1,
                                           delivery_pkgs_freq == "5 or more" ~ 1)) %>% 
  mutate(delivery_pkgs_all = case_when(delivery_pkgs_freq_upd == 1 ~ 1,
                                  delivery_pkgs_freq_upd == 0 ~ 0,
                                  deliver_package == "Yes" ~ 1,
                                  deliver_package == "No" ~ 0)) %>% 
  
  mutate(delivery_grocery_freq_upd = case_when(delivery_grocery_freq == "0 (none)" ~ 0,
                                               delivery_grocery_freq == "1" ~ 1,
                                               delivery_grocery_freq == "2" ~ 1,
                                               delivery_grocery_freq == "3" ~ 1,
                                               delivery_grocery_freq == "4" ~ 1,
                                               delivery_grocery_freq == "5 or more" ~ 1)) %>% 
  mutate(delivery_grocery_all = case_when(delivery_grocery_freq_upd == 1 ~ 1,
                                  delivery_grocery_freq_upd == 0 ~ 0,
                                  deliver_grocery == "Yes" ~ 1,
                                  deliver_grocery == "No" ~ 0)) %>% 
  
  mutate(delivery_food_freq_upd = case_when(delivery_food_freq == "0 (none)" ~ 0,
                                               delivery_food_freq == "1" ~ 1,
                                               delivery_food_freq == "2" ~ 1,
                                               delivery_food_freq == "3" ~ 1,
                                               delivery_food_freq == "4" ~ 1,
                                               delivery_food_freq == "5 or more" ~ 1)) %>% 
  mutate(delivery_food_all = case_when(delivery_food_freq_upd == 1 ~ 1,
                                          delivery_food_freq_upd == 0 ~ 0,
                                          deliver_food == "Yes" ~ 1,
                                          deliver_food == "No" ~ 0)) %>% 
  mutate(delivery = if_else(delivery_pkgs_all > 0 | delivery_grocery_all > 0 | delivery_food_all > 0 , 1, 0))

#since the delivery question was asked with 1 person from the household, 
# we need to group by hhid. Another reason to group by hhid is
# rMove respondents were asked to report # of deliveries received each day

day_household = day_upd %>% group_by(hhid) %>%
  summarise(sum_pkg = sum(delivery_pkgs_all,na.rm = TRUE),
            sum_groc = sum(delivery_grocery_all,na.rm = TRUE),
            sum_food = sum(delivery_food_all,na.rm = TRUE) ) %>% 
  #mutate(sum_pkg_upd = case_when(sum_pkg == 0 ~ 0,
                                # sum_pkg > 0 ~ 1),
  #       sum_groc_upd = case_when(sum_groc == 0 ~ 0,
   #                               sum_groc > 0 ~ 1),
    #     sum_food_upd = case_when(sum_food == 0 ~ 0,
    #                              sum_food > 0 ~ 1)) %>% 
  mutate(delivery = if_else(sum_pkg > 0 | sum_groc > 0 | sum_food > 0 , 1, 0)) %>% 
  select(hhid, delivery)

hh_shopping_join_deliv = left_join(hh_shopping_join, day_household , by = c("hhid" = "hhid")) 

#check the weights
sum(day_hh_join$hh_wt_combined)


#if hh received delivery or not

shop_trips_delivery = hh_shopping_join_deliv %>% 
  group_by(delivery) %>% 
  summarise(n=n(),sum_wt_comb = sum(trip_wt_combined * shop_trip)) %>% 
  mutate(perc_comb = sum_wt_comb/sum(sum_wt_comb)*100) %>% 
  ungroup() %>%  mutate(MOE=z*(p_MOE/sum(n))^(1/2)*100)


person_day_delivery <- day_upd %>% group_by(delivery) %>%
  summarise(n=n(), day_combined = sum(hh_day_wt_combined))

day_shop_trips_delivery <- merge(shop_trips_delivery, person_day_delivery, by = 'delivery')
day_shop_trips_delivery %>% mutate(trip_rate = sum_wt_comb/day_combined) %>% select(delivery,trip_rate)



