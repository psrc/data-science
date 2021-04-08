library(data.table)
library(tidyverse)
library(DT)
library(openxlsx)
library(odbc)
library(DBI)
library(fastDummies)
library(aod)
library(BMA)
library(MASS)
library(jtools)
library(ggstance)
library(sjPlot)
library(effects)
library(dplyr)
library(DescTools)
library(stargazer)


db.connect <- function() {
  elmer_connection <- dbConnect(odbc(),
                                driver = "SQL Server",
                                server = "AWS-PROD-SQL\\SOCKEYE",
                                database = "Elmer",
                                trusted_connection = "yes"
  )
}

read.dt <- function(astring, type =c('table_name', 'sqlquery')) {
  elmer_connection <- db.connect()
  if (type == 'table_name') {
    dtelm <- dbReadTable(elmer_connection, SQL(astring))
  } else {
    dtelm <- dbGetQuery(elmer_connection, SQL(astring))
  }
  dbDisconnect(elmer_connection)
  setDT(dtelm)
}

glmOut <- function(res, file=out_file, ndigit=3, writecsv=T) {
  if (length(grep("summary", class(res)))==0) res <- summary(res)
  co <- res$coefficients
  nvar <- nrow(co)      # No. row as in summary()$coefficients
  ncoll <- ncol(co)     # No. col as in summary()$coefficients
  
  formatter <- function(x) format(round(x,ndigit),nsmall=ndigit)
  nstats <- 4           # sets the number of rows to record the coefficients           
  G <- matrix("", nrow=(nvar+nstats), ncol=(ncoll+1))       # storing data for output
  G[1,1] <- toString(res$call)
  G[(nstats+1):(nvar+nstats),1] <- rownames(co) # save rownames and colnames
  G[nstats, 2:(ncoll+1)] <- colnames(co)
  G[(nstats+1):(nvar+nstats), 2:(ncoll+1)] <- formatter(co)  # save coefficients
  
  G[1,2] <- "AIC"  # save AIC value
  G[2,2] <- res$aic
  G[1,3] <- "Residual Deviance"
  G[2,3] <- res$deviance
  G[1,4] <- "Null deviance"
  G[2,4] <- res$null.deviance
  G[1,5] <- "McFadden/Nagel PseuedoR-Squared" # save R2 value
  G[2,5] <- PseudoR2(res, c("McFadden", "Nagel")) # calculate R2
  
  print(G)
  write.csv(G, file=file, row.names=F)
}


# this data used to create the displacement index has some useful land use info by tract
displ_index_data<- 'J:/Projects/Surveys/HHTravel/Survey2019/Analysis/displacement/estimation_files/displacement_risk_estimation.csv'
displ_risk_df <- read.csv(displ_index_data)


# Read in day table, make a new field for delivery or not

dbtable.day.query<- paste("SELECT *  FROM HHSurvey.v_days_2017_2019_in_house")
day_dt<-read.dt(dbtable.day.query, 'tablename')



day_upd = day_dt %>% 
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

#since the delivery question was asked by 1 person from the household, 
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



# now join the households table to the day table so we can get demographic information
sql.query <- paste("SELECT * FROM HHSurvey.v_households_2017_2019_in_house")
hh = read.dt(sql.query, 'sqlquery')

hh_join_deliv = merge(hh, day_household , by.x='household_id', by.y='hhid')


# Do some computations on the household variables

hh_join_deliv$no_vehicles= 
  with(hh_join_deliv,ifelse(vehicle_count =='0 (no vehicles)', 'No vehicles', 'Has vehicles')) 

#hh_join_deliv[sapply(hh_join_deliv, is.character)] <- lapply(hh_join_deliv[sapply(hh_join_deliv, is.character)], as.factor)
 
hh_join_deliv$new_inc_grp<-hh_join_deliv$hhincome_detailed


hh_join_deliv$new_inc_grp[hh_join_deliv$hhincome_broad=='Under $25,000'] <- 'Under $25,000'
hh_join_deliv$new_inc_grp[hh_join_deliv$hhincome_broad=="$25,000-$49,999"] <- '$25,000-$49,999'
hh_join_deliv$new_inc_grp[hh_join_deliv$hhincome_detailed== '$200,000-$249,999'] <- '$200,000+'
hh_join_deliv$new_inc_grp[hh_join_deliv$hhincome_detailed== '$250,000 or more'] <- '$200,000+'

hh_join_deliv$hhsize_grp <- hh_join_deliv$hhsize

hh_join_deliv$hhsize_grp[hh_join_deliv$hhsize=='3 people'] <- '3+ people'
hh_join_deliv$hhsize_grp[hh_join_deliv$hhsize=='4 people'] <- '3+ people'
hh_join_deliv$hhsize_grp[hh_join_deliv$hhsize=='5 people'] <- '3+ people'
hh_join_deliv$hhsize_grp[hh_join_deliv$hhsize=='6 people'] <- '3+ people'
hh_join_deliv$hhsize_grp[hh_join_deliv$hhsize=='7 people'] <- '3+ people'
hh_join_deliv$hhsize_grp[hh_join_deliv$hhsize=='8 people'] <- '3+ people'
hh_join_deliv$hhsize_grp[hh_join_deliv$hhsize=='9 people'] <- '3+ people'


hh_join_deliv$vehicle_group= 
  with(hh_join_deliv,ifelse(vehicle_count > numadults, 'careq_gr_adults', 'cars_less_adults')) 

hh_join_deliv$hh_race_black = 
  as.factor(with(hh_join_deliv,ifelse(hh_race_category== "African American", 'Black', 'Not Black')))

hh_join_deliv$hh_race_black<- relevel(hh_join_deliv$hh_race_black, ref = "Not Black")

hh_join_deliv$rgc= 
with(hh_join_deliv,ifelse(final_home_rgcnum!= "Not RCG", 'rgc', 'not_rgc'))

hh_join_deliv$puma_factor <-as.factor(hh_join_deliv$final_home_puma10)
# Count the number of shopping trips in each household,
# join back to the table with deliveries and household information

hh_join_deliv$rent_or_not= 
  with(hh_join_deliv, ifelse(rent_own == 'Own/paying mortgage', 'Own', 'Rent'))

hh_join_deliv$sf_house<-with(hh_join_deliv,ifelse(prev_res_type == 'Single-family house (detached house)', 'Single Family House', 'Not Single Family House'))


## Let's look at all the other trips people made in their day.
sql.query <- paste("SELECT * FROM HHSurvey.v_trips_2017_2019")
trips = read.dt(sql.query, 'sqlquery')


d_shop = trips[trips$d_purp_cat == "Shop",]

shop_trip_per_hh = d_shop %>%
  #first, we have to filter the trip data where travelers_hh are missing
  filter(travelers_hh > 0, travelers_hh < 20) %>% 
  mutate(shop_trip = 1/travelers_hh) %>% 
  group_by(hhid,daynum) %>% 
  summarise(n_shop_trips = n(), weight_comb = sum(trip_wt_combined*shop_trip ))



deliv_joined_shop = left_join(hh_join_deliv,shop_trip_per_hh,  by = c("household_id" = "hhid", 
                                                                              "daynum"="daynum")) 


# put zeroes for households with no shopping trips
deliv_joined_shop = deliv_joined_shop %>% mutate(n_shop_trips_0 = replace_na(n_shop_trips, 0))

deliv_joined_shop$n_shop_trips_grp <- deliv_joined_shop$n_shop_trips_0
deliv_joined_shop$n_shop_trips_grp[deliv_joined_shop$n_shop_trips_0==0] <- '0 hh shop trips'
deliv_joined_shop$n_shop_trips_grp[deliv_joined_shop$n_shop_trips_0==1] <- '1 hh shop trips'
deliv_joined_shop$n_shop_trips_grp[deliv_joined_shop$n_shop_trips_0>1] <- '2+ hh shop trips'

# look at the number of work trips as well:


d_work= trips[trips$d_purp_cat == "Work",]

work_trip_per_hh = d_work %>%
  #first, we have to filter the trip data where travelers_hh are missing
  filter(travelers_hh > 0, travelers_hh < 20) %>% 
  mutate(work_trip = 1/travelers_hh) %>% 
  group_by(hhid,daynum) %>% 
  summarise(n_work_trips = n(), weight_comb = sum(trip_wt_combined*work_trip ))



deliv_joined_shop = left_join(deliv_joined_shop, work_trip_per_hh,  by = c("household_id" = "hhid", 
                                                                      "daynum"="daynum")) 


# put zeroes for households with no shopping trips
deliv_joined_shop = deliv_joined_shop %>% mutate(n_work_trips_0 = replace_na(n_work_trips, 0))

deliv_joined_shop$n_work_trips_grp <- deliv_joined_shop$n_work_trips_0
deliv_joined_shop$n_work_trips_grp[deliv_joined_shop$n_work_trips_0==0] <- '0 hh work trips'
deliv_joined_shop$n_work_trips_grp[deliv_joined_shop$n_work_trips_0>=1] <- '1+ hh work trips'


#look at all the trips in the household

trip_per_hh = trips%>%
  #first, we have to filter the trip data where travelers_hh are missing
  filter(travelers_hh > 0, travelers_hh < 20) %>% 
  mutate(trip = 1/travelers_hh) %>% 
  group_by(hhid,daynum) %>% 
  summarise(n_trips = n(), weight_comb = sum(trip_wt_combined*trip ))



deliv_joined_shop = left_join(deliv_joined_shop, trip_per_hh,  by = c("household_id" = "hhid", 
                                                                           "daynum"="daynum")) 

# all trips in the household

# put zeroes for households with no trips
deliv_joined_shop = deliv_joined_shop %>% mutate(n_trips_0 = replace_na(n_trips, 0))

deliv_joined_shop$n_trips_grp <- deliv_joined_shop$n_trips_0
deliv_joined_shop$n_trips_grp[deliv_joined_shop$n_trips_0==0] <- '0 hh trips'
deliv_joined_shop$n_trips_grp[deliv_joined_shop$n_trips_0>=1 & deliv_joined_shop$n_trips_0<=4] <- '1-4 hh trips'
deliv_joined_shop$n_trips_grp[deliv_joined_shop$n_trips_0>4]<-'4+ hh trips'

deliv_joined_shop$has_children= 
  with(deliv_joined_shop,ifelse(numchildren>=1, 'children', 'no children')) 

deliv_joined_shop$wrker_group='no workers'
deliv_joined_shop$wrker_group[deliv_joined_shop$numworkers>0]<-'are workers'


#join households to some 
deliv_joined_shop$census_2010_tract <- as.character(deliv_joined_shop$final_home_tract)
displ_risk_df$GEOID <- as.character(displ_risk_df$GEOID)
deliv_lu<- merge(deliv_joined_shop,displ_risk_df, by.x='census_2010_tract', by.y='GEOID', all.x=TRUE)
deliv_lu$ln_dist_super= log(1+deliv_lu$dist_super)

deliver<-glm(delivery~ no_vehicles+hhsize_grp+n_shop_trips_grp+wrker_group+new_inc_grp+seattle_home+
               ln_jobs_auto_30+hh_race_black,
                   data=deliv_lu,
                    family = 'binomial')


summary(deliver, correlation= TRUE, family = 'binomial')

glmOut(deliver, 'C:/Users/SChildress/Documents/GitHub/data-science/HHSurvey/simple_delivery_model.csv')



stargazer(deliver, type= 'text', out='C:/Users/SChildress/Documents/GitHub/travel-studies/2019/analysis/deliver_model.txt')

PseudoR2(deliver, c("McFadden", "Nagel"))
#https://cran.r-project.org/web/packages/jtools/vignettes/summ.html#effect_plot

plot_summs(deliver, scale = TRUE)
 




