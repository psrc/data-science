# Load Libraries ----------------------------------------------------------

library(data.table)
library(tidyverse)
library(DT)
library(openxlsx)
library(odbc)
library(DBI)
library(psych)

# Statistical assumptions for margins of error
p_MOE <- 0.5
z<-1.645
missing_codes <- c('Missing: Technical Error', 'Missing: Non-response', 
                   'Missing: Skip logic', 'Children or missing', ' Prefer not to answer')

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

#Create a crosstab from two variables, calculate counts, totals, and shares,
# for categorical data
cross_tab_categorical <- function(table, var1, var2, wt_field) {
  expanded <- table %>% 
    group_by(.data[[var1]],.data[[var2]]) %>%
    summarise(Count= n(),Total=sum(.data[[wt_field]])) %>%
    group_by(.data[[var1]])%>%
    mutate(Percentage=Total/sum(Total)*100)
  
  
  expanded_pivot <-expanded%>%
    pivot_wider(names_from=.data[[var2]], values_from=c(Percentage,Total, Count))
  
  return (expanded_pivot)
  
} 

# Create margins of error for dataset
categorical_moe <- function(sample_size_group){
  sample_w_MOE<-sample_size_group %>%
    mutate(p_col=p_MOE) %>%
    mutate(MOE_calc1= (p_col*(1-p_col))/sample_size) %>%
    mutate(MOE_Percent=z*sqrt(MOE_calc1))
  
  sample_w_MOE<- select(sample_w_MOE, -c(p_col, MOE_calc1))
  
  return(sample_w_MOE)
}   

#Load person table
person = read.dt("HHSurvey.v_persons_2017_2019_in_house", 'table_name')

#Filter out NAs for variables
person_no_na = person %>% filter(!is.na(telecommute_freq))
person_no_na = person_no_na %>% filter(!telecommute_freq %in% missing_codes)
person_no_na = person %>% filter(!is.na(workplace))
person_no_na = person_no_na %>% filter(!workplace %in% missing_codes)

#Generate sample size numbers and MOE
sample_size_group<- person_no_na %>%
  group_by(telecommute_freq) %>%
  summarize(sample_size = n())

sample_size_MOE<- categorical_moe(sample_size_group)

#Define weights and variables for cross table function
person_wt_field<- 'hh_wt_combined'
person_count_field<-'person_dim_id'
group_cat <- 'telecommute_freq'
var <- 'workplace'

#Create final cross tables
cross_table<-cross_tab_categorical(person_no_na,group_cat,var, person_wt_field)
cross_table_w_MOE<-merge(cross_table, sample_size_MOE, by=group_cat)
