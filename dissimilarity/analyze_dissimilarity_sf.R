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

setwd("~/GitHub/data-science/dissimilarity")


flu<- st_read('C:/Users/SChildress/Documents/ReferenceResearch/displacement/diss_flu16.shp')

flu_df<-as.data.frame(flu)
dissim_index <- read.csv('dissim_bg.csv')

flu_df$GEOID10<- as.numeric(flu_df$GEOID10)
flu_df<-flu_df%>%drop_na(GEOID10)

flu_df<-flu_df%>%group_by(GEOID10)%>%
  summarise(max_max_du=max(max_du_ac), min_max_du=min(max_du_ac), mean_max_du=mean(max_du_ac))

flu_dissim<-merge(flu_df, dissim_index, by ="GEOID10")

flus

white_min<-lm(White_Minority_Dissim ~ max_max_du, data=flu_dissim)


cor.test(flu_dissim$White_Minority_Dissim, flu_dissim$max_max_du,
         method = "spearman")

cor.test(flu_dissim$White_Black_Dissim, flu_dissim$max_max_du,
         method = "spearman")


ggplot(flu_dissim, aes(x=max_max_du, y=White_Black_Dissim))+
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


