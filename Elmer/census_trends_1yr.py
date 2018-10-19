# This script pulls County and MSA Level Census Data from the Census API
# The data pulled and summarized are data trends produced annually
# Created by Puget Sound Regional Council Staff
# October 2018

import pandas as pd
import urllib
import os
import pyodbc

my_key = '6d9263105b3ca3213e093323b4ece211ab49d4e5'
data_years = ['2017']
acs_data_type = '1yr'

working_directory = os.getcwd()
output_directory = os.path.join(working_directory, 'outputs')

# SQL Connection to our internal SQL database Elmer
sql_conn = pyodbc.connect('DRIVER={SQL Server}; SERVER=sql2016\DSADEV;DATABASE=Elmer;trusted_connection=true')
cursor = sql_conn.cursor() 

# Create the output directory for the trip generation results
if not os.path.exists(output_directory):
    os.makedirs(output_directory)
    
acs_1yr_geographies = {'033': ('county','King','co'),
                       '035': ('county','Kitsap','co'),
                       '053': ('county','Pierce','co'),
                       '061': ('county','Snohomish','co'),                        
                       '53': ('state','Washington','st'),
                       '42660': ('metropolitan statistical area/micropolitan statistical area','Seattle-MSA','msa'),
                       '14740': ('metropolitan statistical area/micropolitan statistical area','Bremerton-MSA','msa'),
                       '35620': ('metropolitan statistical area/micropolitan statistical area','New-York-MSA','msa'),
                       '31080': ('metropolitan statistical area/micropolitan statistical area','Los-Angeles-MSA','msa'),
                       '16980': ('metropolitan statistical area/micropolitan statistical area','Chicago-MSA','msa'),
                       '19100': ('metropolitan statistical area/micropolitan statistical area','Dallas-MSA','msa'),
                       '26420': ('metropolitan statistical area/micropolitan statistical area','Houston-MSA','msa'),
                       '47900': ('metropolitan statistical area/micropolitan statistical area','Washington-DC-MSA','msa'),
                       '37980': ('metropolitan statistical area/micropolitan statistical area','Philadelphia-MSA','msa'),
                       '33100': ('metropolitan statistical area/micropolitan statistical area','Miami-MSA','msa'),
                       '12060': ('metropolitan statistical area/micropolitan statistical area','Atlanta-MSA','msa'),
                       '14460': ('metropolitan statistical area/micropolitan statistical area','Boston-MSA','msa'),
                       '41860': ('metropolitan statistical area/micropolitan statistical area','San-Francisco-MSA','msa'),
                       '38060': ('metropolitan statistical area/micropolitan statistical area','Phoenix-MSA','msa'),
                       '40140': ('metropolitan statistical area/micropolitan statistical area','Riverside-CA-MSA','msa'),
                       '19820': ('metropolitan statistical area/micropolitan statistical area','Detroit-MSA','msa'),
                       '33460': ('metropolitan statistical area/micropolitan statistical area','Minneapolis-MSA','msa'),
                       '41740': ('metropolitan statistical area/micropolitan statistical area','San-Diego-MSA','msa'),
                       '45300': ('metropolitan statistical area/micropolitan statistical area','Tampa-MSA','msa'),
                       '19740': ('metropolitan statistical area/micropolitan statistical area','Denver-MSA','msa'),
                       '41180': ('metropolitan statistical area/micropolitan statistical area','St-Louis-MSA','msa'),
                       '12580': ('metropolitan statistical area/micropolitan statistical area','Baltimore-MSA','msa'),
                       '16740': ('metropolitan statistical area/micropolitan statistical area','Charlotte-MSA','msa'),
                       '36740': ('metropolitan statistical area/micropolitan statistical area','Orlando-MSA','msa'),
                       '41700': ('metropolitan statistical area/micropolitan statistical area','San-Antonio-MSA','msa'),
                       '38900': ('metropolitan statistical area/micropolitan statistical area','Portland-MSA','msa'),
                       '38300': ('metropolitan statistical area/micropolitan statistical area','Pittsburgh-MSA','msa')
                       }

# Dictionaries for Census Data Tables with labels   
mode_share = {'B08301_001':('Total Work Trips','Heading1'),
               'B08301_002':('Total Vehicle','Heading2'),
               'B08301_003':('Drove Alone','Heading3'),
               'B08301_004':('Shared Ride','Heading3'),
               'B08301_005':('HOV 2','Heading4'),
               'B08301_006':('HOV 3','Heading4'),
               'B08301_007':('HOV 4','Heading4'),
               'B08301_008':('HOV 5 or 6','Heading4'),
               'B08301_009':('HOV 7 or more','Heading4'),
               'B08301_010':('Transit','Heading3'),
               'B08301_011':('Bus','Heading4'),
               'B08301_012':('Streetcar','Heading4'),
               'B08301_013':('Light Rail','Heading4'),                           
               'B08301_014':('Commuter Rail','Heading4'),                           
               'B08301_015':('Ferry','Heading4'),                           
               'B08301_016':('Taxi','Heading3'),                           
               'B08301_017':('Motorcycle','Heading3'),                           
               'B08301_018':('Bicycle','Heading3'),                           
               'B08301_019':('Walked','Heading3'),                           
               'B08301_020':('Other','Heading3'),                           
               'B08301_021':('Worked at Home','Heading3')
               }

commute_time = {'B08303_001':('Total Work Trips','Heading1'),
               'B08303_002':('Less than 5 minutes','Heading2'),
               'B08303_003':('5 to 9 minutes','Heading2'),
               'B08303_004':('10 to 14 minutes','Heading2'),
               'B08303_005':('15 to 19 minutes','Heading2'),
               'B08303_006':('20 to 24 minutes','Heading2'),
               'B08303_007':('25 to 29 minutes','Heading2'),
               'B08303_008':('30 to 34 minutes','Heading2'),
               'B08303_009':('35 to 39 minutes','Heading2'),
               'B08303_010':('40 to 44 minutes','Heading2'),
               'B08303_011':('45 to 59 minutes','Heading2'),
               'B08303_012':('60 to 89 minutes','Heading2'),
               'B08303_013':('90 or more minutes','Heading2')                           
               }

poverty_status = {'C17002_001':('Total Population','Heading1'),
               'C17002_002':('Less than 0.50','Heading2'),
               'C17002_003':('0.50 to 0.99','Heading2'),
               'C17002_004':('1.00 to 1.24','Heading2'),
               'C17002_005':('1.25 to 1.49','Heading2'),
               'C17002_006':('1.50 to 1.84','Heading2'),
               'C17002_007':('1.85 to 1.99','Heading2'),
               'C17002_008':('2.00 or higher','Heading2'),                          
               }

rent_cost = {'B25057_001':('Lower Quartile Rent','Heading1'),
             'B25058_001':('Median Rent','Heading1'),
             'B25059_001':('Upper Quartile Rent','Heading1')                        
               }

population_breakdown = {'B01001_001':('Total Population','Heading1'),
             'B01001_002':('Total Male Population','Heading2'),
             'B01001_026':('Total Female Population','Heading2')                      
               }

family_income = {'B19101_001':('Total Population with Family Income','Heading1'),
             'B19101_002':('Less than $10,000','Heading2'),
             'B19101_003':('$10,000 to $14,999','Heading2'),                      
             'B19101_004':('$15,000 to $19,999','Heading2'), 
             'B19101_005':('$20,000 to $24,999','Heading2'), 
             'B19101_006':('$25,000 to $29,999','Heading2'), 
             'B19101_007':('$30,000 to $34,999','Heading2'), 
             'B19101_008':('$35,000 to $39,999','Heading2'), 
             'B19101_009':('$40,000 to $44,999','Heading2'), 
             'B19101_010':('$45,000 to $49,999','Heading2'), 
             'B19101_011':('$50,000 to $59,999','Heading2'), 
             'B19101_012':('$60,000 to $74,999','Heading2'), 
             'B19101_013':('$75,000 to $99,999','Heading2'),             
             'B19101_014':('$100,000 to $124,999','Heading2'),              
             'B19101_015':('$125,000 to $149,999','Heading2'),              
             'B19101_016':('$150,000 to $199,000','Heading2'),              
             'B19101_017':('More than $200,000','Heading2')             
               }

#census_tables = [[acs_data_type, 'B08303', commute_time,'Commute_Time'],
#                 [acs_data_type, 'B08301', mode_share,'Commute_Mode'],
#                 [acs_data_type, 'C17002', poverty_status,'Poverty'],
#                 [acs_data_type, 'B25061', rent_cost,'Rent'],
#                 [acs_data_type, 'B01001', population_breakdown,'Population'],
#                 [acs_data_type, 'B19101', family_income,'Family_Income']                 
#                ]

census_tables = [[acs_data_type, 'B08303', commute_time,'Commute_Time']]

column_names = ['Estimate','Margin_of_Error','DataTable','Subject','Level','Geography','Year']
numeric_columns = ['Estimate','Margin_of_Error']
    
psrc_geographies = ','.join(acs_1yr_geographies.keys())
geography_ids = psrc_geographies.split(",")

# Functions to Download and Format Census API datatables
def create_census_url(data_set, data_tables, geography, type_of_geography, year, api_key):

    if type_of_geography == 'state':
        census_api_call = 'https://api.census.gov/data/' + str(year) + '/'+ data_set + '?get=' + data_tables + '&' + 'for='+ type_of_geography +':'+ geography + '&key=' + api_key    

    elif type_of_geography == 'metropolitan statistical area/micropolitan statistical area':
        census_api_call = 'https://api.census.gov/data/' + str(year) + '/'+ data_set + '?get=' + data_tables + '&' + 'for='+ type_of_geography +':'+ geography + '&key=' + api_key    
    
    else:
        census_api_call = 'https://api.census.gov/data/' + str(year) + '/'+ data_set + '?get=' + data_tables + '&' + 'for='+ type_of_geography +':'+ geography +'&in=state:53' + '&key=' + api_key
    
    return census_api_call

def download_census_data(data_url):

    response = urllib.urlopen(data_url)
    census_data = response.read()
    
    return census_data

def format_census_tables(census_download, working_table, updated_names, geography_type, working_geography, year):
    working_df = pd.read_json(census_download)
    working_df = working_df.rename(columns=working_df.iloc[0]).drop(working_df.index[0])
        
    if geography_type == 'metropolitan statistical area/micropolitan statistical area':
        working_df =  working_df.drop(['metropolitan statistical area/micropolitan statistical area'],axis=1)

    elif geography_type == 'state':
        working_df =  working_df.drop(['state'],axis=1)
    
    elif geography_type == 'county':
        working_df = working_df.drop(['state','county'],axis=1)
    
    working_df['DataTable'] = working_df.columns[0]
    working_df['DataTable'] = working_df['DataTable'].map(lambda x: str(x)[:-1])  
    my_table = working_df.iloc[0]['DataTable'] 
    working_df['Subject'] = working_table[my_table][0]
    working_df['Level'] = working_table[my_table][1]
    working_df['Geography'] = working_geography
    working_df['Year'] = year
    working_df.columns = updated_names
                
    return working_df

# Download and process the Census tables / data profiles
for tables in census_tables:

    # create a blank dataframe sized based on the number of columns in the census output we want
    new_df = pd.DataFrame(columns=column_names)
    
    # Create tables in the central database to hold the results of the census output
    sql_statement = 'drop table ' + tables[3]
    cursor.execute(sql_statement)
    sql_conn.commit()

    sql_statement = 'create table '+tables[3]+'(Record_ID varchar(50), DataTable varchar(50), Subject varchar(50), Estimate int, Margin_of_Error int, Geography varchar(50), Year int)'
    cursor.execute(sql_statement)
    sql_conn.commit()
      
    for years in data_years:
        
        if acs_data_type == '1yr' :
            
            if int(years) >= 2015: 
                acs_description = 'acs/acs1'
                
            else:
                acs_description = 'acs1'
    
        for analysis_geography in geography_ids:
        
            print 'Working on ', years , acs_1yr_geographies[analysis_geography][1] , tables[3]
        
            ##################################################################################################
            ##################################################################################################
            ### Download the Census Data Tables and store in a dataframe
            ##################################################################################################
            ##################################################################################################  
       
            # Create the list of census variables to pass to the census API and collect the data
            for key, value in tables[2].iteritems():
                census_data= key +'E',key +'M'
       
                # Create the query and do the census api call to collect the data in json format
                census_data = ','.join(census_data)
                url_call = create_census_url(acs_description, census_data, analysis_geography, acs_1yr_geographies[analysis_geography][0], years, my_key)
                downloaded_data = download_census_data(url_call)
                current_df = format_census_tables(downloaded_data, tables[2],column_names,acs_1yr_geographies[analysis_geography][0],acs_1yr_geographies[analysis_geography][1],years)
            
                new_df = new_df.append(current_df)
       
            new_df = new_df.fillna(0)
            
            for my_columns in numeric_columns:
                new_df[my_columns] = new_df[my_columns].apply(float)

    # Final cleanup of the dataframe before it is exported
    new_df = new_df.sort_values(by=['Year','Geography','DataTable'])
    new_df = new_df.reset_index()
    new_df['Year'] = new_df['Year'].apply(str)
    new_df['Record_ID'] = new_df['DataTable'] + new_df['Geography'] + new_df['Year']
    final_columns = ['Record_ID','DataTable','Subject','Estimate','Margin_of_Error','Geography','Year']
    new_df = new_df[final_columns]
    
    # Popualte a table in the database with the tile of the current table
    for index,row in new_df.iterrows():
        print 'Working on Data in Row #' + str(row)
        cursor.execute("INSERT INTO commute_time([Record_ID],[Subject],[Estimate],[Geography],[Year]) values (?,?,?,?,?)", row['Record_ID'], row['Subject'], row['Estimate'], row['Geography'], row['Year']) 
        sql_conn.commit()
    
# Close the central database
sql_conn.close()
        
print 'Census data has been pulled and placed in SQL Database'
exit()