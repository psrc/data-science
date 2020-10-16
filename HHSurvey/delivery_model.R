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



PseudoR2(deliver, c("McFadden", "Nagel"))
#https://cran.r-project.org/web/packages/jtools/vignettes/summ.html#effect_plot
 




