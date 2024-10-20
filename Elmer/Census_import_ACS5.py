# This script creates data summaries in the PSRC region
# Created by Puget Sound Regional Council Staff
# October 2018

# Load the libraries we need
import pandas as pd
import urllib
import pyodbc
  
# SQL Connection to our internal SQL database Elmer
sql_conn = pyodbc.connect('DRIVER={SQL Server}; SERVER=sql2016\DSADEV;DATABASE=Elmer;trusted_connection=true')
cursor = sql_conn.cursor() 


working_directory = r'../../'
my_key = 'f9776be472619b8476b0dfdd8f1472a7de7ca2d5'
base_year ='2016'


geography_ids = {'033': ('county','King','co'),
                 '035': ('county','Kitsap','co'),
                 '053': ('county','Pierce','co'),
                 '061': ('county','Snohomish','co')
                }



## Dictionaries for Census Data Tables with labels
census_vars = {'B25104_001E' : 'MONTHLY HOUSING COSTS',
          'B01001_001E' : 'Sex by Age - total estimate'}
## Build list of Census data tablse
tables_to_download = ["B01001", "B01003", "B02001", "B03002"]
vars_to_download = []
census_vars = pd.read_json("variables.json")
census_varnames = census_vars.index.tolist()
for v in census_varnames:
	if v.find("_") > 1:
		candidate_table_name = v.split("_")[0]
		if candidate_table_name in tables_to_download:
			vars_to_download.append(v)



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

    
cursor.execute("DELETE FROM Census.tblStageVarByTract")
sql_conn.commit()
for varname in vars_to_download:
    writer = pd.ExcelWriter(working_directory + varname+'.xlsx')
    
    print varname
    census_data = 'NAME,'+varname
    new_df = pd.DataFrame()

    for geography_id in geography_ids:

            current_df = pd.DataFrame()
            dataset = 'acs/acs5'

            label ='estimate'
            data_type = 'E'
            dataset = 'acs/acs5'
            returns_numeric= True
            url_call = create_census_url(dataset, census_data, geography_ids[geography_id][0], geography_id,base_year, my_key, data_type)
            current_df = pd.read_json(download_census_data(url_call))
            current_df.columns = ['a', 'est', 'state', 'county', 'tract']
            current_df['varname'] = pd.Series(varname, index=current_df.index)
            current_df = current_df[1:] #trim the column names in row 1
            print current_df.head(5)
            new_df = new_df.append(current_df.loc[:, ['varname', 'state', 'county', 'tract', 'est']])

    #new_df.to_excel(writer, index = False)
    #writer.save()
    
    # Popualte a table in the database with the tile of the current table
    for index,row in new_df.iterrows():
        print 'Working on Data in Row #' + str(row)
        cursor.execute("INSERT INTO Census.tblStageVarByTract(varname,[state],[county],[tract],[est]) values (?,?,?,?,?)", row['varname'], row['state'], row['county'], row['tract'], row['est']) 
        sql_conn.commit()
    
# Close the central database
sql_conn.close()
    