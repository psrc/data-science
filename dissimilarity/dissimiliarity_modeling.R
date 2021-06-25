library(dplyr)
library(corrr)
library(writexl)
library(openxlsx)
library(ggplot2)
library(tidyverse)
library(sf)
library(leaflet)
library(tidyverse)
library(sf)
library(leaflet)
library(tidycensus)
library(writexl)
library(htmlwidgets)
library(Hmisc)
library(data.table)
library(tidyverse)
library(DT)
library(openxlsx)
library(odbc)
library(DBI)
library(jtools)
library(MuMIn)
options(scipen=999)

setwd("~/GitHub/data-science/dissimilarity")


flu<- st_read('C:/Users/SChildress/Documents/ReferenceResearch/displacement/diss_flu16.shp')

flu_df<-as.data.frame(flu)
dissim_index <- read.csv('dissim_bg.csv')

acs_rent_inc = read.csv("C:/Users/SChildress/Documents/GitHub/data-science/dissimilarity/census_tract_vars.csv")
housing_policy<-read.xlsx("C:/Users/SChildress/Documents/GitHub/data-science/HHSurvey/estimation_displace/housing_policy_city.xlsx")

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

#for mapping from block group to city name so we can look at housing policies
dbtable.small_area.query<- paste("SELECT block_group_geoid10,city_name_2020 FROM small_areas.parcel_dim
                                 GROUP BY block_group_geoid10, city_name_2020")
bg_city<-read.dt(dbtable.small_area.query, 'query')

flu_df$GEOID10<- as.numeric(flu_df$GEOID10)
flu_df<-flu_df%>%drop_na(GEOID10)

flu_df<-flu_df%>%group_by(GEOID10)%>% arrange(desc(max_du_ac))%>%summarise(max_max_du=first(max_du_ac), min_max_du=last(max_du_ac), mean_max_du=mean(max_du_ac))
# remove 0s, these represent geographic mismatches
flu_df <- flu_df %>% filter(max_max_du!=0)
flu_dissim<-merge(flu_df, dissim_index, by ="GEOID10")

# defining breakpoints in the du per acre
low_sf<-3
med_high_sf<-10
low_mf<-25
med_mf<-75

sf<-10



# Add a variable for defining single family as greater than 0, but less than some max DU per acre
flu_dissim<-flu_dissim %>% mutate(sf_mf_cats = as.factor(case_when(
  max_max_du<=sf ~ "SF (less than 10 Du per acre)",
  max_max_du>=sf ~ "MF",
)))



flu_dissim_2<- merge(flu_dissim, acs_rent_inc, by.x='TractIDInt', by.y='GEOID', all.x='TRUE')

bg_city<- bg_city %>% mutate(block_group_geoid10=as.numeric(block_group_geoid10))
flu_dissim_3 <- merge(flu_dissim_2, bg_city, by.x='GEOID10', by.y='block_group_geoid10')

housing_policy[is.na(housing_policy)]<-0
housing_policy[housing_policy=='x']<-1

flu_dissim_housing_policy<-merge(flu_dissim_3, housing_policy, by.x='city_name_2020', by.y='Jurisdiction', all.x='TRUE')

housing_variables<- c('DBP','IZP','INP','MFP','PPP','PAP','PLP','TP')
#flu_dissim_housing_policy[is.na(flu_dissim_housing_policy)] <- 2
flu_dissim_housing_policy[housing_variables] <- lapply(flu_dissim_housing_policy[housing_variables] , as.factor)
dissim_big_lm<-lm(White_Black_Dissim~ MFP+PAP+sf_mf_cats+no_bachelors+
                poverty_200+ln_jobs_auto_30+ln_jobs_transit_45+
                dist_super+dist_park+voting,
                 data=flu_dissim_housing_policy)

summary(dissim_big_lm)


plot_summs(dissim_big_lm, scale = TRUE)


dissim_white_min_lm<-lm(White_Minority_Dissim~ TP+MFP+PAP+sf_mf_cats+no_bachelors+rent+
                    poverty_200+ln_jobs_auto_30+ln_jobs_transit_45+
                    dist_super+dist_park+
                   +voting,
                  data=flu_dissim_housing_policy)
summary(dissim_white_min_lm)


plot_summs(dissim_white_min_lm, scale = TRUE)


