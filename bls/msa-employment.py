# This script summarizes the QCEW MSA Quarterly Employment
# Results are saved as tables in the Sandbox(test) database
# Created by Puget Sound Regional Council Staff
# Novemeber 2018

import pandas as pd
import time
import os
import urllib
import pyodbc

analysis_years = [2014,2015,2016,2017,2018]
analysis_quarter = [1,2,3,4]
industry_sector = 10

working_directory = os.getcwd()
input_directory = os.path.join(working_directory, 'inputs')
output_directory = os.path.join(working_directory, 'outputs')

# Create the output directory for the trip generation results
if not os.path.exists(output_directory):
    os.makedirs(output_directory)

# SQL Connection to our internal SQL database Elmer
sql_conn = pyodbc.connect('DRIVER={SQL Server}; SERVER=sql2016\DSADEV;DATABASE=Sandbox;trusted_connection=true')
cursor = sql_conn.cursor()

start_of_production = time.time()

print 'Downloading and loading the FIPS code dictionary into a dataframe'
data_url = 'https://data.bls.gov/cew/doc/titles/area/area_titles.csv'
response = urllib.urlopen(data_url)
area_titles = response.read()  
datalines = area_titles.decode().split('\r\n')
fips_codes = pd.DataFrame(datalines)
fips_codes = fips_codes[0].str.split(',', expand=True)
fips_codes.fillna("",inplace=True)
fips_codes = fips_codes.replace('"', '', regex=True)
fips_codes = fips_codes.rename(columns=fips_codes.iloc[0]).drop(fips_codes.index[0])
fips_codes.columns = fips_codes.columns.str.lower()
fips_codes['area_fips'] = fips_codes['area_fips'].apply(str)
updated_columns = ['area_fips','title','area']
fips_codes.columns = updated_columns
fips_codes['area_name'] = fips_codes['title'] + ' ' + fips_codes['area']
keep_columns = ['area_fips','area_name']
fips_codes =fips_codes.loc[:,keep_columns]

current_count = 0
for current_year in analysis_years:
    
    for current_quarter in analysis_quarter:
    
        print 'Downloading the QCEW Data for ' + str(current_year) + ' Quarter # ' + str(current_quarter)
        data_url = 'http://www.bls.gov/cew/data/api/' + str(current_year) + '/' + str(current_quarter) + '/industry/' +str(industry_sector) + '.csv'
        response = urllib.urlopen(data_url)
        qcew_data = response.read()        

        error_string = '404 Not Found'
        
        if qcew_data.find(error_string) == -1:
            
            print 'Loading the downloaded data into a dataframe'
            datalines = qcew_data.decode().split('\r\n')
            working_data = pd.DataFrame(datalines)
            working_data = working_data[0].str.split(',', expand=True)
            working_data = working_data.replace('"', '', regex=True)
            working_data = working_data.rename(columns=working_data.iloc[0]).drop(working_data.index[0])
            working_data.columns = working_data.columns.str.lower()
    
            print 'Trimming data to only include total covered employment (ownership code 0)'
            working_data = working_data[working_data.own_code == '0']
        
            print 'Cleaning up columns and merging annual data by the area fips'
            keep_columns = ['area_fips','month1_emplvl','month2_emplvl','month3_emplvl','avg_wkly_wage']
            working_data = working_data.loc[:,keep_columns]
            
            if current_quarter == 1:
                final_columns = ['area_fips','jobs_01','jobs_02','jobs_03','weekly_wage']
            
            elif current_quarter == 2:
                final_columns = ['area_fips','jobs_04','jobs_05','jobs_06','weekly_wage']

            elif current_quarter == 3:
                final_columns = ['area_fips','jobs_07','jobs_08','jobs_09','weekly_wage']

            else:
                final_columns = ['area_fips','jobs_10','jobs_11','jobs_12','weekly_wage']
            
            working_data.columns = final_columns

            print 'Converting dataframe from Columns to rows'
            adjusted_df = pd.melt(working_data, id_vars=['area_fips'], var_name="category", value_name="value")
            adjusted_df['year'] = current_year
            adjusted_df['quarter'] = 'q' + str(current_quarter)
              
            if current_count == 0:
                final_data = adjusted_df
        
            else:
                final_data = final_data.append(adjusted_df)

            current_count = current_count + 1

        else:
            print 'The file does not exist on the QCEW network, moving to the next quarter'

print 'Adding the FIPS name to the dataframe'
final_data['area_fips'] = final_data['area_fips'].apply(str)
final_data['year'] = final_data['year'].apply(str)
final_data['quarter'] = final_data['quarter'].apply(str)
final_data = pd.merge(final_data, fips_codes, on='area_fips',suffixes=('_x','_y'),how='left')

print 'Adding a Date Column to the dataframe for use in chart making'
final_data[['attribute', 'month']] = final_data['category'].str.split('_', expand=True)
final_data.loc[(final_data['month'] == 'wage' ) & (final_data['quarter'] == 'q1' ), 'month'] = '03'  
final_data.loc[(final_data['month'] == 'wage' ) & (final_data['quarter'] == 'q2' ), 'month'] = '06'  
final_data.loc[(final_data['month'] == 'wage' ) & (final_data['quarter'] == 'q3' ), 'month'] = '09'  
final_data.loc[(final_data['month'] == 'wage' ) & (final_data['quarter'] == 'q4' ), 'month'] = '12'
final_data.loc[(final_data['attribute'] == 'weekly' ), 'attribute'] = 'wages'  
final_data['date'] = final_data['month'] + '/01/' + final_data['year']

print 'Cleaning up columns before importing to the central database'
final_data['record_id'] = final_data['area_fips']+'_'+final_data['attribute']+'_'+final_data['quarter']+'_'+final_data['year']
final_columns = ['record_id','attribute','value','area_fips','quarter','year','area_name','date']
final_data = final_data.loc[:,final_columns]

print 'Getting a list of the tables in Elmer (the Central Database)'
qcew_tablename = 'qcew_quarterly_msa_employment'

table_names = []
for rows in cursor.tables():
    if rows.table_type == "TABLE":
        table_names.append(rows.table_name)
    
table_exists = qcew_tablename in table_names
    
if table_exists == True:
    print 'There is currently a table named ' + qcew_tablename + ' in Elmer, removing the older table'
    sql_statement = 'drop table ' + qcew_tablename
    cursor.execute(sql_statement)
    sql_conn.commit()
    
print 'Creating a new table named ' + qcew_tablename + ' in Elmer to hold the updated MSA employment data'
sql_statement = 'create table '+qcew_tablename+'(record_id varchar(25), attribute varchar(10), value int, area_fips varchar(10), quarter varchar(2), year varchar(4), area_name varchar(75), date varchar(10))'
cursor.execute(sql_statement)
sql_conn.commit()

print 'Add data to ' + qcew_tablename + ' in Elmer'
for index,row in final_data.iterrows():
    sql_state = 'INSERT INTO ' + qcew_tablename + '([record_id],[attribute],[value],[area_fips],[quarter],[year],[area_name],[date]) values (?,?,?,?,?,?,?,?)'
    cursor.execute(sql_state, row['record_id'], row['attribute'], row['value'], row['area_fips'], row['quarter'], row['year'], row['area_name'], row['date']) 
    sql_conn.commit()
    
print 'Closing the central database'
sql_conn.close()

print 'Exporting the final data to csv'
final_data.fillna(0,inplace=True)
final_data.to_csv(os.path.join(output_directory,'qcew_jobs_wages_by_msa.csv'),index=False)

end_of_production = time.time()
print 'The Total Time for all processes took', (end_of_production-start_of_production)/60, 'minutes to execute.'
exit()
