# This script summarizes the LEHD On-the_Map Worker Flow
# Results are saved as tables in the Sandbox(test) database
# Data contains the home county of a worker and what Census Block they work in
# Created by Puget Sound Regional Council Staff
# January 2019

import pandas as pd
import os
from simpledbf import Dbf5
import geopandas as gp

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
block_shapefile = os.path.join(input_directory, 'blocks','wa_blocks_wgs1984.shp')
city_shapefile = os.path.join(input_directory, 'cities','cities_wgs1984.shp')
taz_shapefile = os.path.join(input_directory, 'taz3700','taz_3700_wgs1984.shp')

block_dbf = os.path.join(input_directory, 'blocks','wa_blocks_wgs1984.dbf')

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

def create_worker_flow_df():

    print 'Spatial Joing Blocks and Cities'
    keep_columns = ['GEOID10','CityName']
    bl_layer = create_point_from_polygon(block_shapefile, wgs_coordsys)
    merged_city = gp_spatial_join(bl_layer, city_shapefile, wgs_coordsys, keep_columns)

    print 'Spatial Joing Blocks with TAZ file for easier mapping'
    keep_columns = ['GEOID10', 'TAZ']
    merged_taz = gp_spatial_join(bl_layer, taz_shapefile, wgs_coordsys, keep_columns)
 
    print 'Get Block layer ready for job merging'
    # Create A Cenus Block Dataframe to join the estimate data with
    blocks = Dbf5(block_dbf)
    bl_df = blocks.to_dataframe()
    columns_to_keep=['GEOID10','COUNTYFP10']
    bl_df = bl_df.loc[:,columns_to_keep]
    
    # Add City Names to Blocks
    bl_df = pd.merge(bl_df, merged_city, on='GEOID10',suffixes=('_x','_y'),how='left')
    bl_df.fillna('Unincorporated',inplace=True)

    # Add TAZ Number to Blocks
    bl_df = pd.merge(bl_df, merged_taz, on='GEOID10',suffixes=('_x','_y'),how='left')
    bl_df.fillna(0,inplace=True)

    # Final cleanup of column names in master blocks file'
    updated_names = ['work_block','work_county', 'work_city', 'work_taz']
    bl_df.columns = updated_names

    i = 0

    for key, value in counties.iteritems():

        for current_year in analysis_years:
            
            print 'opening the ' + str(current_year) + ' worker-flow point file for ' + key + ' county' 
        
            interim_df = []
        
            work_flow =  os.path.join(input_directory, key, 'points_'+str(current_year)+'.dbf')
            working_file = Dbf5(work_flow)
            wf_df = working_file.to_dataframe()
            columns_to_keep=['id','s000']
            wf_df = wf_df.loc[:,columns_to_keep]
            updated_names = ['work_block','value']
            wf_df.columns = updated_names
            wf_df['work_block'] = wf_df['work_block'].astype(str)
                
            # merge with the full statewide blockgroup df
            interim_df = pd.merge(bl_df, wf_df, on='work_block',suffixes=('_x','_y'),how='left')
            interim_df = interim_df.dropna(subset=['value'])
            interim_df['year'] = current_year
            interim_df['home_county'] = value

            # Append the current year data frame to the yearly dataframe 
            if i == 0:
                final_df = interim_df
            
            else:
                final_df = final_df.append(interim_df)
       
            i = i + 1

    print 'Final dataframe cleanup for final packaging in central database'
	# Final Cleaning up columns before importing to the central database
    final_df['year'] = final_df['year'].astype(str)
    final_df['value'] = final_df['value'].astype(int)
    final_df['work_taz'] = final_df['work_taz'].astype(int)
    final_df['record_id'] = final_df['home_county']+'_'+final_df['work_block']+'_'+final_df['year']
    final_columns = ['record_id','home_county','work_county','work_block','work_city','work_taz','year','value']
    final_df = final_df.loc[:,final_columns]
    final_df = final_df.reset_index()
    final_df = final_df.drop('index',axis=1)
    
    return final_df
