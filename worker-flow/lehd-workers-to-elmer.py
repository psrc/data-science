# This script summarizes the LEHD On-the_Map Worker Flow
# Results are saved as a pandas dataframe for export to the Central Database
# Created by Puget Sound Regional Council Staff
# January 2019

import pandas as pd
import os
from simpledbf import Dbf5

counties = {'chelan':'53007',
            'island':'53029',
            'jefferson':'53031',
            'king':'53033',
            'kitsap':'53035',
            'kittitas':'53037',
            'lewis':'53041',
            'mason':'53045',
            'pierce':'53053',
            'skagit':'53055',
            'snohomish':'53061',
            'thurston': '53067',
            'yakima':'53077'}

working_directory = os.getcwd()
input_directory = os.path.join(working_directory, 'input')

# Statewide Block File for merging
block_dbf = os.path.join(input_directory,'wa_blocks_wgs1984.dbf')

def create_worker_flow_df(start_year,end_year):
    
    print 'Creating the list of years to analyze'
    start_year = int(start_year)
    end_year = int(end_year)    
    analysis_years = []
    
    for x in range(start_year,end_year+1):
        analysis_years.append(x)
 
    print 'Get block layer ready for merging of worker flow data'
    # Create A Cenus Block Dataframe to join the estimate data with
    blocks = Dbf5(block_dbf)
    bl_df = blocks.to_dataframe()
    columns_to_keep=['GEOID10']
    bl_df = bl_df.loc[:,columns_to_keep]
    bl_df  = bl_df.rename(columns={'GEOID10':'work_block'}) 
    bl_df['work_block'] = bl_df['work_block'].astype(str)
    
    i = 0

    for key, value in counties.iteritems():

        for current_year in analysis_years:
            
            print 'Adding the ' + str(current_year) + ' worker-flow point file for ' + key + ' county' 
        
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
            interim_df['home_fips'] = value

            # Append the current year data frame to the yearly dataframe 
            if i == 0:
                final_df = interim_df
            
            else:
                final_df = final_df.append(interim_df)
       
            i = i + 1

    print 'Final dataframe cleanup for final packaging in central database'
	# Final Cleaning up columns before importing to the central database
    final_df['year'] = final_df['year'].astype(int)
    final_df['value'] = final_df['value'].astype(int)
    final_df = final_df.reset_index()
    final_df = final_df.drop('index',axis=1)
    final_df = final_df.reset_index()
    final_df  = final_df.rename(columns={'index':'record_id'}) 
    final_df['record_id'] = final_df['record_id'].astype(int)
    final_columns = ['record_id','home_fips','work_block','year','value']
    final_df = final_df.loc[:,final_columns]
    
    return final_df
