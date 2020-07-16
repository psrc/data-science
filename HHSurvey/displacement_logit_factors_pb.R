# You will probably need to install a few libraries to get this to work.
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


#The codebook is checked in with these code files, named Combined_Codebook_022020.xlsx


################# Input Data File Reading
# This file contains information by Census Tract such as percent of households https://www.psrc.org/displacement-risk-mapping
# in poverty, coming from the displacement risk analysis work.
# it is checked in on github. You will need to point this variable to where it is
# on your computer.
displ_index_data<- 'C:/Users/pbutrina/Documents/GitHub/data-science/HHSurvey/displacement_risk_estimation.csv'

# This commented out file contains very detailed information about parcels.  For example,
# it contains information for each parcel about the number of jobs within a half mile.
# It is nearly 1 GB. You may wish to move this file locally for speed reasons.
parcel_data<- 'C:/Users/pbutrina/Desktop/buffered_parcels.txt'
# I've moved my locally, as you can see:
#parcel_data <- 'C:/Users/SChildress/Documents/HHSurvey/displace_estimate/buffered_parcels.dat'

## Read person-displacement data from Elmer, other travel survey data as well
db.connect <- function() {
  elmer_connection <- dbConnect(odbc(),
                                driver = "SQL Server",
                                server = "AWS-PROD-SQL\\COHO",
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


dbtable.person.query<- paste("SELECT *  FROM HHSurvey.v_persons_2017_2019_displace_estimation")
person_dt<-read.dt(dbtable.person.query, 'tablename')
displ_risk_df <- read.csv(displ_index_data)
parcel_df<-read.table(parcel_data, header=TRUE, sep='')

#person_dt<-data.table(person_dt)

#first calculate age and race variables across household members
# so group people by household
# calculate if they have any people of color, people over 65
# Create a person table narrowed to age and race fields

person_lt <- person_dt %>% 
  select(household_id,
         person_id,
         age,
         age_category,
         starts_with("race_")
  ) #%>% 
  mutate(age_cat_narrow = case_when(
    age %in% c("Under 5 years old", "5-11 years", "12-15 years", "16-17 years")
    ~ "Persons under 18",
    age %in% c("18-24 years", "25-34 years")
    ~ "Persons 18-34 years",
    age %in% c("35-44 years", "45-54 years", "55-64 years")
    ~ "Persons 35-64 years",
    age %in% c("65-74 years", "75-84 years", "85 or years older")
    ~ "Persons 65+"
  ),
  race_cat_broad = case_when(
    race_category == "White Only"
    ~ "White",
    race_category == "African-American, Hispanic, Multiracial, and Other"
    ~ "POC",
    race_category == "Asian Only" ~ "Asian",
    race_category == "Children or missing" & age_cat_narrow == "Persons under 18"
    ~ "Children",
    race_category == "Children or missing" & age_cat_narrow != "Persons under 18"
    ~ "Missing"
  )) %>% 
  group_by(household_id) %>% 
  mutate(hh_age = case_when(
    any(age_cat_narrow == "Persons under 18")
    ~ "Household with children",
    any(age_cat_narrow == "Persons 65+")
    ~ "Household age 65+",
    any(age_cat_narrow == "Persons 35-64 years")
    ~ "Household age 35-64",
    TRUE ~ "Household excl. age 18-34"
  ),
  hh_race_sep = case_when(
    all(race_cat_broad == "POC") | all(race_cat_broad %in% c("POC", "Children"))
    ~ "POC Only",
    all(race_cat_broad == "Asian") | all(race_cat_broad %in% c("Asian", "Children"))
    ~ "Asian Only",
    any(race_cat_broad == "White") & any(race_cat_broad == "Asian")
    ~ "Asian & White",
    any(race_cat_broad == "White") & any(race_cat_broad == "POC")
    ~ "POC & White",
    any(race_cat_broad == "Asian") & any(race_cat_broad == "POC")
    ~ "Asian & POC",
    all(race_cat_broad == "White") | all(race_cat_broad %in% c("White", "Children"))
    ~ "White Only",
    any(race_cat_broad == "Missing")
    ~ "Missing" 
  ),
  hh_race = case_when(
    all(race_cat_broad == "POC") | all(race_cat_broad %in% c("POC", "Children"))
    ~ "Non-Asian POC",
    all(race_cat_broad == "Asian") | all(race_cat_broad %in% c("Asian", "Children"))
    ~ "Asian",
    any(race_cat_broad == "White") & any(race_cat_broad == "Asian")
    ~ "Asian",
    any(race_cat_broad == "White") & any(race_cat_broad == "POC")
    ~ "Non-Asian POC",
    any(race_cat_broad == "Asian") & any(race_cat_broad == "POC")
    ~ "Other",
    all(race_cat_broad == "White") | all(race_cat_broad %in% c("White", "Children"))
    ~ "White",
    any(race_cat_broad == "Missing")
    ~ "Other"
  )) %>% 
  ungroup()


person_dt[,('hh_any_older'):= lapply(.SD, function(x) ifelse(any(.SD!='65 years+'), 'hh_any_65p', 'hh_not_all_65p')), .SDcols='age_category', by=hhid]
person_dt[,('hh_has_children'):= lapply(.SD, function(x) ifelse(any(.SD=='Under 18 years'), 'hh_has_children', 'hh_no_children')), .SDcols='age_category', by=hhid]

missing_codes <- c('Missing: Technical Error', 'Missing: Non-response', 
                   'Missing: Skip logic', 'Children or missing')

#Identifying displaced households
res_factors<-c("prev_res_factors_forced", "prev_res_factors_housing_cost","prev_res_factors_income_change",
               "prev_res_factors_community_change")

# remove missing data
for(factor in res_factors){
  for(missing in missing_codes){
    person_dt<- subset(person_dt, get(res_factors) != missing)
  }
}

person_dt<-drop_na(person_dt, res_factors)

person_dt$displaced = 0

# switch over to using df syntax for simplicity
person_df <- setDF(person_dt)

# defining the displacement variable
for (factor in res_factors){
  dummy_name<- paste(factor, ' dummy')
  print(dummy_name)
  person_df[person_df[factor]=='Selected', 'displaced']<-1
  
}





# Joining the person data to census tract and parcel-based land use data
#prev_home_taz_2010
person_df$census_2010_tract <- as.character(person_df$census_2010_tract)
person_df_dis <- merge(person_df,displ_risk_df, by.x='census_2010_tract', by.y='GEOID', all.x=TRUE)
# a list of parcel -based variables I'd like to try in the model, there are more on the file
parcel_based_vars<-c('hh_2', 'stugrd_2', 'stuhgh_2', 'stuuni_2', 'empedu_2', 'empfoo_2', 'empgov_2', 'empind_2',
                      'empmed_2', 'empofc_2', 'empret_2', 'empsvc_2', 'emptot_2', 'ppricdy2', 'pprichr2',
                     'tstops_2', 'nparks_2', 'aparks_2', 'dist_lbus', 'dist_ebus', 'dist_crt', 'dist_fry',
                      'dist_lrt')

person_df_dis$census_2010_tract <- as.character(person_df$census_2010_tract)

person_df_dis$parcel_id <- as.character(person_df_dis$parcel_id)
parcel_df$parcelid <- as.character(parcel_df$parcelid)
person_df_dis_parcel<- merge(person_df_dis, parcel_df, by.x='parcel_id', by.y='parcelid')
 
# #free up space because the parcel file is huge
rm(parcel_df)
# 
person_df_dis_parcel[parcel_based_vars] <- lapply(person_df_dis_parcel[parcel_based_vars], function(x) log(1+x))



# There are over a hundred variables on the dataframe- just limit it to potential variables
vars_to_consider <- c('displaced', 'hh_all_people_of_color', 'hh_any_older', 'hh_has_children',"nonwhite","poor_english","no_bachelors","rent","cost_burdened", 
                      "severe_cost_burdened","poverty_200"	,
                      "ln_jobs_auto_30", "ln_jobs_transit_45", "transit_qt_mile","transit_2025_half",
                       "dist_super", "dist_pharm", "dist_rest","dist_park.x",	"dist_school",
                      "prox_high_inc",	"at_risk_du","voting",
                      'displaced', "hhincome_broad", 'race_category', 'education', 'age',
                      'age_category', 'numchildren', 'numadults', 'numworkers','lifecycle','prev_rent_own',
                      'prev_res_type','hhincome_detailed','res_dur', 'hhsize',
                      'vehicle_count', 'student', 'license','age_category', 'city_name', 'growth_center_name',
                      'hh_2', 'stugrd_2', 'stuhgh_2', 'stuuni_2', 'empedu_2', 'empfoo_2', 'empgov_2', 'empind_2',
                      'empmed_2', 'empofc_2', 'empret_2', 'empsvc_2', 'emptot_2', 'ppricdy2', 'pprichr2',
                      'tstops_2', 'nparks_2', 'aparks_2', 'dist_lbus', 'dist_ebus', 'dist_crt', 'dist_fry',
                      'dist_lrt')


person_df_dis_sm <-person_df_dis_parcel[vars_to_consider]

################# variable aggregations and transformations




person_df_dis_sm$college<- with(person_df_dis_sm,ifelse(education %in% c('Bachelor degree',
                                                                         'Graduate/post-graduate degree'), 'college', 'no_college'))
person_df_dis_sm$vehicle_group= 
with(person_df_dis_sm,ifelse(vehicle_count > numadults, 'careq_gr_adults', 'cars_less_adults')) 
person_df_dis_sm$rent_or_not= 
  with(person_df_dis_sm,ifelse(prev_rent_own == 'Rent', 'Rent', 'Not Rent'))

person_df_dis_sm$seattle= 
  with(person_df_dis_sm,ifelse(city_name=='Seattle', 'Seattle', 'Not Seattle')) 

person_df_dis_sm$rgc= 
  with(person_df_dis_sm,ifelse(growth_center_name!='', 'rgc', 'not_rgc'))


person_df_dis_sm$sf_house<-with(person_df_dis_sm,ifelse(prev_res_type == 'Single-family house (detached house)', 'Single Family House', 'Not Single Family House'))

person_df_dis_sm$has_children= 
  with(person_df_dis_sm,ifelse(numchildren>=1, 'children', 'no children')) 

person_df_dis_sm$wrker_group= 
         with(person_df_dis_sm,ifelse(numworkers==0, 'no workers', 'are workers'))

person_df_dis_sm$size_group= 
  with(person_df_dis_sm,ifelse(hhsize>=3, 'hhsize_3ormore', 'hhsize_2orless'))

person_df_dis_sm$age_group= 
  with(person_df_dis_sm,ifelse(age_category=='65 years+', '65+ years', 'less than 65'))

person_df_dis_sm$moved_lst_yr= 
  with(person_df_dis_sm,ifelse(res_dur=='Less than a year', 'Moved Last Year', 'Moved 1-5 years ago'))

person_df_dis_sm$hhincome_mrbroad <- person_df_dis_sm$hhincome_broad
#person_df_dis_sm$hhincome_mrbroad[person_df_dis_sm$hhincome_broad== 'Prefer not to answer']<-'100,000-$149,999'
person_df_dis_sm$hhincome_mrbroad[person_df_dis_sm$hhincome_broad== '$25,000-$49,999']<-'25,000-$99,999'
person_df_dis_sm$hhincome_mrbroad[person_df_dis_sm$hhincome_broad== '$50,000-$74,999']<-'25,000-$99,999'
person_df_dis_sm$hhincome_mrbroad[person_df_dis_sm$hhincome_broad== '$75,000-$99,999']<-'25,000-$99,999'
person_df_dis_sm$hhincome_mrbroad[person_df_dis_sm$hhincome_broad== '$100,000 or more'] <- '$100,000 or more/Prefer not to answer'
person_df_dis_sm$hhincome_mrbroad[person_df_dis_sm$hhincome_broad== 'Prefer not to answer'] <- '$100,000 or more/Prefer not to answer'

person_df_dis_sm$dist_prem_bus<-pmin(person_df_dis_sm$dist_ebus, person_df_dis_sm$dist_fry, person_df_dis_sm$dist_lrt)
person_df_dis_sm$dist_bus<-pmin(person_df_dis_sm$dist_lbus,person_df_dis_sm$dist_ebus, person_df_dis_sm$dist_fry, person_df_dis_sm$dist_lrt)

person_df_dis_sm[sapply(person_df_dis_sm, is.character)] <- lapply(person_df_dis_sm[sapply(person_df_dis_sm, is.character)], as.factor)

# Variables to Try in the Model Fitting Below
less_vars<-c('displaced', "hhincome_mrbroad", 'hh_all_people_of_color', 
            'rent_or_not',
             'vehicle_group', 'size_group',
            'seattle',
            'dist_lrt', 'race_category', 'lifecycle', 'hh_has_children')
 
x_sm<-less_vars[!less_vars %in% "displaced"]
person_df_ls<-person_df_dis_sm[less_vars]
x_sm<-c(x_sm)

# Estimate the model

displ_logit<-glm(displaced ~ hh_all_people_of_color+hhincome_mrbroad+rent_or_not+vehicle_group+seattle+
                 dist_lrt ,data=person_df_ls,
                 family = 'binomial')
summary(displ_logit, correlation= TRUE)

#https://cran.r-project.org/web/packages/jtools/vignettes/summ.html#effect_plot

plot_summs(displ_logit, scale = TRUE)

#https://towardsdatascience.com/visualizing-models-101-using-r-c7c937fc5f04

#plot_model(displ_logit, transform = NULL, show.values = TRUE, axis.labels = '', value.offset = .4)
#effect_plot(plot(allEffects(displ_logit))displ_logit, pred = poor_english, interval = TRUE, plot.points = TRUE)
#looks nonlinear a bit

#effect_plot(displ_logit, pred = white, interval = TRUE, plot.points = TRUE)

#plot(predictorEffects(displ_logit))

# Trying the bma library, Hana recommended it, but I'm confused about how to use it.
# x<-person_df_ls[, !names(person_df_ls) %in% c('displaced')]
# y<-person_df_ls$displaced
# 
# glm.out <- bic.glm(x, y, strict = FALSE, OR = 20,
#                         glm.family="binomial", factor.type=TRUE)
# summary(glm.out)
# imageplot.bma(glm.out)
