# This script pulls Population Data from the Census API
# Created by Puget Sound Regional Council Staff
# January 2019

import pandas as pd
import urllib  

my_key = 'enter your census api key here'
acs_data_type = '5yr'

def create_population_table(working_geography,analysis_years):
    
    working_geography.replace(" ", "%20")

    current_count = 0
    for years in analysis_years:

        # Census Population Data
        print 'Downloading the ' + working_geography + ' population for ' + str(years)
        census_api_call = 'https://api.census.gov/data/' + str(years) + '/acs/acs5?get=B01001_001E,NAME&for='+working_geography+':*' + '&key=' + my_key
        response = urllib.urlopen(census_api_call)
        census_data = response.read()

        print 'Creating a dataframe from the downloaded data and cleaning it up'
        working_df = pd.read_json(census_data)
        working_df = working_df.rename(columns=working_df.iloc[0]).drop(working_df.index[0])
        updated_names = ['value','name','geoid','year']    
        
        if working_geography == 'county':
            working_df['geoid'] = working_df.state.str.cat(working_df.county)
            working_df  = working_df.drop(columns=['state','county'])
            
        working_df['year'] = years
        working_df.columns = updated_names
        working_df  = working_df.drop(columns=['name'])
        working_df['value'] = working_df['value'].apply(int)
        working_df['geoid'] = working_df['geoid'].apply(str)
    
        if current_count == 0:
            final_df = working_df
        
        else:
            final_df = final_df.append(working_df)
    
        current_count = current_count + 1
        
    return final_df
