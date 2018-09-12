# This script creates data summaries in the PSRC region
# Created by Puget Sound Regional Council Staff
# December 2017

# Load the libraries we need
import pandas as pd
import urllib
import time
import datetime as dt
import matplotlib.pyplot as plt     

# I have some hard codes I need to get out of here.


working_directory = r'C:\Users\SChildress\Documents\Census'
my_key = 'd35ff72cb418d90e16e0a6e221a69c00e1209c5c'
base_year ='2016'
comparison = '2012'


geography_ids = {'033': ('county','King','co'),
                       '035': ('county','Kitsap','co'),
                       '053': ('county','Pierce','co'),
                       '061': ('county','Snohomish','co'),
                       '03180':('place','Auburn' ,'place'),
                       '05210':('place','Bellevue' ,'place'),
                       '22640':('place','Everett' ,'place'),
                       '23515':('place','Federal Way' ,'place'),
                       '35415':('place','Kent', 'place'),
                       '57745':('place','Renton' ,'place'),
                       '63000':('place','Seattle' ,'place'),
                       '70000':('place','Tacoma' ,'place')
                      }



## Dictionaries for Census Data Tables with labels
tables = {'$02*001%':'Total Households',
          '$02*013P%': 'Households % People Under 18',
          '$02*014P%': 'Households % People Over 65',
          '$02*015%': 'Average HH Size',
          '$03*061P%': 'Income Over 200K',
          '$05*017%': 'Median Age',
          '$05*032P%': 'Percent One race White',
          #'$05*033P%': 'Percent One race Black',
          '$05*039P%': 'Percent One race Asian',
          '$02*071P%': 'Percent with a Disability',
          '$02*079P%' : 'Percent in Same House LY',
          '$02*088P%' : 'Percent Born in US',
          #'$02*151P%' : 'Percent with a Computer',
          '$02*067P%' : 'Percent with Bachelor Degree ',
          '$03*062%': 'Median Income',
          '$03*074P%': 'Percent with foodstamps',
          '$03*096P%' : 'Percent with Health Insurance',
          '$03*119P%': 'Percent families below poverty',
          '$03*019P%' : 'Percent Drove Alone',
          '$03*025P%' : 'Mean travel time to work',
          '$03*004P%' : 'Civilian Percent  employed'
         }




# Functions to Download and Format Census API datatables
def create_census_url_dp(dataset, data_tables, geography_type, geography_id, year, api_key, data_type):
    data_tables = data_tables.replace('*','_0')
    data_tables = data_tables.replace('%', data_type)
    data_tables = data_tables.replace('$', 'DP')
    census_api_call = 'https://api.census.gov/data/' + str(year) + '/'+ dataset + '/profile/' + '?get=' + data_tables + '&' + 'for='+geography_type+':'+ geography_id+ '&in=state:53'+ '&key=' + api_key
    print census_api_call
    return census_api_call


def get_data(url_call, returns_text, current_df, label, first_call):
    #print url_call
    #print label
    next_df= pd.read_json(download_census_data(url_call))
    next_df.drop(next_df.columns[[2,3]], axis=1, inplace=True)
    next_df.columns = ['Geography', tables[key]+'_'+ label]
    next_df = next_df.iloc[1:]

    if returns_numeric:
        next_df[tables[key]+'_'+ label]=pd.to_numeric(next_df[tables[key]+'_'+ label], errors='ignore')

    if not first_call:
        next_df = pd.merge(current_df, next_df, on = 'Geography')

    return next_df

def download_census_data(data_url):

    response = urllib.urlopen(data_url)
    census_data = response.read()
    
    return census_data

for key in tables:
    writer = pd.ExcelWriter(working_directory + '/output/acs'+'-'+ tables[key]+'.xlsx')
    
    print key
    census_data = 'NAME,'+key
    new_df = pd.DataFrame()

    for geography_id in geography_ids:

            current_df = pd.DataFrame()
            returns_numeric = True
            # get the two values for the years
            dataset = 'acs/acs1'
            # get the value for the first year
            first_call = True
            
            #get the MOE for the first item
            label ='estimate'
            data_type = 'E'
            dataset = 'acs1'
            returns_numeric=  True
            url_call = create_census_url_dp(dataset, census_data, geography_ids[geography_id][0], geography_id,comparison, my_key, data_type)
            current_df = get_data(url_call, returns_numeric, current_df,str(comparison)+'_estimate', first_call )

            first_call = False
            #get the MOE ffor the second item
            dataset = 'acs/acs1'
            url_call = create_census_url_dp(dataset, census_data, geography_ids[geography_id][0], geography_id,base_year, my_key, data_type)
            current_df = get_data(url_call, returns_numeric, current_df,str(base_year)+'_estimate',first_call )


            #get the MOE for the first item
            label ='margin of_error'
            dataset = 'acs1'
            returns_numeric=  True
            data_type = 'M'
            url_call = create_census_url_dp(dataset, census_data, geography_ids[geography_id][0], geography_id,comparison, my_key,data_type)
            current_df = get_data(url_call, returns_numeric, current_df,str(comparison)+'_MOE', first_call )

            #get the MOE ffor the second item
            dataset = 'acs/acs1'
            url_call = create_census_url_dp(dataset, census_data, geography_ids[geography_id][0], geography_id,base_year, my_key, data_type)
            current_df = get_data(url_call, returns_numeric, current_df,str(base_year)+'_MOE',first_call)

            new_df = new_df.append(current_df)

    new_df.to_excel(writer, sheet_name = tables[key], index = False)
    new_df.set_index('Geography', drop=True,inplace=True)
    df_estimates = new_df[new_df.columns[0:2]]
    df_errors = new_df[new_df.columns[2:4]]
    df_errors.columns = df_estimates.columns

    df_plot = df_estimates.plot(kind='bar', yerr = df_errors)
    fig = df_plot.get_figure()
    fig.tight_layout()

    fig.savefig(working_directory + '/output/acs'+  tables[key])
    
    writer.save()