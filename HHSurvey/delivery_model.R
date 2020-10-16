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


got_delivery<-function(column_name){
  ifelse(((column_name!='0 (none)') & (column_name!= 'No')),
         1, 0)
}



dbtable.day.query<- paste("SELECT *  FROM HHSurvey.v_days_2017_2019_in_house")
day_dt<-read.dt(dbtable.day.query, 'tablename')

day_dt$any_delivery<-0
hh_day_dt<-day_dt %>%
  group_by(hhid) %>%
  filter(!is.na(deliver_package)|!is.na(delivery_pkgs_freq))


#parcels <- read.csv('C:/Users/SChildress/Documents/HHSurvey/displace_estimate/buffered_parcels.txt', sep= ' ')

day_names<-names(hh_day_dt)

hh_day_deliver<-
  hh_day_dt%>% dplyr::mutate_at(vars(starts_with('deliver')), funs(replace_na(., 'No')))

hh_day_deliver<-
  hh_day_deliver%>% dplyr::mutate_at(vars(starts_with('deliver')), funs(got_delivery(.)))
         
#there has to be a better way to do this.
hh_day_deliver<-hh_day_deliver%>% mutate(any_delivery= ifelse(delivery_pkgs_freq>0|
                                                              delivery_food_freq>0|
                                                              delivery_grocery_freq>0|
                                                              delivery_work_freq>0|
                                                              deliver_package>0|
                                                              deliver_food>0|
                                                              deliver_grocery>0|
                                                              deliver_work>0,1,0))
                                                                

#days_parcels<-merge(day_dt, parcels, by.x='final_home_parcel_dim_id', by.y='parcelid')
hh_day_deliver[sapply(hh_day_deliver, is.character)] <- lapply(hh_day_deliver[sapply(hh_day_deliver, is.character)], as.factor)


deliver<-glm(any_delivery~ hhincome_broad+hhsize,
                   data=hh_day_deliver,
                    family = 'binomial')


summary(deliver, correlation= TRUE, family = 'binomial')





glmOut(displ_logit)

PseudoR2(displ_logit, c("McFadden", "Nagel"))
#https://cran.r-project.org/web/packages/jtools/vignettes/summ.html#effect_plot
 
dbtable.parcel.query<- paste("SELECT census_2010_block_group, city_name FROM small_areas.parcel_dim")
block_group_city<-read.dt(dbtable.parcel.query, 'query')

block_group_city_one <- block_group_city %>% group_by(census_2010_block_group)%>%
  summarise(city = first(na.omit(city_name)))
  
rm(block_group_city)

# Now Simulate


  
#https://www.rdocumentation.org/packages/Ecfun/versions/0.2-2/topics/simulate.glm
#https://www2.census.gov/programs-surveys/acs/tech_docs/pums/data_dict/PUMS_Data_Dictionary_2014-2018.pdf
syn_pop_hh= read.csv('C:/Users/SChildress/Documents/GitHub/data-science/HHSurvey/estimation_displace/final_adjusted_synthetic_households.csv')
syn_pop_person=read.csv('C:/Users/SChildress/Documents/GitHub/data-science/HHSurvey/estimation_displace/final_adjusted_synthetic_persons.csv')

# Join Households and Persons
hh_pers <- merge(syn_pop_hh, syn_pop_person, by='household_id', all=FALSE)

# filter to movers only

movers <- hh_pers %>% filter(MV==1|MV==2|MV==3)
#hhid
#HINCP

movers_coded<-movers %>% mutate(hhincome_mrbroad=case_when(HINCP<10000 ~ "Under $10,000",
                                              (HINCP>=10000 & HINCP<25000) ~ "$10,000-$24,999",
                                              (HINCP>=25000 & HINCP<100000) ~ "25,000-$99,999",
                                              (HINCP>=100000 & HINCP<150000) ~ "$100,000-$149,999",
                                              (HINCP>=150000 & HINCP<200000) ~ "$150,000-$199,999",
                                              (HINCP>=200000) ~ "$200,000+"))


#agep
# define age variable
movers_coded<-movers_coded %>% mutate(age_cat_narrow=case_when(agep<18 ~ "Persons under 18",
                                                             (agep>=18 & agep<35) ~ "Persons 18-34 years",
                                                             (agep>=35 & agep<65) ~ "Persons 35-64 years",
                                                             (agep>=65 ~ "Persons 65+"))) %>%  
                          group_by(household_id) %>%  # group by household to create household ages
                          mutate(hh_age = case_when(
                                        any(age_cat_narrow == "Persons under 18") ~ "Household with children",
                                        any(age_cat_narrow == "Persons 65+") ~ "Household age 65+",
                                        any(age_cat_narrow == "Persons 35-64 years") ~ "Household age 35-64",
                                        TRUE ~ "Household excl. age 18-34"))
                          


movers_coded$is_adult = 
  with(movers_coded,ifelse(agep>=18, 'adult', 'child'))


# this returns only records with adults, which we want anyway; also counts them
movers_coded<-movers_coded %>%
                filter(is_adult=='adult')%>%
                add_count(household_id)
                

movers_coded<-rename(movers_coded, numadults=n)

movers_coded$vehicle_group= 
  with(movers_coded,ifelse(VEH > numadults, 'careq_gr_adults', 'cars_less_adults')) 



#race

# field rac1p

# PUMS
# Recoded detailed race code
# 1 .White alone (for now I'm not splitting out hispanic-fix later)
# 2 .Black or African American alone
# 3 .American Indian alone (code to 5)
# 4 .Alaska Native alone (code to 5)
# 5 .American Indian and Alaska Native tribes specified; or (code to 5)
# .American Indian or Alaska Native, not specified and no other
# .races
# 6 .Asian alone (code to 3)
# 7 .Native Hawaiian and Other Pacific Islander alone (code to 5)
# 8 .Some Other Race alone (code to 5)
# 9 .Two or More Races (code to 5)
# need to code to 2"African American" 3"Asian" 1"White Only" 4"Hispanic" 9"Missing" 5"Other"
                
movers_coded$person_race_code <- as.character(movers_coded$rac1p)
movers_coded$person_race_code<-recode(movers_coded$person_race_code, "3" = "5", "4" = "5", "6" = "3", "7" ="5", "9" ="5")


# New table with only new variables for joining to the household table
hh_cat <- movers_coded %>% 
          group_by(household_id) %>% 
          summarize(hh_race_code = paste0(person_race_code, collapse = "")) # create a household race code with integer codes of all persons in household
 
hh_cat$hh_race <- case_when( # using a grep function to create household race category based on integer codes
  grepl("9", hh_cat$hh_race_code) ~ "Missing",
  grepl("5", hh_cat$hh_race_code) ~ "Other",
  grepl("1", hh_cat$hh_race_code) &
    !grepl("2", hh_cat$hh_race_code) &
    !grepl("3", hh_cat$hh_race_code) &
    !grepl("4", hh_cat$hh_race_code) ~ "White Only",
  grepl("2", hh_cat$hh_race_code) &
    !grepl("3", hh_cat$hh_race_code) &
    !grepl("4", hh_cat$hh_race_code) ~ "African American",
  grepl("3", hh_cat$hh_race_code) &
    !grepl("2", hh_cat$hh_race_code) &
    !grepl("4", hh_cat$hh_race_code) ~ "Asian",
  grepl("4", hh_cat$hh_race_code) &
    !grepl("2", hh_cat$hh_race_code) &
    !grepl("3", hh_cat$hh_race_code) ~ "Hispanic",
  TRUE ~ "Other" # here all household codes not found in the above definitions receive "Other"
)


movers_coded_w_race<- merge(movers_coded, hh_cat, by = 'household_id')

hh_movers <- movers_coded_w_race%>% 
                  group_by(household_id) %>%
                  slice(n=1)
 


hh_movers$hh_broad_age<-as.character(hh_movers$hh_age)
hh_movers$hh_broad_age[hh_movers$hh_age== 'Household with children']<-'HH age 3564 or chil'
hh_movers$hh_broad_age[hh_movers$hh_age== 'Household age 35-64']<-'HH age 3564 or chil'

#new race category based on hh_race
hh_movers$hh_race_upd = 
  with(hh_movers,ifelse(hh_race == "White", 'White', 'POC/Other'))

hh_movers$hh_race_asian = 
  with(hh_movers,ifelse(hh_race == "Asian", 'Asian', 'non-Asian/White/Other'))

hh_movers$hh_race_poc = 
  with(hh_movers,ifelse(hh_race == "Non-Asian POC", 'Non-Asian POC', 'Asian/White/Other'))

hh_movers$hh_race_other = 
  with(hh_movers,ifelse(hh_race == "Other", 'Other', 'Asian/POC/White'))


# join the household movers over to the demographic info

hh_movers$census_tract_id <- as.character(hh_movers$census_tract_id.x)
displ_risk_df<-displ_risk_df %>% 
                           mutate(tract_short =str_sub(GEOID,-5,-1))
hh_movers_geo <- merge(hh_movers, displ_risk_df, by.x= 'census_tract_id', by.y='tract_short')

hh_movers_geo$census_2010_block_group_id <- as.character(hh_movers_geo$census_2010_block_group_id.x)
block_group_city_one$census_2010_block_group<- as.character(block_group_city_one$census_2010_block_group)
hh_movers_geo <- merge(hh_movers_geo,block_group_city_one, by.x= 'census_2010_block_group_id ', by.y='census_2010_block_group')
hh_movers_geo<-merge(hh_movers_geo, housing_policy, by.x='city', by.y='Jurisdiction')
hh_movers_geo<-merge(hh_movers_geo, acs_rent_inc, by.x='census_tract_id', by.y='GEOID10')
#+Percent.50K..100K+DBP+PP

simulate_displace<-predict(displ_logit, newdata=hh_movers_geo, type='response')

# rent_or_not
