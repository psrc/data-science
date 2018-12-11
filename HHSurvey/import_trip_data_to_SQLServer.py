# -*- coding: utf-8 -*-
"""
Created on Tue Dec 11 14:53:48 2018
This script is created to load household survey trip data into SQL database 
@author: AYang
"""
import pandas as pd
import pyodbc


# 1. SQL Connection to our internal SQL database Elmer
sql_conn = pyodbc.connect('DRIVER={SQL Server}; SERVER=sql2016\DSADEV;DATABASE=Sandbox;trusted_connection=true')
cursor = sql_conn.cursor()

## 2. get the data
trip = pd.read_csv(r'T:\2018December\Angela\trips.csv')
final_data = trip[['hhid', 'personid', 'pernum', 'tripid', 'tripnum','dayofweek', 'mode_1',  'origin_lat', 'origin_lng', 'dest_lat', 'dest_lng', 'google_duration', 'dest_purpose']]

print ('Getting a lsit of the tables in Elmer (the Central Database)')
tablename = 'HHSurvey_trips'

## 3. get the existing table list from the SQL database
table_names = []
for rows in cursor.tables():
    if rows.table_type == "TABLE":
        table_names.append(rows.table_name)
        
print (table_names)

## 4. if the table name already duplicated in the SQL database (Sandbox here), then delete the previous table!  Please be very careful of this step!!!! 
table_exists = tablename in table_names

if table_exists == True:
    print 'There is currently a table named ' + tablename + ', removing the older table'
    sql_statement = 'drop table ' + tablename
    cursor.execute(sql_statement)
    sql_conn.commit()

## 5. Creating a new table named HHSurvey_trips in Sandbox to hold the maintain the HH survey trips
sql_statement = 'create table '+tablename+'(hhid varchar(50), personid varchar(50), pernum int, tripid varchar(50), tripnum varchar(50), dayofweek varchar(50), mode_1 varchar(50), origin_lat varchar(50), origin_lng varchar(50), dest_lat varchar(50), dest_lng varchar(50),  google_duration varchar(50), dest_purpose int)'
cursor.execute(sql_statement)
sql_conn.commit()


## 6. Insert the data into datatable 
print 'Add data to ' + tablename + ' in Sandbox'
for index,row in final_data.iterrows():
    #print (index)
    #print (row)
    sql_state = 'INSERT INTO ' + tablename + '([hhid], [personid], [pernum], [tripid], [tripnum], [dayofweek], [mode_1], [origin_lat], [origin_lng], [dest_lat], [dest_lng], [google_duration], [dest_purpose]) values (?,?,?,?,?,?,?,?,?,?,?,?,?)'
    cursor.execute(sql_state, row['hhid'], row['personid'], row['pernum'], row['tripid'], row['tripnum'], row['dayofweek'], row['mode_1'], row['origin_lat'], row['origin_lng'], row['dest_lat'], row['dest_lng'], row['google_duration'], row['dest_purpose']) 
    sql_conn.commit()
    
    
## 7. finished load data
print 'Closing the central database'
sql_conn.close()