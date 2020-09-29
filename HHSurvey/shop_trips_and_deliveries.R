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
                   'Missing: Skip logic', 'Children or missing', ' Prefer not to answer')

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
sql.query <- paste("SELECT * FROM HHSurvey.v_trips_2017_2019_in_house")
trips = read.dt(sql.query, 'sqlquery')


d_shop = trips[trips$d_purp_cat == "Shop",]
o_shop = trips[trips$o_purp_cat == "Shop",]

# What information can be interesting: 

# how frequent are shopping trips by households - 
#to address multiple household members coming to the same trip i've divided 1 to the number of household members
#going to the same trip. Question - there are some households that use multiple vehicles to go
#to the same shopping trip - shold we account for that?

#there are 0.94 shopping trips per household per day

shopping_trips_hh = trips %>% mutate(shop_trip = if_else(d_purp_cat == "Shop", 1/travelers_hh,0)) %>%
  filter(trip_wt_combined >0, travelers_hh >0, travelers_hh <20) %>%  group_by(household_id) %>% 
  summarise( n_shop_trips = sum(shop_trip), sum_comb = sum(trip_wt_combined),n_days = n_distinct(daynum)) %>% 
  mutate(shop_trips_per_day = n_shop_trips/n_days, trip_rate = shop_trips_per_day*sum_comb) %>% 
  ungroup() %>% mutate(trip_rate = sum(trip_rate)/sum(sum_comb))

#shopping rate per person per day

#there are 0.67 shopping trips per person per day

shopping_rate_all = trips %>% mutate(shop_trip = if_else(d_purp_cat == "Shop", 1,0)) %>%
  filter(trip_wt_combined >0,travelers_hh >0, travelers_hh <20) %>%  group_by(person_id) %>%
  summarise( n_shop_trips = sum(shop_trip), sum_comb = sum(trip_wt_combined),n_days = n_distinct(daynum)) %>% 
  mutate(shop_trips_per_day = n_shop_trips/n_days, trip_rate = shop_trips_per_day*sum_comb) %>% 
  ungroup() %>% mutate(trip_rate = sum(trip_rate)/sum(sum_comb)) #%>% arrange(desc(shop_trips_per_day))

describe(shopping_rate_all$shop_trips_per_day)

# what is the average distance of the shopping trip?

#analyzing raw shopping trip distance for any outliers
describe(d_shop$trip_path_distance)

#it looks like there is one outlier with a trip path distance = 1503. 
#I've checked this entry and it looks like a computational error. 
#Hense, need to remove it from the data for trip path distance analysis

dest_trip_dist = d_shop[d_shop$trip_path_distance < 1300,]

p <- ggplot(dest_trip_dist, aes(y=trip_path_distance)) + 
  geom_boxplot()
p

#do we want to account only weighted trips?
#here is analysis for weighted trips

#here we want to work with the trips that have combined weights > 0.
#Out of 12,959 trips there are 6,954 of weighted trips
#average shopping trip length is 4.8 miles

temp1 = d_shop %>% filter(trip_wt_combined >0, !is.na(trip_path_distance)) %>% group_by(trip_id) %>% 
  summarise(sum_comb = sum(trip_wt_combined),trip_path_distance=trip_path_distance) %>% 
  mutate (trip_path_distance_upd = if_else(trip_path_distance == 0, trip_path_distance+0.1,trip_path_distance ),trip_dist = trip_path_distance_upd*sum_comb) %>% 
  ungroup() %>% 
  mutate(ave_shop_trip_dist = sum(trip_dist)/sum(sum_comb) ) 

#plotting trips distance distributions- WIP
x = temp1$trip_path_distance
b = c(0,1,3,5,10,20,30,50,100,1600)
temp1$bin = .bincode(x, b, TRUE)

temp1$bin = 
  factor(temp1$bin, levels = c("1","2","3","4","5","6","7","8","9") )
m <- ggplot(temp1, aes(x = bin))
m + geom_bar(aes(weight = sum_comb), binwidth = 0.1) + ylab("freq")+xlab("trip length")


#shopping trip mode
#More than 88% of the shopping trips are made by a vehicle, where 46% of the trips made by SOV and 43% by HOV.
create_table_one_var("main_mode",d_shop,"trip")

# Socio-economic characteristics of people who went shopping 

#join shopping trips and person view
sql.query <- paste("SELECT * FROM HHSurvey.v_persons_2017_2019")
person = read.dt(sql.query, 'sqlquery')

person_shopping_join = d_shop %>% left_join(person, by = c("person_id" = "person_dim_id") )
person_trips_join = trips %>% left_join(person, by = c("person_id" = "person_dim_id") )

#income
#Of all shopping trips, 40% were made by the households with income of more than $100k, and about
# 28% were made by hh with income of $$50k-99k
#However, shopping trips account for only about 9% for hh with income $100k or more and $50k-$75k
#the highest shopping rates account for households with income under 50k

income_shopping = create_table_one_var("hhincome_broad", person_shopping_join, "person")
income_general = create_table_one_var("hhincome_broad", person_trips_join, "person")

income_shopping_rates = income_general %>%
  left_join(income_shopping, by = c("hhincome_broad" = "hhincome_broad")) %>% 
  mutate(shopping_rates = sum_wt_comb.y/sum_wt_comb.x*100) %>% 
  select(hhincome_broad, shopping_rates)

#gender

gender_shopping = create_table_one_var("gender", person_shopping_join, "person")
gender_general = create_table_one_var("gender", person_trips_join, "person")

gender_shopping_rates = gender_general %>%
  left_join(gender_shopping, by = c("gender" = "gender")) %>% 
  mutate(shopping_rates = sum_wt_comb.y/sum_wt_comb.x*100) %>% 
  select(gender, shopping_rates)


#race 
race_shopping = create_table_one_var("hh_race_category", person_shopping_join, "person")
race_general = create_table_one_var("hh_race_category", person_trips_join, "person")

race_shopping_rates = race_general %>%
  left_join(race_shopping, by = c("hh_race_category" = "hh_race_category")) %>% 
  mutate(shopping_rates = sum_wt_comb.y/sum_wt_comb.x*100) %>% 
  select(hh_race_category, shopping_rates)


#age

age_shopping = create_table_one_var("age", person_shopping_join, "person")
age_general = create_table_one_var("age", person_trips_join, "person")

age_shopping_rates = age_general %>%
  left_join(age_shopping, by = c("age" = "age")) %>% 
  mutate(shopping_rates = sum_wt_comb.y/sum_wt_comb.x*100) %>% 
  select(age, shopping_rates) %>% arrange(disc(shopping_rates))


#employment
employment_shopping = create_table_one_var("employment", person_shopping_join, "person")
employment_general = create_table_one_var("employment", person_trips_join, "person")

employment_shopping_rates = employment_general %>%
  left_join(employment_shopping, by = c("employment" = "employment")) %>% 
  mutate(shopping_rates = sum_wt_comb.y/sum_wt_comb.x*100) %>% 
  select(employment, shopping_rates) 

  

# Delivery analysis - selecting people that received deliveries =================================

sql.query <- paste("SELECT * FROM HHSurvey.v_days_2017_2019_in_house")
days = read.dt(sql.query, 'sqlquery')

sql.query <- paste("SELECT * FROM HHSurvey.v_households_2017_2019_in_house")
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
                                          deliver_food == "No" ~ 0))

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

day_hh_join = left_join(day_household, hh , by = c("hhid" = "household_id")) 
day_hh_join_deliv = day_hh_join %>% filter(delivery == 1)


#share of households that receive deliveries
day_hh_join %>% group_by(delivery) %>% 
  summarise(n=n(),sum_wt_comb = sum(hh_wt_combined,na.rm = TRUE)) %>% 
  mutate(perc_comb = sum_wt_comb/sum(sum_wt_comb)*100)

#income
income_deliv = create_table_one_var("hhincome_broad", day_hh_join_deliv, "household")
income_deliv_general = create_table_one_var("hhincome_broad", day_hh_join, "household")

income_deliv_rates = income_deliv_general %>%
  left_join(income_deliv, by = c("hhincome_broad" = "hhincome_broad")) %>% 
  mutate(deliv_rates = sum_wt_comb.y/sum_wt_comb.x*100) %>% 
  select(hhincome_broad, deliv_rates)

#race
race_deliv = create_table_one_var("hh_race_category", day_hh_join_deliv, "household")
race_deliv_general = create_table_one_var("hh_race_category", day_hh_join, "household")

race_deliv_rates = race_deliv_general %>%
  left_join(race_deliv, by = c("hh_race_category" = "hh_race_category")) %>% 
  mutate(deliv_rates = sum_wt_comb.y/sum_wt_comb.x*100) %>% 
  select(hh_race_category, deliv_rates)

#life cycle
lifecycle_deliv = create_table_one_var("lifecycle", day_hh_join_deliv, "household")
lifecycle_deliv_general = create_table_one_var("lifecycle", day_hh_join, "household")

lifecycle_deliv_rates = lifecycle_deliv_general %>%
  left_join(lifecycle_deliv, by = c("lifecycle" = "lifecycle")) %>% 
  mutate(deliv_rates = sum_wt_comb.y/sum_wt_comb.x*100) %>% 
  select(lifecycle, deliv_rates)


#Comparing households that are taking shopping trips and that are not

#it looks like households that households that are getting deliveries have a bit higher shopping trip rates


trips %>% mutate(shop_trip = if_else(d_purp_cat == "Shop", 1/travelers_hh,0)) %>%
  filter(trip_wt_combined >0, travelers_hh >0, travelers_hh <20) %>%  group_by(household_id) %>% 
  summarise( n_shop_trips = sum(shop_trip), sum_comb = sum(trip_wt_combined),n_days = n_distinct(daynum)) %>% 
  mutate(shop_trips_per_day = n_shop_trips/n_days, trip_rate = shop_trips_per_day*sum_comb) %>% 
  left_join(day_household, by = c("household_id" = "hhid")) %>% 
  #filter(delivery == 1) %>% 
  ungroup() %>%
  group_by(delivery) %>% 
  summarise(trip_rate = sum(trip_rate)/sum(sum_comb))
