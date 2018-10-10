# This script pulls Tract Level Census Data from the Census API
# for use in defining tracts with equity populations
# Created by Puget Sound Regional Council Staff
# October 2018

import pandas as pd
import urllib   
import os
import geopandas as gp
from simpledbf import Dbf5

# ACS Datatables and years
my_key = 'enter your census api key here'
data_year = 2016
acs_data_type = '5yr'

# Ratio to identify tract as being an equity geography
equity_ratio = 0.50

minority_status = {'B03002_001':('Total Pop w Race','Heading1'),
                   'B03002_003':('White Alone','Heading2')}

poverty_status = {'C17002_001':('Total Pop w Poverty','Heading1'),
                  'C17002_008':('2.00 or higher','Heading2')}

# GIS layers for spatial joins
state_plane = 'epsg:2285'
tract_shapefile = '//file2/Gisapps/geodata/census/Tract/tract2010.shp'
tract_dbf = '//file2/Gisapps/geodata/census/Tract/tract2010.dbf'

working_directory = os.getcwd()
output_directory = os.path.join(working_directory, 'outputs')

# Create the output directory for the trip generation results
if not os.path.exists(output_directory):
    os.makedirs(output_directory)
    
census_tables = [[acs_data_type, 'B03002', minority_status,'Race'],
                 [acs_data_type, 'C17002', poverty_status,'Poverty']]

column_names = ['Estimate','Margin of Error','State','County','Tract','DataTable','Subject','Level','Year']
numeric_columns = ['Estimate','Margin of Error']

# Functions to Download and Format Census API datatables
def gp_table_join(update_table,join_shapefile,join_field):
    
    # open join shapefile as a geodataframe
    join_layer = gp.GeoDataFrame.from_file(join_shapefile)

    # table join
    merged = join_layer.merge(update_table, on=join_field)
    
    return merged

def download_census_data(data_url):

    response = urllib.urlopen(data_url)
    census_data = response.read()
    
    return census_data

def format_census_tables(census_download, working_table):
    working_df = pd.read_json(census_download)
    working_df = working_df.rename(columns=working_df.iloc[0]).drop(working_df.index[0])
    
    working_df['DataTable'] = working_df.columns[0]
    working_df['DataTable'] = working_df['DataTable'].map(lambda x: str(x)[:-1]) 
    my_table = working_df.iloc[0]['DataTable'] 
    updated_names = [working_table[my_table][0],'Error','State','County','Tract','DataTable']
    working_df.columns = updated_names
    working_df[working_table[my_table][0]] = working_df[working_table[my_table][0]].apply(float)
                
    return working_df

# Create A Cenus Tract Dataframe to join the estimate data with
print 'Creating a full Census Tract dataframe from the shapefile to join final data with'
tracts = Dbf5(tract_dbf)
tracts_df = tracts.to_dataframe()
columns_to_keep=['GEOID10','COUNTYFP10']
tracts_df = tracts_df.loc[:,columns_to_keep]
updated_names = ['GEOID10','County']
tracts_df.columns = updated_names

# Census Tract Popualtion Estimates
for tables in census_tables:
    print 'Downloading and assembling ' +  tables[3] + ' Census Tract information.'   

    for key, value in tables[2].iteritems():
        census_data= key +'E',key +'M'
        
        # Create the query and do the census api call to collect the data in json format
        census_data = ','.join(census_data)
        census_api_call = 'https://api.census.gov/data/' + str(data_year) + '/acs/acs5?get=' + census_data + '&for=tract:*&in=state:53&in=county:033,035,053,061' + '&key=' + my_key
        downloaded_data = download_census_data(census_api_call)
        
        current_df = format_census_tables(downloaded_data, tables[2])
        
        # Trim Out extra columns before merging with full tract set
        current_df['GEOID10'] = current_df['State'] + current_df['County'] + current_df['Tract']
        columns_to_remove = ['Error','State','County','Tract','DataTable']
        current_df = current_df.drop(columns=columns_to_remove)
        
        # Merge the Tract Dataframe with the Current Data based on GEOID10
        tracts_df = pd.merge(tracts_df, current_df, on='GEOID10',suffixes=('_x','_y'),how='left') 

# Calcualte Total and Shares by breakpoints
print 'Calculating minority population and shares of population by tract'
tracts_df['minority'] = tracts_df['Total Pop w Race'] - tracts_df['White Alone']
tracts_df['pct_minority'] = tracts_df['minority'] / tracts_df['Total Pop w Race']

print 'Calculating poverty population and shares of population by tract'
tracts_df['poverty'] = tracts_df['Total Pop w Poverty'] - tracts_df['2.00 or higher']
tracts_df['pct_poverty'] = tracts_df['poverty'] / tracts_df['Total Pop w Poverty']

# Add County Level Percentages of minority populations to the dataframe
print 'Calculating regional poverty and minority shares of total population'
regional_minority = sum(tracts_df['minority']) / sum(tracts_df['Total Pop w Race'])
regional_poverty = sum(tracts_df['poverty']) / sum(tracts_df['Total Pop w Poverty'])

# Add a column and flag if the minority and income shares are greater than the regional average
print 'Comparing tract share of equity populations to the regional average'
tracts_df['Above-Regional-Minority'] = 0
tracts_df['Above-Regional-Poverty'] = 0
tracts_df.loc[tracts_df['pct_minority'] >= regional_minority, 'Above-Regional-Minority'] = 1
tracts_df.loc[tracts_df['pct_poverty'] >= regional_poverty, 'Above-Regional-Poverty'] = 1

# Add a column and flag if the minority and income shares are greater than the defined ratio
print 'Comparing tract share of equity populations to a ratio of ' + str(equity_ratio)
tracts_df['Above-Ratio-Minority'] = 0
tracts_df['Above-Ratio-Poverty'] = 0
tracts_df.loc[tracts_df['pct_minority'] >= equity_ratio, 'Above-Ratio-Minority'] = 1
tracts_df.loc[tracts_df['pct_poverty'] >= equity_ratio, 'Above-Ratio-Poverty'] = 1

# Clean up the final dataframe and export to csv
print 'Cleaning up final dataframe and exporting to csv to ' + output_directory 
final_columns = ['GEOID10',
                 'County',
                 'Total Pop w Race',
                 'minority',
                 'pct_minority',
                 'Above-Regional-Minority',
                 'Above-Ratio-Minority',
                 'Total Pop w Poverty',
                 'poverty',
                 'pct_poverty',
                 'Above-Regional-Poverty',
                 'Above-Ratio-Poverty']

final_df = tracts_df[final_columns]
final_df.to_csv(os.path.join(output_directory, 'equity_populations_by_tract_acs5yr_'+str(data_year)+'.csv'),index=False)                

# Join to the original shapefile and write out the final shapefile
print 'Creating the shapefiles and outputing to ' + output_directory 
working_shapefile = gp_table_join(final_df, tract_shapefile,'GEOID10')
working_shapefile.to_file(os.path.join(output_directory,'equity_populations_by_tract_acs5yr_'+str(data_year)+'.shp')) 
         
exit()



