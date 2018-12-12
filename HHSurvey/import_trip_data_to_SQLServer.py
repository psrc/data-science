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
final_data = trip
## drop the null value for now, but I will try to keep null value in the future 
#final_data = final_data.fillna(0)
final_data['tripid'] = final_data['tripid'].astype(int)

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
sql_statement1 = 'create table ' + tablename 
sql_statement2 = '( ' + \
                 'hhid INT NULL, ' + \
                 'personid INT NULL, ' + \
                 'pernum int NULL, ' + \
                 'tripid INT NULL, ' + \
                 'tripnum INT NULL, ' + \
                 'traveldate datetime2(7) NULL, ' + \
                 'daynum INT NULL, ' + \
                 'dayofweek int NULL, ' + \
                 'hhgroup INT NULL, ' + \
                 'copied_trip float NULL, ' + \
                 'completed_at varchar(255) NULL, ' + \
                 'revised_at varchar(255) NULL, ' + \
                 'revised_count float NULL, ' + \
                 'svy_complete INT NULL, ' + \
                 'depart_time_mam float NULL, ' + \
                 'depart_time_hhmm varchar(255) NULL, ' + \
                 'depart_time_timestamp varchar(255) NULL, ' + \
                 'arrival_time_mam float NULL, ' + \
                 'arrival_time_hhmm varchar(255) NULL, ' + \
                 'arrival_time_timestamp varchar(255) NULL, ' + \
                 'origin_name varchar(255) NULL, ' + \
                 'origin_address varchar(255) NULL, ' + \
                 'origin_lat float NULL, ' + \
                 'origin_lng float NULL, ' + \
                 'dest_name varchar(255) NULL, ' + \
                 'dest_address varchar(255) NULL, ' + \
                 'dest_lat float NULL, ' + \
                 'dest_lng float NULL, ' + \
                 'trip_path_distance float NULL, ' + \
                 'google_duration float NULL, '  + \
                 'reported_duration float NULL, ' + \
                 'hhmember1 float NULL, ' + \
                 'hhmember2 float NULL, ' + \
                 'hhmember3 float NULL, ' + \
                 'hhmember4 float NULL, ' + \
                 'hhmember5 float NULL, ' + \
                 'hhmember6 float NULL, ' + \
                 'hhmember7 float NULL, ' + \
                 'hhmember8 float NULL, ' + \
                 'hhmember9 float NULL, ' + \
                 'hhmember_none float NULL, ' + \
                 'travelers_hh INT NULL, ' + \
                 'travelers_nonhh INT NULL, ' + \
                 'travelers_total INT NULL, ' + \
                 'origin_purpose float NULL, ' + \
                 'o_purpose_other varchar(255) NULL, '+ \
                 'dest_purpose INT NULL, ' + \
                 'dest_purpose_comment varchar(255) NULL, ' + \
                 'mode_1 INT NULL, ' + \
                 'mode_2 float NULL, ' + \
                 'mode_3 float NULL, ' + \
                 'mode_4 float NULL, ' + \
                 'driver float NULL, ' + \
                 'pool_start INT NULL, ' + \
                 'change_vehicles float NULL, ' + \
                 'park_ride_area_start float NULL, ' + \
                 'park_ride_area_end float NULL, ' + \
                 'park_ride_lot_start float NULL, ' + \
                 'park_ride_lot_end float NULL, ' + \
                 'toll float NULL, ' + \
                 'taxi_type float NULL, ' + \
                 'taxi_pay float NULL, ' + \
                 'bus_type float NULL, ' + \
                 'bus_pay float NULL, ' + \
                 'bus_cost_dk float NULL, ' + \
                 'ferry_type float NULL, ' + \
                 'ferry_pay float NULL, ' + \
                 'ferry_cost_dk float NULL, ' + \
                 'rail_type float NULL, ' + \
                 'rail_pay float NULL, ' + \
                 'rail_cost_dk float NULL, ' + \
                 'air_type float NULL, ' + \
                 'air_pay float NULL, ' + \
                 'airfare_cost_dk float NULL, ' + \
                 'mode_acc float NULL, ' + \
                 'mode_egr float NULL, ' + \
                 'park float NULL, ' + \
                 'park_type float NULL, ' + \
                 'park_pay float NULL, ' + \
                 'transit_system_1 float NULL, ' + \
                 'transit_system_2 float NULL, ' + \
                 'transit_system_3 float NULL, ' + \
                 'transit_system_4 float NULL, ' + \
                 'transit_system_5 float NULL, ' + \
                 'transit_line_1 float NULL, ' + \
                 'transit_line_2 float NULL, ' + \
                 'transit_line_3 float NULL, ' + \
                 'transit_line_4 float NULL, ' + \
                 'transit_line_5 float NULL, ' + \
                 'speed_mph float NULL, ' + \
                 'user_merged float NULL, ' + \
                 'user_split float NULL, ' + \
                 'analyst_merged float NULL, ' + \
                 'analyst_split float NULL, ' + \
                 'flag_teleport float NULL, ' + \
                 'proxy_added_trip varchar(255) NULL, ' + \
                 'nonproxy_derived_trip float NULL, ' + \
                 'child_trip_location_tripid float NULL, ' + \
                 'tripid_new INT NULL)'

                                           
sql_statement = sql_statement1  + sql_statement2                                    
                                           
                                           
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