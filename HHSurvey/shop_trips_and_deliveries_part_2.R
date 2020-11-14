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

#loading day table

sql.query <- paste("SELECT * FROM HHSurvey.v_days_2017_2019_public")
days = read.dt(sql.query, 'sqlquery')


sum(d_shop$trip_wt_combined)
# 2.28 million person shopping trips

sum(d_shop$trip_wt_combined)/sum(days$hh_day_wt_combined)
# 0.56 person shop trips per day


shop_trip_per_hh = d_shop %>%
  #first, we have to filter the trip data where travelers_hh are missing
  filter(travelers_hh > 0, travelers_hh < 20) %>% 
  mutate(shop_trip = 1/travelers_hh) %>% 
  group_by(hhid,daynum) %>% 
  summarise(n = n(), weight_comb = sum(trip_wt_combined*shop_trip ))

sum(shop_trip_per_hh$weight_comb)
#1.7 million household shopping trips



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

day_household_2 = day_upd %>% group_by(hhid, daynum) %>%
  summarise(sum_pkg = sum(delivery_pkgs_all,na.rm = TRUE),
            sum_groc = sum(delivery_grocery_all,na.rm = TRUE),
            sum_food = sum(delivery_food_all,na.rm = TRUE),
            day_wts = max(hh_day_wt_combined)) %>% 
  #mutate(sum_pkg_upd = case_when(sum_pkg == 0 ~ 0,
                                # sum_pkg > 0 ~ 1),
  #       sum_groc_upd = case_when(sum_groc == 0 ~ 0,
   #                               sum_groc > 0 ~ 1),
    #     sum_food_upd = case_when(sum_food == 0 ~ 0,
    #                              sum_food > 0 ~ 1)) %>% 
  mutate(delivery = if_else(sum_pkg > 0 | sum_groc > 0 | sum_food > 0 , 1, 0)) %>% 
  select(hhid, delivery,day_wts,daynum)

hh_tot_by_deliv_day_wt<- day_household_2 %>% group_by(delivery) %>% 
  summarise(household_deliver =sum(day_wts, na.rm=TRUE)) %>% 
  mutate(perc_comb = household_deliver/sum(household_deliver)*100)

write.csv(hh_tot_by_deliv_day_wt)


#day_household_2 has as many rows as observed household days

deliv_joined_shop_trips = left_join(day_household_2,shop_trip_per_hh,  by = c("hhid" = "hhid", 
                                                                              "daynum"="daynum")) 

# there are nas because there are some household days without shopping trips? Is that why?
# So I think we want the trip weights to be zero there?
# I think I'm using a different weight than what Polina was summing
deliv_joined_shop_trips2<-deliv_joined_shop_trips %>% dplyr::mutate(trip_wt_no_na = replace_na(weight_comb, 0))

sum(deliv_joined_shop_trips2$day_wts)
# 1.66 mill
sum(deliv_joined_shop_trips2$trip_wt_no_na)
# 1.72 mill
sum(deliv_joined_shop_trips2$trip_wt_no_na)/sum(deliv_joined_shop_trips2$day_wts)
#overall average shop trips per household 1.03 ?

deliv_shop_trips <-deliv_joined_shop_trips2 %>% group_by(delivery) %>%
  summarise(shop_trip_sum=sum(trip_wt_no_na), delivery_day_sum=sum(day_wts)) %>%
  mutate(shop_trip_rate_by_deliv= shop_trip_sum/delivery_day_sum)

# 0.988 shop trips for households with no deliveries
# 1.15 shop trips for households with deliveries


