library(dplyr)
library(corrr)
library(writexl)

dissim_index <- read.csv('dissimilarity_index.csv')
vars_test <- read.csv('census_tract_vars.csv')
sf_under10<-read.csv('sf_under10.csv')

summ<-summary(dissim_index)
correlation_matrix<-correlate(dissim_index)%>%
                    rplot()
  


                    
correlation_matrix
dissim_vars<-merge(dissim_index, vars_test, on='GEOID')
# 
# 
# dissim_vars<- dissim_vars %>% 
#               select_if(is.numeric)
# 
# dissim_all_corrs<-correlate(dissim_vars)%>%
#   writexl::write_xlsx('correlation_matrix_vars.xlsx')

dissim_vars<-dissim_vars %>% mutate(GEOIDchar = as.character(GEOID))
sf_under10<-sf_under10 %>% mutate(GEOIDchar = as.character(GEOID10))

dissim_vars<-merge(dissim_vars,sf_under10, by = 'GEOIDchar')



