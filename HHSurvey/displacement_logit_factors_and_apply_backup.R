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

#The codebook is checked in with these code files, named Combined_Codebook_022020.xlsx

################# Input Data File Reading


# This file contains information by Census Tract such as percent of households https://www.psrc.org/displacement-risk-mapping
# in poverty, coming from the displacement risk analysis work.
# it is checked in on github. You will need to point this variable to where it is
# on your computer.
# Census Tract based information used for the displacement risk index
displ_index_data<- 'C:/Users/SChildress/Documents/GitHub/data-science/HHSurvey/displacement_risk_estimation.csv'

#add updated hh race and age variables
hh_race_age_cat = read.xlsx("C:/Users/SChildress/Documents/GitHub/data-science/HHSurvey/hh_race_age_categ.xlsx")

# Census tract information about incomes and rentals
acs_rent_inc = read.csv("C:/Users/SChildress/Documents/HHSurvey/displace_estimate/acs_income_rent_2018.csv")

# Jurisdiction level information about housing policy
housing_policy<-read.xlsx("C:/Users/SChildress/Documents/GitHub/data-science/HHSurvey/estimation_displace/housing_policy_city.xlsx")

# Transit score for each home parcel
movers_score = read.csv("C:/Users/SChildress/Documents/GitHub/data-science/HHSurvey/estimation_displace/movers_score2018.csv")

#Outputs of the estimation
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


# adding information about housing policy
housing_policy[is.na(housing_policy)]<-0
housing_policy[housing_policy=='x']<-1
person_df <- merge(person_df, housing_policy, by.x='city_name', by.y='Jurisdiction')


# Joining the person data to census tract, joining to acs information, and displacement risk info
#prev_home_taz_2010
person_df$census_2010_tract <- as.character(person_df$census_2010_tract)
displ_risk_df$GEOID<-as.character(displ_risk_df$GEOID)
person_df_dis <- merge(person_df,displ_risk_df, by.x='census_2010_tract', by.y='GEOID', all.x=TRUE)
acs_rent_inc$GEOID10<- as.character(acs_rent_inc$GEOID10)
person_df_dis <- merge(person_df_dis,acs_rent_inc, by.x='census_2010_tract', by.y='GEOID10', all.x=TRUE )


# adding information about transit score
person_df_dis$parcel_id <- as.character(person_df_dis$prev_home_parcel_id)
movers_score$parcel<-as.character(movers_score$PSRC_ID)
person_df_dis<-merge(person_df_dis, movers_score, by.x='parcel_id', by.y='parcel')

#adding some age and race variables
person_df_dis$hhid <- as.character(person_df_dis$hhid)
hh_race_age_cat$hhid <- as.character(hh_race_age_cat$hhid)
person_df_dis_sm<-merge(person_df_dis, hh_race_age_cat, by='hhid')



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
                      'hh_race', 'hh_age',
                      'Percent.Less.than.10K', "Percent.Less.than.25K",  "Percent.Less.than.50K",  
                      "Percent.50K..100K",    "Percent.Above.100K" ,  "Percent.Above.150K",  "Percent.Above.200K",    
                      "Median.household.income", "LN.Median.Income","Median.Rent"
)

vars_to_consider<-c(vars_to_consider,names(housing_policy))



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
#person_df_dis_sm$ln_nu_total<- log(1+person_df_dis_sm$NUTotal)
person_df_dis_sm$ln_scaled_score<-log(1+person_df_dis_sm$scaled_score)




# displ_logit<-glm(displaced ~ hhincome_mrbroad+hh_broad_age+rent_or_not
#                  +vehicle_group+Percent.50K..100K+hh_race_poc+DBP+PP+ln_scaled_score,
#                    data=person_df_dis_sm,
#                    family = 'binomial')

displ_logit<-glm(displaced ~ hhincome_mrbroad+hh_broad_age+hh_race_poc
                 +vehicle_group+Percent.50K..100K+DBP+PP,
                   data=person_df_dis_sm,
                    family = 'binomial')


summary(displ_logit, correlation= TRUE, family = 'binomial')





glmOut(displ_logit)

PseudoR2(displ_logit, c("McFadden", "Nagel"))
#https://cran.r-project.org/web/packages/jtools/vignettes/summ.html#effect_plot
 
dbtable.parcel.query<- paste("SELECT block_group_geoid10, city_name_2020 FROM small_areas.parcel_dim")
block_group_city<-read.dt(dbtable.parcel.query, 'query')

block_group_city_one <- block_group_city %>% group_by(block_group_geoid10)%>%
  summarise(city = first(na.omit(city_name_2020)))
  

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
          summarise(hh_race_code = paste0(person_race_code, collapse = "")) # create a household race code with integer codes of all persons in household
 
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
  with(hh_movers,ifelse(hh_race == "White Only", 'White', 'POC/Other'))

hh_movers$hh_race_asian = 
  with(hh_movers,ifelse(hh_race == "Asian", 'Asian', 'non-Asian/White/Other'))

hh_movers$hh_race_poc = 
  with(hh_movers,ifelse(hh_race == "African American" | hh_race =='Other', 'Non-Asian POC', 'Asian/White/Other'))

hh_movers$hh_race_other = 
  with(hh_movers,ifelse(hh_race == "Other", 'Other', 'Asian/POC/White'))


# join the household movers over to the demographic info


hh_movers<- hh_movers %>%
  mutate(new_tract=substr(census_2010_block_group_id.x,1, 11))

hh_movers$new_tract<-as.character(hh_movers$new_tract)

hh_movers_geo <- merge(hh_movers, displ_risk_df, by.x= 'new_tract', by.y='GEOID')

hh_movers_geo$census_2010_block_group_id <- as.character(hh_movers_geo$census_2010_block_group_id.x)
block_group_city_one$census_2010_block_group<- as.character(block_group_city_one$block_group_geoid10)
hh_movers_geo <- merge(hh_movers_geo,block_group_city_one, by.x= 'census_2010_block_group_id', by.y='census_2010_block_group')
hh_movers_geo<-merge(hh_movers_geo, housing_policy, by.x='city', by.y='Jurisdiction')
hh_movers_geo<-merge(hh_movers_geo, acs_rent_inc, by.x='new_tract', by.y='GEOID10')
#+Percent.50K..100K+DBP+PP

#why isn't this working?
pred<-cbind(hh_movers_geo,predicted=predict(displ_logit, type='response', newdata=hh_movers_geo))
prediction <- pred %>% mutate(simulated_displacement= rbinom(length(pred$predicted), size = 1, prob=pred$predicted))
# displ_logit<-glm(displaced ~ hhincome_mrbroad+hh_broad_age+hh_race_poc
#                  +vehicle_group+Percent.50K..100K+DBP+PP,
#                  data=person_df_dis_sm,
#                  family = 'binomial')


hh_income_pred<-prediction %>% group_by(hhincome_mrbroad, simulated_displacement) %>% tally()
hh_race_pred<-prediction %>% group_by(hh_race_poc, simulated_displacement) %>% tally()
displacement_block_group<-prediction %>% group_by(census_2010_block_group_id, simulated_displacement) %>% tally()
displacement_block_group_wide<-displacement_block_group %>% pivot_wider(
                              names_from=simulated_displacement, values_from=n)



write.csv(displacement_block_group_wide,"C:/Users/SChildress/Documents/GitHub/data-science/HHSurvey/estimation_displace/displacement_simulation.csv")

