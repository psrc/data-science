# -*- coding: utf-8 -*-
"""
Created on Mon Jan 07 15:48:23 2019
@author: AYang
Task: This script is to upload one single county file to SQL. 
This step was carried out after union all jurisdictions to one county table, 
and attach geo information (census id and UGA, TAZ ID) to the table

NOTE: BEFORE RUN THIS FILE, YOU HAVE TO MAKE SURE PIN IS IN INT TYPE. sometimes, it is in wreid object type and with e+9 value. 
ISSUE / FINAL date is in the date formate (change it in excel)
"""

import pandas as pd
import pyodbc
import numpy as np
import os 


COUNTY = 'KITSAP'
COUNTY_CODE = '35'
DATA_PATH = r'J:\Projects\Permits\17Permit\database\working'
my_tablename = COUNTY + '_' + COUNTY_CODE + '_17'
file_name = COUNTY + '17_merged_geo.csv'

def read_data(DATA_PATH, COUNTY, file_name):
    my_file = pd.DataFrame.from_csv(os.path.join(DATA_PATH, COUNTY, file_name), sep=',', index_col=None)
    return my_file

def data_process(my_data):
    ## add some columns
    my_data['UGA'] = my_data['Join_Count']
    my_data['TRACTID'] = my_data['GEOID10']
    my_data['BLKGRPID'] = my_data['BLKGRPCE10']
    my_data['BLKID'] = my_data['BLOCKCE10']
    my_data['CHECK_DUPLICATED'] = my_data['CHECK_DUPL']
    my_data['COUNTY'] = COUNTY_CODE
    if 'TAZ10' not in my_data.columns:
        my_data['TAZ10'] = np.nan
    if 'FAZ10' not in my_data.columns:
        my_data['FAZ10'] = np.nan   
    if 'TAZ4K' not in my_data.columns:
        my_data['TAZ4K'] = np.nan
    if 'ID' not in my_data.columns:
        my_data['ID'] = np.nan
    # reorder the csv table columns, so it could line up with the SQL table columns. It is important in the data type specification, apple to apple. 
    my_data = my_data[[u'ID', u'PSRCIDN', u'PERMITNO', u'SORT', u'MULTIREC', u'PIN',
       u'ADDRESS', u'HOUSENO', u'PREFIX', u'STRNAME', u'STRTYPE', u'SUFFIX',
       u'UNIT_BLD', u'ZIP', u'ISSUED', u'FINALED', u'STATUS', u'TYPE', u'PS',
       u'UNITS', u'BLDGS', u'LANDUSE', u'CONDO', u'VALUE', u'ZONING', u'NOTES',
       u'NOTES2', u'NOTES3', u'NOTES4', u'NOTES5', u'NOTES6', u'NOTES7',
       u'LOTSIZE', u'JURIS', u'JURIS15', u'PLC', u'PLC15', u'PROJYEAR',
       u'CNTY', u'MULTCNTY', u'PSRCID', u'PSRCIDXY', u'X_COORD', u'Y_COORD',
       u'RUNTYPE', u'CHECK_DUPLICATED', u'PIN_PARENT', u'COUNTY', 
       'TRACTID', 'BLKGRPID', 'BLKID', 'UGA', 'TAZ10', 'TAZ4K', 'FAZ10']]
    return my_data


def process_null_data(my_data):
    my_data.replace('', np.nan, inplace=True)
    print (np.where(my_data.applymap(lambda x: x == '')))
    my_data = my_data.where((pd.notnull(my_data)), None)
    return my_data

def get_table_from_elmer():
    table_names = []
    for rows in cursor.tables():
        if rows.table_type == "TABLE":
            table_names.append(rows.table_name)
    return table_names

def check_duplicated_table(table_names, my_tablename):
    table_exists = my_tablename in table_names
    if table_exists == True:
        print 'There is currently a table named ' + my_tablename + ', removing the older table'
        sql_statement = 'drop table ' + my_tablename
        cursor.execute(sql_statement)
        sql_conn.commit()

## get column list from original csv table, to help construct the SQL data table
def get_col_list(my_data):
    str_c = ''
    for c in final_data.columns.tolist()[0:]:
        print c
        str_c = str_c + '[' + c + '],'   
    str_c = str_c[:-1] 
    print ('data table column names are')
    print (str_c)
    return str_c

    
## create data table structure in SQL and specific data types
def create_data_table_in_SQL(sql_statement):                                                                                                           
    cursor.execute(sql_statement)
    sql_conn.commit()
    
# insert data into table
def insert_data_into_SQL(my_data, str_c, my_tablename):
    for index,row in my_data.iterrows():
        print (index)
        #print (row)
        sql_state = 'INSERT INTO ' + my_tablename + '(' + str_c + ')' + 'values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)' 
        cursor.execute(sql_state, row['ID'],row['PSRCIDN'],row['PERMITNO'],row['SORT'],row['MULTIREC'],
                                  row['PIN'],row['ADDRESS'],row['HOUSENO'],row['PREFIX'],row['STRNAME'],
                                  row['STRTYPE'],row['SUFFIX'],row['UNIT_BLD'],row['ZIP'],row['ISSUED'],
                                  row['FINALED'],row['STATUS'],row['TYPE'],row['PS'],row['UNITS'],
                                  row['BLDGS'],row['LANDUSE'],row['CONDO'],row['VALUE'],row['ZONING'],
                                  row['NOTES'],row['NOTES2'],row['NOTES3'],row['NOTES4'],row['NOTES5'],
                                  row['NOTES6'],row['NOTES7'],row['LOTSIZE'],
                                  row['JURIS'],row['JURIS15'],row['PLC'],row['PLC15'],row['PROJYEAR'],
                                  row['CNTY'],row['MULTCNTY'],row['PSRCID'],row['PSRCIDXY'],row['X_COORD'],
                                  row['Y_COORD'],row['RUNTYPE'],row['CHECK_DUPLICATED'], row['PIN_PARENT'],row['COUNTY'],
                                  row['TRACTID'],row['BLKGRPID'],row['BLKID'],row['UGA'],row['TAZ10'],row['TAZ4K'],row['FAZ10']) 
        sql_conn.commit()




sql_conn = pyodbc.connect('DRIVER={SQL Server}; SERVER=sql2016\DSADEV;DATABASE=Sandbox;trusted_connection=true')
cursor = sql_conn.cursor()


    
## set up the SQL data table structure (the data types would change from table to table)
sql_statement1 = 'create table ' + my_tablename 
sql_statement2 = '( ' + \
                 'ID INT NULL, ' + \
                 'PSRCIDN varchar(255) NULL, ' + \
                 'PERMITNO varchar(255) NULL, ' + \
                 'SORT varchar(255) NULL, ' + \
                 'MULTIREC varchar(255) NULL, ' + \
                 'PIN varchar(255) NULL, ' + \
                 'ADDRESS varchar(255) NULL, ' + \
                 'HOUSENO varchar(255) NULL, ' + \
                 'PREFIX varchar(255) NULL, ' + \
                 'STRNAME varchar(255) NULL, ' + \
                 'STRTYPE varchar(255) NULL, ' + \
                 'SUFFIX varchar(255) NULL, ' + \
                 'UNIT_BLD varchar(255) NULL, ' + \
                 'ZIP varchar(255) NULL, ' + \
                 'ISSUED date NULL, ' + \
                 'FINALED date NULL, ' + \
                 'STATUS varchar(255) NULL, ' + \
                 'TYPE INT NULL, ' + \
                 'PS INT NULL, ' + \
                 'UNITS varchar(255) NULL, ' + \
                 'BLDGS varchar(255) NULL, ' + \
                 'LANDUSE varchar(255) NULL, ' + \
                 'CONDO varchar(255) NULL, ' + \
                 'VALUE varchar(255) NULL, ' + \
                 'ZONING varchar(255) NULL, ' + \
                 'NOTES nvarchar(500) NULL, ' + \
                 'NOTES2 varchar(255) NULL, ' + \
                 'NOTES3 varchar(255) NULL, ' + \
                 'NOTES4 varchar(255) NULL, ' + \
                 'NOTES5 varchar(255) NULL, ' + \
                 'NOTES6 varchar(255) NULL, ' + \
                 'NOTES7 varchar(255) NULL, ' + \
                 'LOTSIZE varchar(255) NULL, ' + \
                 'JURIS varchar(255) NULL, ' + \
                 'JURIS15 INT NULL, ' + \
                 'PLC INT NULL, ' + \
                 'PLC15 varchar(255) NULL, ' + \
                 'PROJYEAR INT NULL, ' + \
                 'CNTY INT NULL, ' + \
                 'MULTCNTY varchar(255) NULL, ' + \
                 'PSRCID varchar(255) NULL, ' + \
                 'PSRCIDXY varchar(255) NULL, ' + \
                 'X_COORD float NULL, ' + \
                 'Y_COORD float NULL, ' + \
                 'RUNTYPE INT NULL, '+\
                 'CHECK_DUPLICATED INT NULL, ' +\
                 'PIN_PARENT varchar(255) NULL, ' + \
                 'COUNTY INT NULL, ' + \
                 'TRACTID varchar(255) NULL, ' + \
                 'BLKGRPID varchar(255) NULL, '+\
                 'BLKID varchar(255) NULL, ' +\
                 'UGA INT NULL, ' + \
                 'TAZ10 varchar(255) NULL, ' + \
                 'TAZ4K varchar(255) NULL, ' + \
                 'FAZ10 varchar(255) NULL)'
    
    
final_data = read_data(DATA_PATH, COUNTY, file_name)
final_data = data_process(final_data)
final_data = process_null_data(final_data)
table_names = get_table_from_elmer()
print table_names
check_duplicated_table(table_names, my_tablename)  
str_c = get_col_list(final_data)

## 3. exactive the SQL process                 
sql_statement = sql_statement1  + sql_statement2  
create_data_table_in_SQL(sql_statement)
insert_data_into_SQL(final_data, str_c, my_tablename)
print (COUNTY)
print ('-----------------finished------------------')
    
print ('Closing the central database')
sql_conn.close()








