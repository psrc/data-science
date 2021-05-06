library(dplyr)
library(corrr)
library(writexl)
library(ggplot2)


setwd("~/GitHub/dissimilarity")

dissim_index <- read.csv('dissim_bg.csv')
sf_layer<- read.csv('sf_under10.csv')

summ<-summary(dissim_index)

# Add a variable for defining single family as greater than 0, but less than 6 DU per acre
sf_layer<-sf_layer %>% mutate(
  is_sf_6 = case_when(
    MaxDU_Res==0 ~ 0,
    MaxDU_Res>=6 ~ 0,
    MaxDU_Res>0 & MaxDU_Res<6 ~ 1
  ))%>%
  mutate(is_sf_factor_6 = as.numeric(is_sf_6))

# Add a variable for defining single family as greater than 0, but less than 10 DU per acre
sf_layer<-sf_layer %>% mutate(
  is_sf_10 = case_when(
    MaxDU_Res==0 ~ 0,
    MaxDU_Res>=10 ~ 0,
    MaxDU_Res>0 & MaxDU_Res<10 ~ 1
  ))%>%
  mutate(is_sf_factor_10 = as.numeric(is_sf_10))
                    


dissim_vars<-merge(dissim_index, sf_layer, on='GEOID10')

dissim_vars %>%
  group_by(is_sf_6)%>%
  summarize(mean_white_minority_dissim_6=mean(White_Minority_Dissim))

dissim_vars %>%
  group_by(is_sf_6)%>%
  summarize(mean_white_black_dissim_6=mean(White_Black_Dissim))


white_min_6<-lm(White_Minority_Dissim ~ is_sf_factor_6, data=dissim_vars)
summary(white_min_6, scale = TRUE)


#https://statisticsbyjim.com/basics/correlations/

cor.test(dissim_vars$White_Minority_Dissim, dissim_vars$is_sf_6,
         method = "spearman")

white_black_6<-lm(White_Black_Dissim ~ is_sf_factor_6, data=dissim_vars)
summary(white_black_6, scale = TRUE)

cor.test(dissim_vars$White_Black_Dissim, dissim_vars$is_sf_10,
         method = "spearman")

dissim_vars %>%
  group_by(is_sf_10)%>%
  summarize(mean_white_minority_dissim_10=mean(White_Minority_Dissim))

dissim_vars %>%
  group_by(is_sf_10)%>%
  summarize(mean_white_minority_dissim_10=mean(White_Black_Dissim))


white_min<-lm(White_Minority_Dissim ~ is_sf_factor_10, data=dissim_vars)
summary(white_min, scale = TRUE)

cor.test(dissim_vars$White_Minority_Dissim, dissim_vars$is_sf_10,
         method = "spearman")

white_black<-lm(White_Black_Dissim ~ is_sf_factor_10, data=dissim_vars)
summary(white_black, scale = TRUE)

cor.test(dissim_vars$White_Black_Dissim, dissim_vars$is_sf_10,
         method = "spearman")

