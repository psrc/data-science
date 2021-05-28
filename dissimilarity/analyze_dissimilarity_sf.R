library(dplyr)
library(corrr)
library(writexl)
library(ggplot2)


setwd("~/GitHub/data-science/dissimilarity")

dissim_index <- read.csv('dissim_bg.csv')
sf_layer<- read.csv('sf_under10.csv')

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


ggplot(dissim_vars, aes(x=MaxDU_Res, y=White_Black_Dissim))+
  geom_point()+
  geom_smooth(method=lm)

ggplot(dissim_vars, aes(x=White_Black_Dissim)) + geom_histogram()

ggplot(dissim_vars, aes(x=White_Minority_Dissim)) + geom_histogram()

white_black_lm<-lm(White_Black_Dissim ~ MaxDU_Res, data=dissim_vars)
summary(white_black_lm, scale = TRUE)