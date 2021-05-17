library(dplyr)
library(corrr)
library(writexl)

dissim_index <- read.csv('dissimilarity_index.csv')
vars_test <- read.csv('census_tract_vars.csv')

summ<-summary(dissim_index)
correlation_matrix<-correlate(dissim_index)%>%
                    rplot()
  
  
                    writexl::write_xlsx('index_correlation_matrix.xlsx')

                    
correlation_matrix
dissim_vars<-merge(dissim_index, vars_test, on='GEOID')


dissim_vars<- dissim_vars %>% 
              select_if(is.numeric)

dissim_all_corrs<-correlate(dissim_vars)%>%
  writexl::write_xlsx('correlation_matrix_vars.xlsx')
