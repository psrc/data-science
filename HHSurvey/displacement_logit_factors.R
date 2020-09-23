
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
library(DescTools)

#The codebook is checked in with these code files, named Combined_Codebook_022020.xlsx


################# Input Data File Reading
# This file contains information by Census Tract such as percent of households https://www.psrc.org/displacement-risk-mapping
# in poverty, coming from the displacement risk analysis work.
# it is checked in on github. You will need to point this variable to where it is
# on your computer.
displ_index_data<- 'J:/Projects/Surveys/HHTravel/Survey2019/Analysis/displacement/estimation_files/displacement_risk_estimation.csv'

# This commented out file contains very detailed information about parcels.  For example,
# it contains information for each parcel about the number of jobs within a half mile.
# It is nearly 1 GB. You may wish to move this file locally for speed reasons. This is 2018 parcel data
#parcel_data<- 'C:/Users/SChildress/Documents/HHSurvey/displace_estimate/buffered_parcels.txt'
# I've moved my locally, as you can see:
parcel_data <- 'C:/Users/SChildress/Documents/HHSurvey/displace_estimate/buffered_parcels.dat'

#add updated hh race and age variables
hh_race_age_cat = read.csv("C:/Users/SChildress/Documents/GitHub/data-science/HHSurvey/hh_race_age_categ.csv")

acs_rent_inc = read.csv("C:/Users/SChildress/Documents/HHSurvey/displace_estimate/acs_income_rent_2018.csv")

dissim<-read.xlsx("C:/Users/SChildress/Documents/HHSurvey/displace_estimate/dissimilarity_2018.xlsx")

housing_policy<-read.xlsx("C:/Users/SChildress/Documents/GitHub/data-science/HHSurvey/estimation_displace/housing_policy_city.xlsx")

movers_score = read.csv("C:/Users/SChildress/Documents/GitHub/data-science/HHSurvey/estimation_displace/movers_score2018.csv")

out_file= "C:/Users/SChildress/Documents/GitHub/data-science/HHSurvey/estimation_displace/displace_estimate_results.csv"

## Read person-displacement data from Elmer, other travel survey data as well
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

dbtable.person.query<- paste("SELECT *  FROM HHSurvey.v_persons_2017_2019_displace_estimation_2014parcels")
person_dt<-read.dt(dbtable.person.query, 'tablename')
displ_risk_df <- read.csv(displ_index_data)
parcel_df<-read.table(parcel_data, header=TRUE, sep='')

#person_dt<-data.table(person_dt)

#first calculate age and race variables across household members
# so group people by household
# calculate if they have any people of color, people over 65
# Create a person table narrowed to age and race fields


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

housing_policy[is.na(housing_policy)]<-0
housing_policy[housing_policy=='x']<-1

person_df <- merge(person_df, housing_policy, by.x='city_name', by.y='Jurisdiction')


# Joining the person data to census tract and parcel-based land use data
#prev_home_taz_2010
person_df$census_2010_tract <- as.character(person_df$census_2010_tract)
person_df_dis <- merge(person_df,displ_risk_df, by.x='census_2010_tract', by.y='GEOID', all.x=TRUE)

acs_rent_inc$GEOID10<- as.character(acs_rent_inc$GEOID10)

person_df_dis <- merge(person_df_dis,acs_rent_inc, by.x='census_2010_tract', by.y='GEOID10', all.x=TRUE )


dissim$GEOID<-as.character(dissim$GEOID)


person_df_dis <- merge(person_df_dis,dissim, by.x='census_2010_tract', by.y='GEOID', all.x=TRUE )




#a list of parcel -based variables I'd like to try in the model, there are more on the file

parcel_based_vars<-c('hh_2', 'stugrd_2', 'stuhgh_2', 'stuuni_2', 'empedu_2', 'empfoo_2', 'empgov_2', 'empind_2',
                      'empmed_2', 'empofc_2', 'empret_2', 'empsvc_2', 'emptot_2', 'ppricdy2', 'pprichr2',
                     'tstops_2', 'nparks_2', 'aparks_2', 'dist_lbus', 'dist_ebus', 'dist_crt', 'dist_fry',
                      'dist_lrt')

person_df_dis$census_2010_tract <- as.character(person_df$census_2010_tract)



person_df_dis$parcel_id <- as.character(person_df_dis$prev_home_parcel_id)
parcel_df$parcelid <- as.character(parcel_df$parcelid)
#merging by the previous residence parcel from the person table and by the parcel id in the parcel table
person_df_dis_parcel<- merge(person_df_dis, parcel_df, by.x='parcel_id', by.y='parcelid', all.x = TRUE)

movers_score$parcel<-as.character(movers_score$PSRC_ID)
person_df_dis_parcel<-merge(person_df_dis, movers_score, by.x='parcel_id', by.y='parcel')

person_df_dis_parcel$hhid <- as.character(person_df_dis_parcel$hhid)
hh_race_age_cat$household_id <- as.character(hh_race_age_cat$household_id)
person_df_dis_parcel<- merge(person_df_dis_parcel, hh_race_age_cat, by.x='hhid', by.y='household_id', all.x = TRUE)

# #free up space because the parcel file is huge
rm(parcel_df)
# 
person_df_dis_parcel[parcel_based_vars] <- lapply(person_df_dis_parcel[parcel_based_vars], function(x) log(1+x))



# There are over a hundred variables on the dataframe- just limit it to potential variables
vars_to_consider <- c('displaced','hh_any_older', 'hh_has_children',"nonwhite","poor_english","no_bachelors","rent","cost_burdened", 
                      "severe_cost_burdened","poverty_200"	, 'seattle_home',
                      "ln_jobs_auto_30", "ln_jobs_transit_45", "transit_qt_mile","transit_2025_half",
                       "dist_super", "dist_pharm", "dist_rest","dist_park.x",	"dist_school",
                      "prox_high_inc",	"at_risk_du","voting",'hhincome_detailed',
                      'displaced', "hhincome_broad", 'race_category', 'education', 'age',
                      'age_category', 'numchildren', 'numadults', 'numworkers','lifecycle','prev_rent_own',
                      'prev_res_type','hhincome_detailed','res_dur', 'hhsize',
                      'vehicle_count', 'student', 'license','age_category', 'seattle_home', 'city_name', 'growth_center_name',
                      'hh_2', 'stugrd_2', 'stuhgh_2', 'stuuni_2', 'empedu_2', 'empfoo_2', 'empgov_2', 'empind_2',
                      'empmed_2', 'empofc_2', 'empret_2', 'empsvc_2', 'emptot_2', 'ppricdy2', 'pprichr2',
                      'tstops_2', 'nparks_2', 'aparks_2', 'dist_lbus', 'dist_ebus', 'dist_crt', 'dist_fry',
                      'dist_lrt','hh_race', 'hh_age',
                      'Percent.Less.than.10K', "Percent.Less.than.25K",  "Percent.Less.than.50K",  
                      "Percent.50K..100K",    "Percent.Above.100K" ,  "Percent.Above.150K",  "Percent.Above.200K",    
                      "Median.household.income", "LN.Median.Income","Median.Rent"
                      )

vars_to_consider<-c(vars_to_consider, names(dissim),names(housing_policy))

#person_df_dis_sm <-person_df_dis_parcel[vars_to_consider]

person_df_dis_sm <-person_df_dis_parcel
################# variable aggregations and transformations




person_df_dis_sm$college<- with(person_df_dis_sm,ifelse(education %in% c('Bachelor degree',
                                                                         'Graduate/post-graduate degree'), 'college', 'no_college'))
person_df_dis_sm$vehicle_group= 
with(person_df_dis_sm,ifelse(vehicle_count > numadults, 'careq_gr_adults', 'cars_less_adults')) 

person_df_dis_sm$rent_or_not= 
  with(person_df_dis_sm,ifelse(prev_rent_own == 'Rent', 'Rent', 'Not Rent'))


# This data needs to be updated to 2018
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

person_df_dis_sm$hhincome_mrbroad <- person_df_dis_sm$hhincome_detailed
#person_df_dis_sm$hhincome_mrbroad[person_df_dis_sm$hhincome_broad== 'Prefer not to answer']<-'100,000-$149,999'
person_df_dis_sm$hhincome_mrbroad[person_df_dis_sm$hhincome_broad== '$25,000-$49,999']<-'25,000-$99,999'
person_df_dis_sm$hhincome_mrbroad[person_df_dis_sm$hhincome_broad== '$50,000-$74,999']<-'25,000-$99,999'
person_df_dis_sm$hhincome_mrbroad[person_df_dis_sm$hhincome_broad== '$75,000-$99,999']<-'25,000-$99,999'
person_df_dis_sm$hhincome_mrbroad[person_df_dis_sm$hhincome_detailed== '$200,000-$249,999'] <- '$200,000+'
person_df_dis_sm$hhincome_mrbroad[person_df_dis_sm$hhincome_detailed== '$250,000 or more'] <- '$200,000+'

person_df_dis_sm$dist_prem_bus<-pmin(person_df_dis_sm$dist_ebus, person_df_dis_sm$dist_fry, person_df_dis_sm$dist_lrt)
person_df_dis_sm$dist_bus<-pmin(person_df_dis_sm$dist_lbus,person_df_dis_sm$dist_ebus, person_df_dis_sm$dist_fry, person_df_dis_sm$dist_lrt)

person_df_dis_sm$hh_age<- as.character(person_df_dis_sm$hh_age)
person_df_dis_sm$hh_broad_age<-person_df_dis_sm$hh_age
person_df_dis_sm$hh_broad_age[person_df_dis_sm$hh_age== 'Household with children']<-'HH age 3564 or chil'
person_df_dis_sm$hh_broad_age[person_df_dis_sm$hh_age== 'Household age 35-64']<-'HH age 3564 or chil'

#new race category based on hh_race
person_df_dis_sm$hh_race_upd = 
  with(person_df_dis_sm,ifelse(hh_race == "White", 'White', 'POC/Other'))

person_df_dis_sm$hh_race_asian = 
  with(person_df_dis_sm,ifelse(hh_race == "Asian", 'Asian', 'non-Asian/White/Other'))

person_df_dis_sm$hh_race_poc = 
  with(person_df_dis_sm,ifelse(hh_race == "Non-Asian POC", 'Non-Asian POC', 'Asian/White/Other'))

person_df_dis_sm$hh_race_other = 
  with(person_df_dis_sm,ifelse(hh_race == "Other", 'Other', 'Asian/POC/White'))

person_df_dis_sm[sapply(person_df_dis_sm, is.character)] <- lapply(person_df_dis_sm[sapply(person_df_dis_sm, is.character)], as.factor)

person_df_dis_sm$Median.household.income = as.numeric(person_df_dis_sm$Median.household.income)
person_df_dis_sm$Median.Rent= as.numeric(person_df_dis_sm$Median.Rent)
person_df_dis_sm$sqrt_median_rent = sqrt(1+person_df_dis_sm$Median.Rent)
person_df_dis_sm$sqrt_median_inc = sqrt(1+person_df_dis_sm$Median.household.income)

#Percent of Trect Population to County Population
person_df_dis_sm$'White_pct'<- 100*person_df_dis_sm$'White_pct'
person_df_dis_sm$'Black_pct'<- 100*person_df_dis_sm$'Black_pct'
person_df_dis_sm$'Asian_pct'<- 100*person_df_dis_sm$'Asian_pct'
person_df_dis_sm$'Minority_pct'<- 100*person_df_dis_sm$'Minority_pct'
#iffence in shares between White and other groups					

person_df_dis_sm$'White_Black'<- 100*person_df_dis_sm$'White-Black'
person_df_dis_sm$'White_Minority'<-100*person_df_dis_sm$'White-Minority'
person_df_dis_sm$'Black_AIAN'<-100*person_df_dis_sm$'Black-AIAN'
# displ_logit<-glm(displaced ~. ,data=person_df_ls,
#                  family = 'binomial')

# displ_logit<-glm(displaced ~ hhincome_detailed*rent_or_not+hh_broad_age*rent_or_not+ 
#                     hh_race_upd+hh_broad_age+no_bachelors+dist_school+poor_english+sqrt_median_rent+
#                     hhincome_mrbroad*Percent.Less.than.50K+hhincome_mrbroad*Percent.Above.150K,data=person_df_dis_sm,
#                   family

displacement_variables=c('RA', 'SP', 'FR','RP','MHP','DM','NO',
                         'DBP', 'DBSH', 'DBFAM', 'DB80', 
                         'INP', 'INSH', 'INFAM', 'IN80',
                         'PKP', 'PKSH', 'PKFAM', 'PK80',
                         'PLP', 'PLSH', 'PLFAM', 'PL80')
person_df_dis_sm$ln_nu_total<- log(1+person_df_dis_sm$NUTotal)
person_df_dis_sm$ln_scaled_score<-log(1+person_df_dis_sm$scaled_score)
person_df_dis_sm$ln_score <-log(1+person_df_dis_sm$score)



displ_logit<-glm(displaced ~ hhincome_mrbroad+hh_broad_age+rent_or_not
                 +vehicle_group+Percent.50K..100K+hh_race_poc+DBP+PP+tstops_2,
                   data=person_df_dis_sm,
                   family = 'binomial')

# displ_logit<-glm(displaced ~ hhincome_mrbroad+hh_broad_age+rent_or_not
#                  +vehicle_group+Percent.50K..100K+hh_race_poc+DBP+PP+ln_scaled_score,
#                    data=person_df_dis_sm,
#                    family = 'binomial')


summary(displ_logit, correlation= TRUE, family = 'binomial')





glmOut(displ_logit)
#https://cran.r-project.org/web/packages/jtools/vignettes/summ.html#effect_plot

plot_summs(displ_logit, scale = TRUE)

PseudoR2(displ_logit, c("McFadden", "Nagel"))


