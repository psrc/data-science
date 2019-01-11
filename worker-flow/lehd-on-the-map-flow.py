# This script summarizes the LEHD On-the_Map Worker Flow
# Results are saved as tables in the Sandbox(test) database
# Data contains the home county of a worker and what Census Blockgroup they work in
# Created by Puget Sound Regional Council Staff
# January 2019

import pandas as pd
import time
import os
import pyodbc
from simpledbf import Dbf5
import geopandas as gp

working_tablename = 'lehd_otm_county_workers'

start_year = 2005
end_year = 2015

analysis_years = []

for x in range(start_year,end_year+1):
   
    analysis_years.append(x)

counties = {'king':'033',
            'kitsap':'035',
            'pierce':'053',
            'snohomish':'061'}

working_directory = os.getcwd()
input_directory = os.path.join(working_directory, 'input')

# Shapefiles
blockgroup_shapefile = os.path.join(input_directory, 'blockgroups','wa_blockgroups_wgs1984.shp')
city_shapefile = os.path.join(input_directory, 'cities','cities_wgs1984.shp')

blockgroup_dbf = os.path.join(input_directory, 'blockgroups','wa_blockgroups_wgs1984.dbf')

wgs_coordsys = 'epsg:4326'

def create_point_from_polygon(polygon_shape,coord_sys):
    poly = gp.read_file(polygon_shape)
    points = poly.copy()
    points.geometry = points['geometry'].centroid
    points.crs = {'init' :coord_sys}
    
    # create a geodataframe for points and return
    geo_layer = gp.GeoDataFrame(points, geometry='geometry')
    geo_layer.crs = {'init' :coord_sys}
    
    return geo_layer

def gp_spatial_join(target_layer,join_shapefile,coord_sys,keep_columns):
    
    # open join shapefile as a geodataframe
    join_layer = gp.GeoDataFrame.from_file(join_shapefile)
    join_layer.crs = {'init' :coord_sys}

    # spatial join
    merged = gp.sjoin(target_layer, join_layer, how = "inner", op='intersects')
    merged = pd.DataFrame(merged)
    merged = merged[keep_columns]
    
    return merged

# SQL Connection to our internal SQL database Elmer
sql_conn = pyodbc.connect('DRIVER={SQL Server}; SERVER=sql2016\DSADEV;DATABASE=Sandbox;trusted_connection=true')
cursor = sql_conn.cursor()

start_of_production = time.time()

# Spatial Join Block Groupss and City Layers to create a blockgroup/city equivalency
print 'creating a blockgroup and city layer file'
keep_columns = ['GEOID','CityName']
bg_layer = create_point_from_polygon(blockgroup_shapefile, wgs_coordsys)
merged_bg = gp_spatial_join(bg_layer, city_shapefile, wgs_coordsys, keep_columns)

# Create A Cenus Tract Dataframe to join the estimate data with
print 'creating a full census blockgroup dataframe from the shapefile to join final data with'
blockgroups = Dbf5(blockgroup_dbf)
bg_df = blockgroups.to_dataframe()
columns_to_keep=['GEOID','COUNTYFP']
bg_df = bg_df.loc[:,columns_to_keep]

print 'adding city name to the blockgroup layer to join results with'
bg_df = pd.merge(bg_df, merged_bg, on='GEOID',suffixes=('_x','_y'),how='left')
bg_df.fillna('Unincorporated',inplace=True)

print 'final cleanup of column names in master blockgroup file'
updated_names = ['work_blockgroup','work_county', 'work_city']
bg_df.columns = updated_names

i = 0

for key, value in counties.iteritems():

    for current_year in analysis_years:
        
        interim_df = []
        
        print 'opening the ' + str(current_year) + ' worker-flow point file for ' + key + ' county'
        work_flow =  os.path.join(input_directory, key, 'points_'+str(current_year)+'.dbf')
        working_file = Dbf5(work_flow)
        wf_df = working_file.to_dataframe()
        columns_to_keep=['id','s000']
        wf_df = wf_df.loc[:,columns_to_keep]
        updated_names = ['block','value']
        wf_df.columns = updated_names
        wf_df['block'] = wf_df['block'].astype(str)
        
        # create block group id from first 12 characters in the block id
        wf_df['work_blockgroup'] = wf_df['block'].str[0:12]
        columns_to_keep=['work_blockgroup','value']
        wf_df = wf_df.loc[:,columns_to_keep]
        workers = wf_df.groupby('work_blockgroup').sum()
        workers = workers.reset_index()
        
        # merge with the full statewide blockgroup df
        interim_df = pd.merge(bg_df, workers, on='work_blockgroup',suffixes=('_x','_y'),how='left')
        interim_df.fillna(0,inplace=True)
        interim_df['year'] = current_year
        interim_df['home_county'] = value

        if i == 0:
            final_df = interim_df
            
        else:
            final_df = final_df.append(interim_df)
       
        i = i + 1

print 'Cleaning up columns before importing to the central database'
final_df['year'] = final_df['year'].astype(str)
final_df['value'] = final_df['value'].astype(int)
final_df['record_id'] = final_df['home_county']+'_'+final_df['work_blockgroup']+'_'+final_df['year']
final_columns = ['record_id','home_county','work_county','work_blockgroup','work_city','year','value']
final_df = final_df.loc[:,final_columns]

print 'Getting a list of the tables in Elmer (the Central Database)'
table_names = []
for rows in cursor.tables():
    if rows.table_type == "TABLE":
        table_names.append(rows.table_name)
    
table_exists = working_tablename in table_names
    
if table_exists == True:
    print 'There is currently a table named ' + working_tablename + ' in Elmer, removing the older table'
    sql_statement = 'drop table ' + working_tablename
    cursor.execute(sql_statement)
    sql_conn.commit()
    
print 'Creating a new table named ' + working_tablename + ' in Elmer to hold the updated data'
sql_statement = 'create table '+working_tablename+'(record_id varchar(25), home_county varchar(3), work_county varchar(3), work_blockgroup varchar(12), work_city varchar(25), year varchar(4), value int)'
cursor.execute(sql_statement)
sql_conn.commit()

print 'Add data to ' + working_tablename + ' in Elmer'
for index,row in final_df.iterrows():
    sql_state = 'INSERT INTO ' + working_tablename + '([record_id],[home_county],[work_county],[work_blockgroup],[work_city],[year],[value]) values (?,?,?,?,?,?,?)'
    cursor.execute(sql_state, row['record_id'], row['home_county'], row['work_county'], row['work_blockgroup'], row['work_city'], row['year'], row['value'])
    sql_conn.commit()
    
print 'Closing the central database'
sql_conn.close()

end_of_production = time.time()
print 'The Total Time for all processes took', (end_of_production-start_of_production)/60, 'minutes to execute.'
#exit()
