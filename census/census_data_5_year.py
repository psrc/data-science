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


working_directory = r'C:\Users\SChildress\Documents\Census Data'
my_key = 'd35ff72cb418d90e16e0a6e221a69c00e1209c5c'
base_year ='2016'


geography_ids = {'033': ('county','King','co'),
                       '035': ('county','Kitsap','co'),
                       '053': ('county','Pierce','co'),
                       '061': ('county','Snohomish','co')
                      }



## Dictionaries for Census Data Tables with labels
tables = {'$25104_001E' : 'MONTHLY HOUSING COSTS'}




# Functions to Download and Format Census API datatables
def create_census_url(dataset, data_tables, geography_type, geography_id, year, api_key, data_type):
    data_tables = data_tables.replace('*','_0')
    data_tables = data_tables.replace('%', data_type)
    data_tables = data_tables.replace('$', 'B')
    census_api_call = 'https://api.census.gov/data/' + str(year) + '/'+ dataset  + '?get=' + data_tables + '&' + 'for=tract:*&in=state:53%20'+geography_type+':'+ geography_id + '&key='+ api_key
    print census_api_call
    return census_api_call



def download_census_data(data_url):

    response = urllib.urlopen(data_url)
    census_data = response.read()
    
    return census_data

for key in tables:
    writer = pd.ExcelWriter(working_directory + tables[key]+'.xlsx')
    
    print key
    census_data = 'NAME,'+key
    new_df = pd.DataFrame()

    for geography_id in geography_ids:

            current_df = pd.DataFrame()
            dataset = 'acs/acs5'

            label ='estimate'
            data_type = 'E'
            dataset = 'acs/acs5'
            returns_numeric=  True
            url_call = create_census_url(dataset, census_data, geography_ids[geography_id][0], geography_id,base_year, my_key, data_type)
            current_df = pd.read_json(download_census_data(url_call))
            print current_df


            new_df = new_df.append(current_df)

    new_df.to_excel(writer, index = False)

    
    writer.save()