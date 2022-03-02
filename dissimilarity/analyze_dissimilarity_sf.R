library(dplyr)
library(corrr)
library(writexl)
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
library(BAMMtools)

setwd("~/GitHub/data-science/dissimilarity")


create_map <- function(c.layer,
                             map.title = NULL, map.subtitle = NULL,
                             map.title.position = NULL,
                             legend.title = NULL, legend.subtitle = NULL,
                             map.lat=47.615, map.lon=-122.257, map.zoom=8.5, wgs84=4326){
  


  # Calculate Bins from Data and create color palette
  rng <- range(c.layer$mean_max_du)
  max_bin <- max(abs(rng))
  round_to <- 10^floor(log10(max_bin))
  max_bin <- ceiling(max_bin/round_to)*round_to
  breaks <- (sqrt(max_bin)*c(0.1, 0.2,0.4, 0.6, 0.8, 1))^2
  bins <- c(0, breaks)
  
  pal <- leaflet::colorBin("YlOrRd", domain = c.layer$mean_max_du, bins = bins)
  
  labels <- paste0(
                   'Max Du per Acre: ', prettyNum(round(c.layer$mean_max_du, -1), big.mark = ",")) %>% lapply(htmltools::HTML)
  
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
                         fillColor = pal(c.layer$mean_max_du),
                         opacity = 0.7,
                         weight = 0.7,
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
                       values = c.layer$estimate,
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


flu<- st_read('C:/Users/SChildress/Documents/ReferenceResearch/displacement/diss_flu16.shp')




flu_df<-as.data.frame(flu)


flu_df$GEOID10<- as.numeric(flu_df$GEOID10)
flu_df<-flu_df%>%drop_na(GEOID10)

flu_df<-flu_df%>%group_by(GEOID10)%>%
  summarise(max_max_du=max(max_du_ac), min_max_du=min(max_du_ac), mean_max_du=mean(max_du_ac))

flu_df<-flu_df%>%mutate(GEOID10=as.character(GEOID10))

gdb.nm <- paste0("MSSQL:server=",
                 "AWS-PROD-SQL\\Sockeye",
                 ";database=",
                 "ElmerGeo",
                 ";trusted_connection=yes")

spn <-  2285

bg_layer_name <- "dbo.BLOCKGRP2010_NOWATER"

bg.lyr <- st_read(gdb.nm, bg_layer_name, crs = spn)

wgs84=4326
c.layer <- dplyr::left_join(bg.lyr,flu_df, by = c("geoid10"="GEOID10")) %>%
  sf::st_transform(wgs84)

flu_map<-create_map(c.layer)

ggplot(flu_df,aes(x=mean_max_du))+geom_histogram(bins=100)+geom_vline(aes(xintercept=mean(mean_max_du, color=blue)))

breaks<-getJenksBreaks(flu_df$mean_max_du, k=10)
mean(flu_df$mean_max_du)

flu_df<-flu_df %>% mutate(sf_breaks=cut(mean_max_du, breaks=breaks), right=FALSE)

#threshold at 

flu_dissim<-merge(flu_df, dissim_index, by ="GEOID10")


white_min<-lm(White_Minority_Dissim ~ max_max_du, data=flu_dissim)



cor.test(flu_dissim$White_Minority_Dissim, flu_dissim$mean_max_du,
         method = "spearman")

cor.test(flu_dissim$White_Black_Dissim, flu_dissim$mean_max_du,
         method = "spearman")

cor.test(flu_dissim$White_Black_Dissim, flu_dissim$sf_breaks)

ggplot(flu_dissim, aes(x=mean_max_du, y=White_Black_Dissim))+
  geom_point()+
  geom_smooth(method=lm, formula='y ~poly(x,2)')

ggplot(flu_dissim, aes(x=sf_breaks, y=White_Black_Dissim))+
  geom_point()+
  geom_smooth(method=lm, formula='y ~poly(x,2)')

ggplot(flu_dissim, aes(x=min_max_du, y=White_Black_Dissim))+
  geom_point()+
  geom_smooth(method=lm, formula='y ~poly(x,2)')

ggplot(flu_dissim, aes(x=mean_max_du, y=White_Black_Dissim))+
  geom_point()+
  geom_smooth(method=lm, formula='y ~poly(x,2)')

ggplot(dissim_vars, aes(x=White_Black_Dissim)) + geom_histogram()

ggplot(dissim_vars, aes(x=White_Minority_Dissim)) + geom_histogram()

white_black_lm<-lm(White_Black_Dissim ~ MaxDU_Res, data=dissim_vars)
summary(white_black_lm, scale = TRUE)


sf_threshold_low<-3
sf_threshold_high<-10

summ<-summary(dissim_index)

sf_layer<-sf_layer %>% filter(MaxDU_Res>0)

# Add a variable for defining single family as greater than 0, but less than some max DU per acre
sf_layer<-sf_layer %>% mutate(
  is_sf_low = case_when(
    MaxDU_Res==0 ~ 0,
    MaxDU_Res>=sf_threshold_low ~ 0,
    MaxDU_Res>0 & MaxDU_Res<sf_threshold_low ~ 1
  ))%>%
  mutate(is_sf_factor_low = as.numeric(is_sf_low))

# Add a variable for defining single family as greater than 0, but less than 10 DU per acre
sf_layer<-sf_layer %>% mutate(
  is_sf_10 = case_when(
    MaxDU_Res==0 ~ 0,
    MaxDU_Res>=sf_threshold_high ~ 0,
    MaxDU_Res>0 & MaxDU_Res<sf_threshold_high ~ 1
  ))%>%
  mutate(is_sf_factor_10 = as.numeric(is_sf_10))
                    

sf_layer<-sf_layer %>% mutate(
  is_sf_25 = case_when(
    MaxDU_Res==0 ~ 0,
    MaxDU_Res>=25 ~ 0,
    MaxDU_Res>0 & MaxDU_Res<25 ~ 1
  ))%>%
  mutate(is_sf_factor_25 = as.numeric(is_sf_25))

dissim_vars %>%
  group_by(is_sf_factor_25)%>%
  summarize(mean_white_black_dissim_25=mean(White_Black_Dissim))


dissim_vars<-merge(dissim_index, sf_layer, on='GEOID10')

mean_low<-dissim_vars %>%
  group_by(is_sf_low)%>%
  summarize(mean_white_minority_dissim_low=mean(White_Minority_Dissim))

dissim_vars %>%
  group_by(is_sf_low)%>%
  summarize(mean_white_black_dissim_low=mean(White_Black_Dissim))


white_min_low<-lm(White_Minority_Dissim ~ is_sf_factor_low, data=dissim_vars)
summary(white_min_low, scale = TRUE)


#https://statisticsbyjim.com/basics/correlations/

cor.test(dissim_vars$White_Minority_Dissim, dissim_vars$is_sf_low,
         method = "spearman")

cor.test(dissim_vars$White_Black_Dissim, dissim_vars$is_sf_low,
         method = "spearman")


white_black_low<-lm(White_Black_Dissim ~ is_sf_factor_low, data=dissim_vars)
summary(white_black_low, scale = TRUE)

cor.test(dissim_vars$White_Black_Dissim, dissim_vars$is_sf_10,
         method = "spearman")

dissim_vars %>%
  group_by(is_sf_10)%>%
  summarize(mean_white_minority_dissim_10=mean(White_Minority_Dissim))

dissim_vars %>%
  group_by(is_sf_10)%>%
  summarize(mean_white_minority_black_10=mean(White_Black_Dissim))


white_min<-lm(White_Minority_Dissim ~ is_sf_factor_10, data=dissim_vars)
summary(white_min, scale = TRUE)

cor.test(dissim_vars$White_Minority_Dissim, dissim_vars$is_sf_10,
         method = "spearman")

white_black<-lm(White_Black_Dissim ~ is_sf_factor_10, data=dissim_vars)
summary(white_black, scale = TRUE)

cor.test(dissim_vars$White_Black_Dissim, dissim_vars$is_sf_10,
         method = "spearman")


