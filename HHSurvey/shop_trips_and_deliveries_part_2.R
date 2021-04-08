source('travel_survey_analysis_functions.R')
#Household Travel Survey - Shopping trips and delivery analysis

#Author: Polina Butrina, Suzanne Childress

#Analysis to-do: Trends in Shopping Trips Who is doing the deliveries; were is the distribution; shopping trip rates

# Load Libraries ----------------------------------------------------------

library(data.table)
library(tidyverse)
library(DT)
library(openxlsx)
library(odbc)
library(DBI)
library(Hmisc)


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


sql.query <- paste("SELECT * FROM HHSurvey.v_days_2017_2019_public")
days = read.dt(sql.query, 'sqlquery')


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

day_household= day_upd %>% group_by(hhid, daynum) %>%
  summarise(sum_pkg = sum(delivery_pkgs_all,na.rm = TRUE),
            sum_groc = sum(delivery_grocery_all,na.rm = TRUE),
            sum_food = sum(delivery_food_all,na.rm = TRUE),
            day_wts_2019 = first(hh_day_wt_2019)) %>% 
  mutate(sum_pkg_upd = case_when(sum_pkg == 0 ~ 0,
                                 sum_pkg > 0 ~ 1),
         sum_groc_upd = case_when(sum_groc == 0 ~ 0,
                                  sum_groc > 0 ~ 1),
         sum_food_upd = case_when(sum_food == 0 ~ 0,
                                  sum_food > 0 ~ 1)) %>%
          mutate(delivery = if_else(sum_pkg > 0 | sum_groc > 0 | sum_food > 0 , 1, 0))


hh_pkgs_2019<- day_household %>% group_by(sum_pkg_upd) %>% 
  summarise(household_deliver =sum(day_wts_2019, na.rm=TRUE))

write.table(hh_pkgs_2019, "clipboard", sep="\t")

hh_groc_2019<- day_household %>% group_by(sum_groc_upd) %>% 
  summarise(household_deliver =sum(day_wts_2019, na.rm=TRUE))

write.table(hh_groc_2019, "clipboard", sep="\t")

hh_food_2019<- day_household %>% group_by(sum_food_upd) %>% 
  summarise(household_deliver =sum(day_wts_2019, na.rm=TRUE))

write.table(hh_food_2019, "clipboard", sep="\t")

#who gets deliveries?
sql.query <- paste("SELECT * FROM HHSurvey.v_households_2017_2019")
household = read.dt(sql.query, 'sqlquery')

write.table(household %>% group_by(hh_race_category) %>% tally(), "clipboard", sep='\t')

hh_delivery = left_join(day_household,household, by = c("hhid" = "hhid"))



hh_delivery$no_vehicles= 
  with(hh_delivery,ifelse(vehicle_count =='0 (no vehicles)', 'No vehicles', 'Has vehicles')) 

#hh_delivery[sapply(hh_delivery, is.character)] <- lapply(hh_delivery[sapply(hh_delivery, is.character)], as.factor)

hh_delivery$new_inc_grp<-hh_delivery$hhincome_detailed


hh_delivery$new_inc_grp[hh_delivery$hhincome_broad=='Under $25,000'] <- 'Under $25,000'
hh_delivery$new_inc_grp[hh_delivery$hhincome_broad=="$25,000-$49,999"] <- '$25,000-$49,999'
hh_delivery$new_inc_grp[hh_delivery$hhincome_detailed== '$200,000-$249,999'] <- '$200,000+'
hh_delivery$new_inc_grp[hh_delivery$hhincome_detailed== '$250,000 or more'] <- '$200,000+'

hh_delivery$hhsize_grp <- hh_delivery$hhsize

hh_delivery$hhsize_grp[hh_delivery$hhsize=='3 people'] <- '3-4 people'
hh_delivery$hhsize_grp[hh_delivery$hhsize=='4 people'] <- '3-4 people'
hh_delivery$hhsize_grp[hh_delivery$hhsize=='5 people'] <- '5+ people'
hh_delivery$hhsize_grp[hh_delivery$hhsize=='6 people'] <- '5+ people'
hh_delivery$hhsize_grp[hh_delivery$hhsize=='7 people'] <- '5+ people'
hh_delivery$hhsize_grp[hh_delivery$hhsize=='8 people'] <- '5+ people'
hh_delivery$hhsize_grp[hh_delivery$hhsize=='9 people'] <- '5+ people'

hh_delivery$wrkr_grp <- hh_delivery$numworkers
hh_delivery$wrkr_grp[hh_delivery$wrkr_grp==4] <- 3
hh_delivery$wrkr_grp[hh_delivery$wrkr_grp==5] <- 3

hh_delivery$hh_race_black = 
  as.factor(with(hh_delivery,ifelse(hh_race_category== "African American", 'Black', 'Not Black')))

hh_delivery$hh_race_black<- relevel(hh_delivery$hh_race_black, ref = "Not Black")


hh_income_deliveries<-cross_tab_categorical(hh_delivery,'new_inc_grp', 'delivery','day_wts_2019')
write.table(hh_income_deliveries, "clipboard", sep="\t")

hh_size_deliveries<-cross_tab_categorical(hh_delivery,'hhsize_grp', 'delivery','day_wts_2019')
write.table(hh_size_deliveries, "clipboard", sep="\t")

hh_wrkrs_deliveries<-cross_tab_categorical(hh_delivery,'wrkr_grp', 'delivery','day_wts_2019')
write.table(hh_wrkrs_deliveries, "clipboard", sep="\t")

hh_race_deliveries<-cross_tab_categorical(hh_delivery,'hh_race_category', 'delivery','day_wts_2019')
write.table(hh_race_deliveries, "clipboard", sep="\t")

hh_race_black_deliveries<-cross_tab_categorical(hh_delivery,'hh_race_black', 'delivery','day_wts_2019')
write.table(hh_race_black_deliveries, "clipboard", sep="\t")

