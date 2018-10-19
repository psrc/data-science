# This script calculates a Low Wage Job to Affordable Housing fit
# Methodology is based on the University of California Davis Urban Geography methods
# 5yr ACS Census Tract data for rentals are pulled for all census tracts via the census api
# Job data is pulled from the LEHD LODES dataset corresponding to the Census Data Year
# Created by Puget Sound Regional Council Staff
# October 2018

import pandas as pd
import urllib
import time   
import os
from shapely.geometry import Point
import geopandas as gp
from simpledbf import Dbf5
import shutil
import gzip
import getpass
import glob

my_key = 'enter your census api key here'
data_year = 2015
acs_data_type = '5yr'

# Geopandas buffering requires the distance in feet
job_access_buffer = 13200

working_directory = os.getcwd()
output_directory = os.path.join(working_directory, 'outputs')

# Download the LEHD LODES Data for the analysis year
print 'Downloading the ' + str(data_year) + ' LODES file for analysis.'
download_file = os.path.join('c:\\Users',getpass.getuser(),'Downloads','wa_wac_S000_JT00_' + str(data_year) + '.csv.gz')
urllib.urlretrieve('https://lehd.ces.census.gov/data/lodes/LODES7/wa/wac/wa_wac_S000_JT00_'+ str(data_year) + '.csv.gz',download_file)

# Uncompress files for use in analysis and then remove the temporary archive file
print 'Uncompressing and loading the ' + str(data_year) + ' LODES file for analysis.'
lodes_archive = os.path.join(download_file)

with gzip.open(lodes_archive) as job_archive:

    job_salary_df = pd.read_csv(job_archive)

# Remove the zip file after the dataframe is created
print 'Removing the tempory ' + str(data_year) + ' LODES download file.'
os.remove(download_file)    

# GIS layers for spatial joins
state_plane = 'epsg:2285'
tract_shapefile = '//file2/Gisapps/geodata/census/Tract/tract2010.shp'
tract_dbf = '//file2/Gisapps/geodata/census/Tract/tract2010.dbf'
tract_projection = '//file2/Gisapps/geodata/census/Tract/tract2010.prj'

block_shapefile = '//file2/Gisapps/geodata/census/Block/block2010.shp'
block_dbf = '//file2/Gisapps/geodata/census/Block/block2010.dbf'

# Create the output directory for the trip generation results
if not os.path.exists(output_directory):
    os.makedirs(output_directory)

# Functions to Download and Format Census API datatables
def gp_table_join(update_table,join_shapefile,join_field):
    
    # open join shapefile as a geodataframe
    join_layer = gp.GeoDataFrame.from_file(join_shapefile)

    # table join
    merged = join_layer.merge(update_table, on=join_field)
    
    return merged

def gp_spatial_join(target_shapefile,join_shapefile,coord_sys,keep_columns):
    
    # open join shapefile as a geodataframe
    join_layer = gp.GeoDataFrame.from_file(join_shapefile)
    join_layer.crs = {'init' :coord_sys}
    
    # open layer that the spaital join is targeting
    target_layer = gp.GeoDataFrame.from_file(target_shapefile)
    target_layer.crs = {'init' :coord_sys}
    
    # spatial join
    merged = gp.sjoin(target_layer, join_layer, how = "inner", op='intersects')
    merged = pd.DataFrame(merged)
    merged = merged.rename(columns={'GEOID10_left':'GEOID10'})
    merged = merged[keep_columns]
    
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

def create_point_from_table(current_df,x_coord,y_coord,coord_sys):
    current_df['geometry'] = current_df.apply(lambda x: Point((float(x[x_coord]), float(x[y_coord]))), axis=1)
    geo_layer = gp.GeoDataFrame(current_df, geometry='geometry')
    geo_layer.crs = {'init' :coord_sys}
    
    return geo_layer

def create_point_from_polygon(polygon_shape,coord_sys):
    poly = gp.read_file(polygon_shape)
    points = poly.copy()
    points.geometry = points['geometry'].centroid
    points.crs = {'init' :coord_sys}
    
    # create a geodataframe for points and return
    geo_layer = gp.GeoDataFrame(points, geometry='geometry')
    geo_layer.crs = {'init' :coord_sys}
    
    return geo_layer

# Download and process the Census tables / data profiles
start_of_production = time.time()

####################################################################################################################
####################################################################################################################
### Census Tract Jobs Estimates by Salary from LEHD
####################################################################################################################
####################################################################################################################

# Create a Census Tract dataframe to join the job data with
print 'Creating a full Census Tract dataframe'
tracts = Dbf5(tract_dbf)
tracts_df = tracts.to_dataframe()
columns_to_keep=['STATEFP10','COUNTYFP10','TRACTCE10']
tracts_df = tracts_df.loc[:,columns_to_keep]
tracts_df .columns = tracts_df.columns.str.lower()
tracts_df['tract_id'] = tracts_df['statefp10'] + tracts_df['countyfp10'] + tracts_df['tractce10']
final_columns = ['tract_id']
tracts_df = tracts_df.loc[:,final_columns]
tracts_df['tract_id'] =tracts_df['tract_id'].astype(float)

# Create a Census Block dataframe to join the job data with
print 'Creating a full Census block dataframe'
blocks = Dbf5(block_dbf)
blocks_df = blocks.to_dataframe()
columns_to_keep=['STATEFP10','COUNTYFP10','TRACTCE10','BLOCKCE10']
blocks_df = blocks_df.loc[:,columns_to_keep]
blocks_df .columns = blocks_df.columns.str.lower()
blocks_df['tract_id'] = blocks_df['statefp10'] + blocks_df['countyfp10'] + blocks_df['tractce10']
blocks_df['block_id'] = blocks_df['statefp10'] + blocks_df['countyfp10'] + blocks_df['tractce10'] + blocks_df['blockce10']
final_columns = ['block_id','tract_id']
blocks_df = blocks_df.loc[:,final_columns]
blocks_df['block_id'] = blocks_df['block_id'].astype(float)
blocks_df['tract_id'] = blocks_df['tract_id'].astype(float)

# Open the LEHD jobs data (by block) and aggregate to Census Tracts
print 'Generating jobs by census block and salary'
columns_to_keep = ['w_geocode','C000','CE01','CE02','CE03']
job_salary_df = job_salary_df[columns_to_keep]
job_salary_df  = job_salary_df.rename(columns={'w_geocode':'block_id'})
job_salary_df['block_id'] = job_salary_df['block_id'].astype(float)
job_salary_df.columns = job_salary_df.columns.str.lower()

# Join the block and jobs by tract together
df_jobs_block = pd.merge(blocks_df, job_salary_df, on='block_id',suffixes=('_x','_y'),how='left')
df_jobs_block.fillna(0,inplace=True)

print 'Generating jobs by census tract and salary'
df_jobs_tract = df_jobs_block.groupby('tract_id').sum()
df_jobs_tract = df_jobs_tract.reset_index()

print 'Final job cleanup and csv export'
final_tracts = pd.merge(tracts_df, df_jobs_tract, on='tract_id',suffixes=('_x','_y'),how='left')
final_columns = ['tract_id','c000','ce01','ce02','ce03']
final_tracts = final_tracts[final_columns]
updated_names = ['tract_id','tot_jobs','lw_jobs','mw_jobs','hw_jobs']
final_tracts.columns = updated_names

####################################################################################################################
####################################################################################################################
### Census Tract Rental information from ACS 5yr
####################################################################################################################
####################################################################################################################

rental_cost = {'B25056_001':('Total Rental Units Occupied','Heading1'),
             'B25056_002':('Total Cash Rent','Heading2'),
             'B25056_003':('Rent < $100','Heading3'),
             'B25056_004':('Rent $100 to $149','Heading3'),
             'B25056_005':('Rent $150 to $199','Heading3'),
             'B25056_006':('Rent $200 to $249','Heading3'),
             'B25056_007':('Rent $250 to $299','Heading3'),
             'B25056_008':('Rent $300 to $349','Heading3'),
             'B25056_009':('Rent $350 to $399','Heading3'),
             'B25056_010':('Rent $400 to $449','Heading3'),
             'B25056_011':('Rent $450 to $499','Heading3'),
             'B25056_012':('Rent $500 to $549','Heading3'),
             'B25056_013':('Rent $550 to $599','Heading3'),
             'B25056_014':('Rent $600 to $649','Heading3'),
             'B25056_015':('Rent $650 to $699','Heading3'),
             'B25056_016':('Rent $700 to $749','Heading3'),
             'B25056_017':('Rent $750 to $799','Heading3'),
             'B25056_018':('Rent $800 to $899','Heading3'), 
             'B25056_019':('Rent $900 to $999','Heading3'), 
             'B25056_020':('Rent $1000 to $1249','Heading3'), 
             'B25056_021':('Rent $1250 to $1499','Heading3'), 
             'B25056_022':('Rent $1500 to $1999','Heading3'), 
             'B25061_001':('Total Vacant Units','Heading3') ,                                            
             'B25061_002':('Vacant - Rent < $100','Heading3'),
             'B25061_003':('Vacant - Rent $100 to $149','Heading3'),
             'B25061_004':('Vacant - Rent $150 to $199','Heading3'),
             'B25061_005':('Vacant - Rent $200 to $249','Heading3'),
             'B25061_006':('Vacant - Rent $250 to $299','Heading3'),
             'B25061_007':('Vacant - Rent $300 to $349','Heading3'),
             'B25061_008':('Vacant - Rent $350 to $399','Heading3'),
             'B25061_009':('Vacant - Rent $400 to $449','Heading3'),
             'B25061_010':('Vacant - Rent $450 to $499','Heading3'),
             'B25061_011':('Vacant - Rent $500 to $549','Heading3'),
             'B25061_012':('Vacant - Rent $550 to $599','Heading3'),
             'B25061_013':('Vacant - Rent $600 to $649','Heading3'),
             'B25061_014':('Vacant - Rent $650 to $699','Heading3'),
             'B25061_015':('Vacant - Rent $700 to $749','Heading3'),
             'B25061_016':('Vacant - Rent $750 to $799','Heading3'),
             'B25061_017':('Vacant - Rent $800 to $899','Heading3'), 
             'B25061_018':('Vacant - Rent $900 to $999','Heading3'), 
             'B25061_019':('Vacant - Rent $1000 to $1249','Heading3'), 
             'B25061_020':('Vacant - Rent $1250 to $1499','Heading3'), 
             'B25061_021':('Vacant - Rent $1500 to $1999','Heading3')
               }
    
census_tables = [[acs_data_type, 'B25056', rental_cost,'Rental Cost']]

column_names = ['Estimate','Margin of Error','State','County','Tract','DataTable','Subject','Level','Year']
numeric_columns = ['Estimate','Margin of Error']

rental_tracts_df = tracts_df

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
        current_df['tract_id'] = current_df['State'] + current_df['County'] + current_df['Tract']
        current_df['tract_id'] = current_df['tract_id'].astype(float)
        columns_to_remove = ['Error','State','County','Tract','DataTable']
        current_df = current_df.drop(columns=columns_to_remove)
        
        # Merge the Tract Dataframe with the Current Data based on tract_id
        rental_tracts_df = pd.merge(rental_tracts_df, current_df, on='tract_id',suffixes=('_x','_y'),how='left') 

print 'Calculating the number of occupied units that are afforable for low income people'
rental_tracts_df['affordable-occupied-units'] = rental_tracts_df['Rent < $100'] \
+ rental_tracts_df['Rent $100 to $149'] \
+ rental_tracts_df['Rent $150 to $199'] \
+ rental_tracts_df['Rent $200 to $249'] \
+ rental_tracts_df['Rent $250 to $299'] \
+ rental_tracts_df['Rent $300 to $349'] \
+ rental_tracts_df['Rent $350 to $399'] \
+ rental_tracts_df['Rent $400 to $449'] \
+ rental_tracts_df['Rent $450 to $499'] \
+ rental_tracts_df['Rent $500 to $549'] \
+ rental_tracts_df['Rent $550 to $599'] \
+ rental_tracts_df['Rent $600 to $649'] \
+ rental_tracts_df['Rent $650 to $699'] \
+ rental_tracts_df['Rent $700 to $749']  

print 'Calculating the number of vacant units that are afforable for low income people'
rental_tracts_df['affordable-vacant-units'] = rental_tracts_df['Vacant - Rent < $100'] \
+ rental_tracts_df['Vacant - Rent $100 to $149'] \
+ rental_tracts_df['Vacant - Rent $150 to $199'] \
+ rental_tracts_df['Vacant - Rent $200 to $249'] \
+ rental_tracts_df['Vacant - Rent $250 to $299'] \
+ rental_tracts_df['Vacant - Rent $300 to $349'] \
+ rental_tracts_df['Vacant - Rent $350 to $399'] \
+ rental_tracts_df['Vacant - Rent $400 to $449'] \
+ rental_tracts_df['Vacant - Rent $450 to $499'] \
+ rental_tracts_df['Vacant - Rent $500 to $549'] \
+ rental_tracts_df['Vacant - Rent $550 to $599'] \
+ rental_tracts_df['Vacant - Rent $600 to $649'] \
+ rental_tracts_df['Vacant - Rent $650 to $699'] \
+ rental_tracts_df['Vacant - Rent $700 to $749']

print 'Cleaning up and outputting rental units by tract'
rental_tracts_df['total-affordable-units'] = rental_tracts_df['affordable-occupied-units'] + rental_tracts_df['affordable-vacant-units']
rental_tracts_df['total-units'] = rental_tracts_df['Total Rental Units Occupied'] + rental_tracts_df['Total Vacant Units']
final_columns = ['tract_id','total-affordable-units','total-units']
rental_tracts_df = rental_tracts_df[final_columns]
updated_names = ['tract_id','aff_units','tot_units']
rental_tracts_df.columns = updated_names

print 'Merge jobs and rental units by census tract'
final_tracts = pd.merge(final_tracts, rental_tracts_df, on='tract_id',suffixes=('_x','_y'),how='left')

####################################################################################################################
####################################################################################################################
### Tract Buffering
####################################################################################################################
####################################################################################################################
print 'Creating buffers around all census tracts - buffer distance is ' + str(job_access_buffer) + ' feet'

# Create a geodataframe of Census Tracts from the Job and Housing dataframe and write out the shapefile
print 'Creating a tract shapefile from the full dataframe that includes the housing and job data'
tract_with_data = os.path.join(output_directory,'tract_data.shp')
final_tracts['GEOID10'] = final_tracts['tract_id'].astype('int64')
final_tracts['GEOID10'] = final_tracts['GEOID10'].astype(str)
full_tract_df = gp_table_join(final_tracts, tract_shapefile, 'GEOID10')
full_tract_df.to_file(tract_with_data)
shutil.copyfile(tract_projection, os.path.join(output_directory,'tract_data.prj'))

# Create a buffer file from the centroid points of all the Census Tracts
print 'Creating a buffered centroid point shapefile for all census tracts to buffer against'
tract_centroids = create_point_from_polygon(tract_shapefile,state_plane)
tract_centroids['buffer_distance'] = job_access_buffer
tract_centroids['geometry'] = tract_centroids.apply(lambda x: x.geometry.buffer(x.buffer_distance), axis=1)
tract_centroids.to_file(os.path.join(output_directory,'all_tract_buffers.shp'))
shutil.copyfile(tract_projection, os.path.join(output_directory,'all_tract_buffers.prj'))

# Add total jobs and total units columns to store buffered results in full tract dataframe
final_tracts['lw_job_acc'] = 0
final_tracts['af_unt_acc'] = 0

# Cycle through the tract buffers and figure out how many jobs are accessbile
for rows in range(0, (len(final_tracts))):
    print 'Working on Census Tract ' + str(rows) + ' of ' + str(len(final_tracts))
    current_tract = final_tracts['GEOID10'][rows]
    working_tract_buffer = os.path.join(output_directory,'working_tract_buffer.shp')
    tract_centroids[tract_centroids['GEOID10']==current_tract].to_file(working_tract_buffer)
    shutil.copyfile(tract_projection, os.path.join(output_directory,'working_tract_buffer.prj'))

    # Calculate the number of Affordable Units and Low-Wage Jobs in the Buffer
    columns_to_keep = ['GEOID10','aff_units','lw_jobs']
    joined_df = gp_spatial_join(tract_with_data,working_tract_buffer,state_plane,columns_to_keep)
    total_lw_jobs_buffered = sum(joined_df['lw_jobs'])
    total_afforable_units_buffered = sum(joined_df['aff_units'])

    final_tracts['lw_job_acc'][rows] = total_lw_jobs_buffered
    final_tracts['af_unt_acc'][rows] = total_afforable_units_buffered

# Write final tract csv file 
final_tracts['job_unit_ratio'] = final_tracts['lw_job_acc'] / final_tracts['af_unt_acc']
print 'Exporting the final csv and shapefiles'
final_tracts.to_csv(os.path.join(output_directory, 'jobs_and_rental_units_by_tract_'+str(data_year)+'.csv'),index=False) 

final_tract_df = gp_table_join(final_tracts, tract_shapefile, 'GEOID10')
final_tract_df.to_file(os.path.join(output_directory,'job_housing_fit_tract_data_' + str(data_year) + '.shp'))
shutil.copyfile(tract_projection, os.path.join(output_directory,'job_housing_fit_tract_data_' + str(data_year) + '.prj'))
               
# Remove the temporary shapefiles created during the process
print 'Deleting the temporary shapefiles that were used during the buffering process'
[os.remove(x) for x in glob.glob(os.path.join(output_directory,'all_tract_buffers.*'))]
[os.remove(x) for x in glob.glob(os.path.join(output_directory,'tract_data.*'))]
[os.remove(x) for x in glob.glob(os.path.join(output_directory,'working_tract_buffer.*'))]

end_of_production = time.time()
print 'The Total Time for all processes took', (end_of_production-start_of_production)/60, 'minutes to execute.'
exit()