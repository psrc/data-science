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


#parcels <- read.csv('C:/Users/SChildress/Documents/HHSurvey/displace_estimate/buffered_parcels.txt', sep= ' ')

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

day_household = day_upd %>% group_by(hhid) %>%
  summarise(sum_pkg = sum(delivery_pkgs_all,na.rm = TRUE),
            sum_groc = sum(delivery_grocery_all,na.rm = TRUE),
            sum_food = sum(delivery_food_all,na.rm = TRUE) ) %>% 
  mutate(delivery = if_else(sum_pkg > 0 | sum_groc > 0 | sum_food > 0 , 1, 0)) %>% 
  select(hhid, delivery) 

sql.query <- paste("SELECT * FROM HHSurvey.v_households_2017_2019_public")
hh = read.dt(sql.query, 'sqlquery')

hh_join_deliv = left_join(hh, day_household , by = c("hhid" = "hhid"))
                                                                

#days_parcels<-merge(day_dt, parcels, by.x='final_home_parcel_dim_id', by.y='parcelid')

hh_join_deliv[sapply(hh_join_deliv, is.character)] <- lapply(hh_join_deliv[sapply(hh_join_deliv, is.character)], as.factor)


deliver<-glm(delivery~ 0+hhincome_broad+hhsize,
                   data=hh_join_deliv,
                    family = 'binomial')


summary(deliver, correlation= TRUE, family = 'binomial')



PseudoR2(deliver, c("McFadden", "Nagel"))
#https://cran.r-project.org/web/packages/jtools/vignettes/summ.html#effect_plot
 




