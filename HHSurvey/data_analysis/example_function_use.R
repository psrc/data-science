source('travel_survey_analysis_functions.R')
# Code Examples -----------------------------------------------------------
#Read the data from Elmer

#You can do this by using read.dt function. The function has two arguments: 
# first argument passes a sql query or a table name (as shown in Elmer)
# in the second argument user should specify if the first argument is 'table_name' or 'sqlquery'

#Here is an example using sql query - first, you need to create a variable with the sql query
# and then pass this variable to the read.dt function
sql.query = paste("SELECT * FROM HHSurvey.v_persons_2017_2019_in_house")
person = read.dt(sql.query, 'sqlquery')

#If you would like to use the table name, instead of query, you can use the following code
#that will produce the same results
person = read.dt("HHSurvey.v_persons_2017_2019", 'table_name')


#Check the data
# this step will allow you to understand the variable and the table that you are analyzing
#you can use the following functions to check for missing values, categories, etc.

#this function will allow you to see all of the variables in the table, check the data type,
#and see the first couple of values for each of the variables
glimpse(person)

# to check the distribution of a specific variable, you can use the following code
#here, for example, we are looking at mode_freq_5 category 
person %>% group_by() %>% summarise(n=n())

#if you analyze a numerical variable, you can use the following code to see the variable range
describe()


#to delete NA you can use the following code
#the best practices suggest to create a new variable with the updated table

person_no_na = person %>% filter(!is.na(mode_freq_5))

#when we re-run the distribution code, we see that we've eliminated NAs
person_no_na %>% group_by(mode_freq_5) %>% summarise(n=n())

# to exclude missing codes, you can use the following code
#note, that we've assigned missing_codes at the beginning of the script(lines 20-21)
person_no_na = person_no_na %>% filter(!mode_freq_5 %in% missing_codes)


#Create summaries

# to create a summary table based on one variable, you can use create_table_one_var function.
#The function create_table_one_var has 3 arguments:
# first, you have to specify the variable you are analyzing
#second, enter table name
#third, specify the table type e.g. person, household, vehicle, trip, or day. This will
# help to use correct weights

#here is an example for mode_freq_5 variable

create_table_one_var("mode_freq_5", person_no_na,"person" )



# Two-way table -----------------------------------------------------------


# This is an example of how to create a two-way table, including counts, weighted totals, shares, and margins of error.
# The analysis is for race of a person by whether they have a driver's license or permit.

# First before you start calcuating
# you will need to determine the names of the data fields you are using, 
# the weight to use, and an id for counting.

# User defined variables on each analysis:

# this is the weight for summing in your analysis
person_wt_field<- 'hh_wt_combined'
# this is a field to count the number of records
person_count_field<-'person_dim_id'
# this is how you want to group the data in the first dimension,
# this is how you will get the n for your sub group
group_cat <- 'race_category'
# this is the second thing you want to summarize by
var <- 'license'

# filter data missing weights
persons_no_na<-person %>% drop_na(all_of(person_wt_field))

# now find the sample size of your subgroup
sample_size_group<- persons_no_na %>%
  group_by(race_category) %>%
  summarize(sample_size = n_distinct((person_dim_id)))

# get the margins of error for your groups
sample_size_MOE<- categorical_moe(sample_size_group)

# calculate totals and shares
cross_table<-cross_tab_categorical(persons_no_na,group_cat,var, person_wt_field)

# merge the cross tab with the margin of error
cross_table_w_MOE<-merge(cross_table, sample_size_MOE, by=group_cat)

# it looks like People of Color are more likely to not have a driver's license.
# There is not enough data to summarize some of the categories such as learner's permit.
# The children mostly do not answer this question (only for driver's age children.)
cross_table_w_MOE
# optional step:  write it out to a file
#file_loc <- 'C:/Users/SChildress/Documents/GitHub/travel-studies/2019/analysis'
