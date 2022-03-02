source('travel_survey_analysis_functions.R')


#where you are running your R code
wrkdir <- "C:/Users/SChildress/Documents/GitHub/travel_studies/2019/analysis"

#where you want to output tables
file_loc <- 'C:/Users/SChildress/Documents/HHSurvey/'

sql.trip.query <- paste("SELECT d_puma10, mode_simple, trip_wt_combined FROM HHSurvey.v_trips_2017_2019")
trips <- read.dt(sql.trip.query, 'sqlquery')


trips_no_na<-trips %>% drop_na(all_of('trip_wt_combined'))
group_cat<-'d_puma10'

sample_size_group<- trips_no_na %>%
  group_by(d_puma10) %>%
  count(mode_simple)

sample_size_MOE<- categorical_moe(sample_size_group)

cross_table<-cross_tab_categorical(trips_no_na,group_cat, 'mode_simple', 'trip_wt_combined')
cross_table_w_MOE<-merge(cross_table, sample_size_MOE, by=group_cat)
cross_table_w_MOE<-cross_table_w_MOE %>%
                   group_by(d_puma10) %>%
                   filter(row_number()==1)
write_cross_tab(cross_table_w_MOE,group_cat,'mode_simple',file_loc)

