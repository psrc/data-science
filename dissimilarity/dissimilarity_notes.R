## ----setup, include=FALSE---------------------------------------------------------------------------------
knitr::opts_chunk$set(echo = TRUE)


## ----data_prep, echo=FALSE, message=FALSE, warning=FALSE, results='hide'----------------------------------
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
library(BAMMtools)
library(DBI)
library(odbc)
library(mapview)

setwd("~/GitHub/data-science/dissimilarity")


flu<- st_read('C:/Users/SChildress/Documents/ReferenceResearch/displacement/diss_flu16.shp')

flu_df<-as.data.frame(flu)
dissim_index <- read.csv('dissim_bg.csv')

flu_df$GEOID10<- as.numeric(flu_df$GEOID10)
flu_df<-flu_df%>%drop_na(GEOID10)



## ----stat_test, echo=FALSE--------------------------------------------------------------------------------
flu_df<-flu_df%>%group_by(GEOID10)%>% arrange(desc(max_du_ac))%>%summarise(max_max_du=first(max_du_ac), min_max_du=last(max_du_ac), mean_max_du=mean(max_du_ac))

# remove 0s, these represent geographic mismatches
flu_df <- flu_df %>% filter(max_max_du!=0)
flu_dissim<-merge(flu_df, dissim_index, by ="GEOID10")


cor.test(flu_dissim$White_Minority_Dissim, flu_dissim$max_max_du,
         method = "spearman")

cor.test(flu_dissim$White_Black_Dissim, flu_dissim$max_max_du,
         method = "spearman")

cor.test(flu_dissim$White_AIAN_Dissim, flu_dissim$max_max_du,
         method = "spearman")


cor.test(flu_dissim$White_Minority_Dissim, flu_dissim$mean_max_du,
         method = "spearman")

cor.test(flu_dissim$White_Black_Dissim, flu_dissim$mean_max_du,
         method = "spearman")

cor.test(flu_dissim$White_AIAN_Dissim, flu_dissim$mean_max_du,
         method = "spearman")

cor.test(flu_dissim$White_Minority_Dissim, flu_dissim$min_max_du,
         method = "spearman")

cor.test(flu_dissim$White_Black_Dissim, flu_dissim$min_max_du,
         method = "spearman")

cor.test(flu_dissim$White_AIAN_Dissim, flu_dissim$min_max_du,
         method = "spearman")




## ----summary_vars, echo=FALSE-----------------------------------------------------------------------------

describe(flu_dissim$mean_max_du)

describe(flu_dissim$White_Black_Dissim)
describe(flu_dissim$White_Minority_Dissim)

ggplot(flu_df,aes(x=mean_max_du))+geom_histogram(bins=100)+geom_vline(aes(xintercept=mean(mean_max_du, color=blue)))

breaks<-getJenksBreaks(flu_df$mean_max_du, k=10)
breaks

ggplot(flu_dissim, aes(x=White_Black_Dissim)) + geom_histogram(bins=100)
ggplot(flu_dissim, aes(x=White_Minority_Dissim)) + geom_histogram(bins=100)



## ----more_analysis----------------------------------------------------------------------------------------

flu_dissim<- flu_dissim %>%mutate(mean_max_du_capped=replace(mean_max_du,mean_max_du>100,100))

ggplot(flu_dissim, aes(x=mean_max_du_capped)) + geom_histogram(bins=25)





## ---- echo=FALSE------------------------------------------------------------------------------------------
create_map_du <- function(c.layer,
                             map.title = NULL, map.subtitle = NULL,
                             map.title.position = NULL,
                             legend.title = NULL, legend.subtitle = NULL,
                             map.lat=47.615, map.lon=-122.257, map.zoom=8.5, wgs84=4326){
  


  # Calculate Bins from Data and create color palette
  rng <- range(c.layer$mean_max_du_capped)
  max_bin <- max(abs(rng))
  round_to <- 10^floor(log10(max_bin))
  max_bin <- ceiling(max_bin/round_to)*round_to
  breaks <- (sqrt(max_bin)*c(0.1, 0.2,0.4, 0.6, 0.8, 1))^2
  bins <- c(0, breaks)

  pal <- leaflet::colorBin("RdYlBu", domain = c.layer$mean_max_du_capped, bins = bins, reverse = TRUE)
  
  labels <- paste0(
                   'Max Du per Acre: ',c.layer$mean_max_du_capped) %>% lapply(htmltools::HTML)
  
  m <- leaflet::leaflet() %>%
    leaflet::addMapPane(name = "polygons", zIndex = 410) %>%
    leaflet::addMapPane(name = "maplabels", zIndex = 500) %>% # higher zIndex rendered on top
    
    leaflet::addProviderTiles("CartoDB.VoyagerNoLabels") %>%
    leaflet::addProviderTiles("CartoDB.VoyagerOnlyLabels",
                              options = leaflet::leafletOptions(pane = "maplabels"),
                              group = "Labels") %>%
    
    leaflet::addEasyButton(leaflet::easyButton(icon="fa-globe",
                                               title="Region",
                                               onClick=leaflet::JS("function(btn, map){map.setView([47.615,-122.257],8.5); }"))) %>%
    leaflet::addPolygons(data=c.layer,
                         fillOpacity = 0.7,
                         fillColor = pal(c.layer$mean_max_du_capped),
                         opacity = 0.1,
                         weight = 0.1,
                         stroke=FALSE,
                         color = "#BCBEC0",
                         group="Population",
                         options = leaflet::leafletOptions(pane = "polygons"),
                         dashArray = "",
                         highlight = leaflet::highlightOptions(
                           weight =0.1,
                           color = "76787A",
                           dashArray ="",
                           fillOpacity = 1,
                           bringToFront = TRUE),
                         label = labels,
                         labelOptions = leaflet::labelOptions(
                           style = list("font-weight" = "normal", padding = "3px 8px"),
                           textsize = "15px",
                           direction = "auto")) %>%
    
    leaflet::addLegend(pal = pal,
                       values = c.layer$mean_max_du_capped,
                       position = "bottomright",
                       title = paste(legend.title, '<br>', legend.subtitle)) %>%
    
    leaflet::addControl(html = paste(map.title, '<br>', map.subtitle),
                        position = map.title.position,
                        layerId = 'mapTitle') %>%
    
    leaflet::addLayersControl(baseGroups = "CartoDB.VoyagerNoLabels",
                              overlayGroups = c("Labels", "Population")) %>%
    
    leaflet::setView(lng=map.lon, lat=map.lat, zoom=map.zoom)
  
  return(m)
  
}


## ----make_maps, echo=FALSE--------------------------------------------------------------------------------
flu_dissim<-flu_dissim%>%mutate(GEOID10=as.character(GEOID10))
flu_dissim<-flu_dissim%>%drop_na(GEOID10)

gdb.nm <- paste0("MSSQL:server=",
                 "AWS-PROD-SQL\\Sockeye",
                 ";database=",
                 "ElmerGeo",
                 ";trusted_connection=yes")

spn <-  2285

bg_layer_name <- "dbo.BLOCKGRP2010_NOWATER"

bg.lyr <- st_read(gdb.nm, bg_layer_name, crs = spn)

wgs84=4326
c.layer <- dplyr::left_join(bg.lyr,flu_dissim, by = c("geoid10"="GEOID10")) %>%
  sf::st_transform(wgs84)
c.layer$mean_max_du_capped[is.na(c.layer$mean_max_du_capped)]<-0


flu_bg_map<-create_map_du(c.layer)

flu_bg_map


## ---- echo=FALSE------------------------------------------------------------------------------------------
create_map_du_10 <- function(c.layer,
                             map.title = NULL, map.subtitle = NULL,
                             map.title.position = NULL,
                             legend.title = NULL, legend.subtitle = NULL,
                             map.lat=47.615, map.lon=-122.257, map.zoom=8.5, wgs84=4326){
  


  # Calculate Bins from Data and create color palette
  bins <- c(0, 10,100)

  
  pal <- leaflet::colorBin("RdYlBu", domain = c.layer$mean_max_du_capped, bins = bins, reverse=TRUE)
  
  labels <- paste0(
                   'Max Du per Acre: ', c.layer$mean_max_du_capped) %>% lapply(htmltools::HTML)
  
  m <- leaflet::leaflet() %>%
    leaflet::addMapPane(name = "polygons", zIndex = 410) %>%
    leaflet::addMapPane(name = "maplabels", zIndex = 500) %>% # higher zIndex rendered on top
    
    leaflet::addProviderTiles("CartoDB.VoyagerNoLabels") %>%
    leaflet::addProviderTiles("CartoDB.VoyagerOnlyLabels",
                              options = leaflet::leafletOptions(pane = "maplabels"),
                              group = "Labels") %>%
    
    leaflet::addEasyButton(leaflet::easyButton(icon="fa-globe",
                                               title="Region",
                                               onClick=leaflet::JS("function(btn, map){map.setView([47.615,-122.257],8.5); }"))) %>%
    leaflet::addPolygons(data=c.layer,
                         fillOpacity = 0.7,
                         fillColor = pal(c.layer$mean_max_du_capped),
                         opacity = 0.7,
                         weight = 0.7,
                         stroke=FALSE,
                         color = "#BCBEC0",
                         group="Population",
                         options = leaflet::leafletOptions(pane = "polygons"),
                         dashArray = "",
                         highlight = leaflet::highlightOptions(
                           weight =5,
                           color = "76787A",
                           dashArray ="",
                           fillOpacity = 0.7,
                           bringToFront = TRUE),
                         label = labels,
                         labelOptions = leaflet::labelOptions(
                           style = list("font-weight" = "normal", padding = "3px 8px"),
                           textsize = "15px",
                           direction = "auto")) %>%
    
    leaflet::addLegend(pal = pal,
                       values = c.layer$mean_max_du_capped,
                       position = "bottomright",
                       title = paste(legend.title, '<br>', legend.subtitle)) %>%
    
    leaflet::addControl(html = paste(map.title, '<br>', map.subtitle),
                        position = map.title.position,
                        layerId = 'mapTitle') %>%
    
    leaflet::addLayersControl(baseGroups = "CartoDB.VoyagerNoLabels",
                              overlayGroups = c("Labels", "Population")) %>%
    
    leaflet::setView(lng=map.lon, lat=map.lat, zoom=map.zoom)
  
  return(m)
  
}


## ----du_10------------------------------------------------------------------------------------------------

map_du_10<-create_map_du_10(c.layer)
map_du_10



## ---- echo=FALSE------------------------------------------------------------------------------------------
create_map_du_25 <- function(c.layer,
                             map.title = NULL, map.subtitle = NULL,
                             map.title.position = NULL,
                             legend.title = NULL, legend.subtitle = NULL,
                             map.lat=47.615, map.lon=-122.257, map.zoom=8.5, wgs84=4326){
  


  # Calculate Bins from Data and create color palette
  bins <- c(0, 25,100)

  pal <- leaflet::colorBin("RdYlBu", domain = c.layer$mean_max_du_capped, bins = bins, reverse=TRUE)
  
  labels <- paste0(
                   'Max Du per Acre: ', prettyNum(round(c.layer$mean_max_du_capped, -1), big.mark = ",")) %>% lapply(htmltools::HTML)
  
  m <- leaflet::leaflet() %>%
    leaflet::addMapPane(name = "polygons", zIndex = 410) %>%
    leaflet::addMapPane(name = "maplabels", zIndex = 500) %>% # higher zIndex rendered on top
    
    leaflet::addProviderTiles("CartoDB.VoyagerNoLabels") %>%
    leaflet::addProviderTiles("CartoDB.VoyagerOnlyLabels",
                              options = leaflet::leafletOptions(pane = "maplabels"),
                              group = "Labels") %>%
    
    leaflet::addEasyButton(leaflet::easyButton(icon="fa-globe",
                                               title="Region",
                                               onClick=leaflet::JS("function(btn, map){map.setView([47.615,-122.257],8.5); }"))) %>%
    leaflet::addPolygons(data=c.layer,
                         fillOpacity = 0.7,
                         fillColor = pal(c.layer$mean_max_du_capped),
                         opacity = 0.7,
                         weight = 0.7,
                         stroke=FALSE,
                         color = "#BCBEC0",
                         group="Population",
                         options = leaflet::leafletOptions(pane = "polygons"),
                         dashArray = "",
                         highlight = leaflet::highlightOptions(
                           weight =5,
                           color = "76787A",
                           dashArray ="",
                           fillOpacity = 0.7,
                           bringToFront = TRUE),
                         label = labels,
                         labelOptions = leaflet::labelOptions(
                           style = list("font-weight" = "normal", padding = "3px 8px"),
                           textsize = "15px",
                           direction = "auto")) %>%
    
    leaflet::addLegend(pal = pal,
                       values = c.layer$mean_max_du_capped,
                       position = "bottomright",
                       title = paste(legend.title, '<br>', legend.subtitle)) %>%
    
    leaflet::addControl(html = paste(map.title, '<br>', map.subtitle),
                        position = map.title.position,
                        layerId = 'mapTitle') %>%
    
    leaflet::addLayersControl(baseGroups = "CartoDB.VoyagerNoLabels",
                              overlayGroups = c("Labels", "Population")) %>%
    
    leaflet::setView(lng=map.lon, lat=map.lat, zoom=map.zoom)
  
  return(m)
  
}


## ---- echo=FALSE------------------------------------------------------------------------------------------
map_du_25<-create_map_du_25(c.layer)
map_du_25


## ---- echo=FALSE------------------------------------------------------------------------------------------
create_map_dissim <- function(c.layer,
                             map.title = NULL, map.subtitle = NULL,
                             map.title.position = NULL,
                             legend.title = NULL, legend.subtitle = NULL,
                             map.lat=47.615, map.lon=-122.257, map.zoom=8.5, wgs84=4326){
  


  # Calculate Bins from Data and create color palette
  rng <- range(c.layer$White_Black_Dissim)

  bins<-getJenksBreaks(c.layer$White_Black_Dissim, k=10)

  
  pal <- leaflet::colorBin("RdYlBu", domain = c.layer$White_Black_Dissim, bins = bins)
  
  labels <- paste0(
                   'White_Black_Dissim: ',c.layer$White_Black_Dissim, big.mark = ",") %>% lapply(htmltools::HTML)
  
  m <- leaflet::leaflet() %>%
    leaflet::addMapPane(name = "polygons", zIndex = 410) %>%
    leaflet::addMapPane(name = "maplabels", zIndex = 500) %>% # higher zIndex rendered on top
    
    leaflet::addProviderTiles("CartoDB.VoyagerNoLabels") %>%
    leaflet::addProviderTiles("CartoDB.VoyagerOnlyLabels",
                              options = leaflet::leafletOptions(pane = "maplabels"),
                              group = "Labels") %>%
    
    leaflet::addEasyButton(leaflet::easyButton(icon="fa-globe",
                                               title="Region",
                                               onClick=leaflet::JS("function(btn, map){map.setView([47.615,-122.257],8.5); }"))) %>%
    leaflet::addPolygons(data=c.layer,
                         fillOpacity = 0.7,
                         fillColor = pal(c.layer$White_Black_Dissim),
                         opacity = 0.7,
                         weight = 0.7,
                         stroke=FALSE,
                         group="Population",
                         options = leaflet::leafletOptions(pane = "polygons"),
                         dashArray = "",
                         highlight = leaflet::highlightOptions(
                           weight =5,
                           color = "76787A",
                           dashArray ="",
                           fillOpacity = 0.7,
                           bringToFront = TRUE),
                         label = labels,
                         labelOptions = leaflet::labelOptions(
                           style = list("font-weight" = "normal", padding = "3px 8px"),
                           textsize = "15px",
                           direction = "auto")) %>%
    
    leaflet::addLegend(pal = pal,
                       values = c.layer$White_Black_Dissim,
                       position = "bottomright",
                       title = paste(legend.title, '<br>', legend.subtitle)) %>%
    
    leaflet::addControl(html = paste(map.title, '<br>', map.subtitle),
                        position = map.title.position,
                        layerId = 'mapTitle') %>%
    
    leaflet::addLayersControl(baseGroups = "CartoDB.VoyagerNoLabels",
                              overlayGroups = c("Labels", "Population")) %>%
    
    leaflet::setView(lng=map.lon, lat=map.lat, zoom=map.zoom)
  
  return(m)
  
}



## ----White_Black_Dissim-----------------------------------------------------------------------------------
c.layer$White_Black_Dissim[is.na(c.layer$White_Black_Dissim)]<-1000
dissim_bg_map<-create_map_dissim(c.layer)
dissim_bg_map




## ---------------------------------------------------------------------------------------------------------

ggplot(flu_dissim, aes(x=mean_max_du_capped, y=White_Black_Dissim))+
  geom_point()+
  geom_smooth(method=lm, formula='y ~poly(x,3)')

ggplot(flu_dissim, aes(x=mean_max_du_capped, y=White_Minority_Dissim))+
  geom_point()+
  geom_smooth(method=lm, formula='y ~poly(x,3)')



## ---------------------------------------------------------------------------------------------------------



## ---- echo=FALSE------------------------------------------------------------------------------------------

sf_threshold_low<-10



# Add a variable for defining single family as greater than 0, but less than some max DU per acre
flu_dissim<-flu_dissim %>% mutate(
  is_sf_low = case_when(
    max_max_du>=sf_threshold_low ~ 0,
    max_max_du<sf_threshold_low ~ 1
  ))%>%
  mutate(is_sf_factor_low = as.numeric(is_sf_low))


mean_low<-flu_dissim %>%
  group_by(is_sf_low)%>%
  summarise(mean_white_minority_dissim_low=mean(White_Minority_Dissim))

flu_dissim %>%
  group_by(is_sf_low)%>%
  summarise(mean_white_black_dissim_low=mean(White_Black_Dissim))

flu_dissim %>%
  group_by(is_sf_low)%>%
  summarise(mean_white_aian_dissim_low=mean(White_AIAN_Dissim))





anova_sf_white_black = aov(White_Black_Dissim ~is_sf_low, data=flu_dissim)
anova_sf_white_minority = aov(White_Minority_Dissim ~is_sf_low, data=flu_dissim)
anova_sf_white_aian = aov(White_AIAN_Dissim ~is_sf_low, data=flu_dissim)
summary(anova_sf_white_aian)
summary(anova_sf_white_minority)
summary(anova_sf_white_black)



## ---- echo=FALSE------------------------------------------------------------------------------------------
  
low_sf<-3
med_high_sf<-10
low_mf<-25
med_mf<-75


# Add a variable for defining single family as greater than 0, but less than some max DU per acre
flu_dissim<-flu_dissim %>% mutate(sf_mf_cats = case_when(
    max_max_du<=low_sf ~ "Low_SF (less than 3 Du per acre)",
    max_max_du<=med_high_sf ~ "Med_High_SF (3-10)",
    max_max_du<=low_mf ~  "Low_MF (10-25)",
    max_max_du<=med_mf ~ "Med_MF(25-75)",
    max_max_du>=med_mf ~ "High_MF(75+)"
  ))

flu_dissim$sf_mf_cats <-factor(flu_dissim$sf_mf_cats, levels=c("Low_SF (less than 3 Du per acre)",
                                                               "Med_High_SF (3-10)",
                                                                "Low_MF (10-25)",
                                                               "Med_MF(25-75)",
                                                               "High_MF(75+)"))

flu_dissim %>% group_by(sf_mf_cats) %>% summarise(mean_dissim_white_black=mean(White_Black_Dissim))

du_cat_dissim<-ggplot(flu_dissim, aes(x=sf_mf_cats, y=White_Black_Dissim))+geom_boxplot()





## ---- echo=FALSE------------------------------------------------------------------------------------------
flu_dissim_model<-glm(White_Black_Dissim ~ sf_mf_cats,
                 data=flu_dissim)

summary(flu_dissim_model)


## ---- echo=FALSE------------------------------------------------------------------------------------------
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

block_group_city<-read.dt("select pd.block_group_geoid10 from small_areas.parcel_dim pd where pd.city_name_2020 = 'Seattle' group by pd.block_group_geoid10 order by pd.block_group_geoid10", 'sqlquery')





## ----seattle, echo=FALSE----------------------------------------------------------------------------------
block_group_city <- block_group_city %>% mutate(block_group_geoid10 =as.character(block_group_geoid10))
flu_dissim_seattle<- dplyr::left_join(block_group_city,flu_dissim, by = c("block_group_geoid10"="GEOID10"))


flu_dissim %>% group_by(sf_mf_cats) %>% summarise(mean_dissim_white_black=mean(White_Black_Dissim))
ggplot(flu_dissim_seattle, aes(x=sf_mf_cats, y=White_Black_Dissim))+geom_boxplot()         
flu_dissim_model_seattle<-glm(White_Black_Dissim ~ sf_mf_cats,
                 data=flu_dissim)
summary(flu_dissim_seattle)
ggplot(flu_dissim, aes(x=mean_max_du_capped, y=White_Black_Dissim))+
  geom_point()+
  geom_smooth(method=lm, formula='y ~poly(x,3)')

