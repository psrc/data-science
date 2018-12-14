# -*- coding: utf-8 -*-
"""
Created on Tue Dec 11 14:53:48 2018
This script is created to load household survey trip data into SQL database 
@author: AYang
"""
import pandas as pd
import pyodbc
import numpy as np


# 1. SQL Connection to our internal SQL database Elmer
sql_conn = pyodbc.connect('DRIVER={SQL Server}; SERVER=sql2016\DSADEV;DATABASE=Sandbox;trusted_connection=true')
cursor = sql_conn.cursor()


## 2. get the data and prepare the data for SQL read
trip = pd.read_csv(r'T:\2018December\Angela\trips.csv')
final_data = trip
for int_column in ['hhid', 'tripid', 'personid', 'pernum', 'tripnum', 'daynum', 'dayofweek', 'hhgroup', 'svy_complete', 'tripid_new', 'travelers_hh', 'travelers_nonhh', 'travelers_total', 'dest_purpose', 'mode_1']:
    final_data[int_column] = final_data[int_column].astype(int)
 
## convert empty string as numpy nan value
final_data.replace('', np.nan, inplace=True)
print (np.where(final_data.applymap(lambda x: x == '')))

'''
########## VERY IMPORTANT LESSON #########
replace panda or numpy value none to NULL, or the SQL server won't recogonize the NULL value.  
referrence: https://stackoverflow.com/questions/14162723/replacing-pandas-or-numpy-nan-with-a-none-to-use-with-mysqldb
'''
final_data = final_data.where((pd.notnull(final_data)), None)

'''
to get rid of some wried value in string value: 
25267    Volunteering�??
25303    Volunteering�??
25336    Volunteering�??
'''

final_data.loc[25267,'dest_purpose_comment'] = 'Volunteering'
final_data.loc[25303,'dest_purpose_comment'] = 'Volunteering'
final_data.loc[25336,'dest_purpose_comment'] = 'Volunteering'

final_data.loc[25268,'o_purpose_other'] = 'Volunteering'
final_data.loc[25304,'o_purpose_other'] = 'Volunteering'
final_data.loc[25337,'o_purpose_other'] = 'Volunteering'

## 3. get the existing table list from the SQL database
print ('Getting a lsit of the tables in Elmer (the Central Database)')
my_tablename = 'HHSurvey_trips'
table_names = []
for rows in cursor.tables():
    if rows.table_type == "TABLE":
        table_names.append(rows.table_name)
        
print (table_names)


## 4. if the table name already duplicated in the SQL database (Sandbox here), then delete the previous table!  Please be very careful of this step!!!! 
table_exists = my_tablename in table_names
if table_exists == True:
    print 'There is currently a table named ' + my_tablename + ', removing the older table'
    sql_statement = 'drop table ' + my_tablename
    cursor.execute(sql_statement)
    sql_conn.commit()


## 5. Creating a new table named HHSurvey_trips in Sandbox to hold the maintain the HH survey trips
sql_statement1 = 'create table ' + my_tablename 
sql_statement2 = '( ' + \
                 'recid varchar(255) NULL, ' + \
                 'hhid INT NULL, ' + \
                 'personid INT NULL, ' + \
                 'pernum INT NULL, ' + \
                 'tripid INT NULL, ' + \
                 'tripnum INT NULL, ' + \
                 'traveldate datetime NULL, ' + \
                 'daynum INT NULL, ' + \
                 'dayofweek INT NULL, ' + \
                 'hhgroup INT NULL, ' + \
                 'copied_trip varchar(255) NULL, ' + \
                 'completed_at varchar(255) NULL, ' + \
                 'revised_at varchar(255) NULL, ' + \
                 'revised_count decimal(38, 10) NULL, ' + \
                 'svy_complete INT NULL, ' + \
                 'depart_time_mam decimal(38, 10) NULL, ' + \
                 'depart_time_hhmm datetime NULL, ' + \
                 'depart_time_timestamp varchar(255) NULL, ' + \
                 'arrival_time_mam decimal(38, 10) NULL, ' + \
                 'arrival_time_hhmm datetime NULL, ' + \
                 'arrival_time_timestamp varchar(255) NULL, ' + \
                 'origin_name varchar(255) NULL, ' + \
                 'origin_address varchar(255) NULL, ' + \
                 'origin_lat decimal(38, 10) NULL, ' + \
                 'origin_lng decimal(38, 10) NULL, ' + \
                 'dest_name varchar(255) NULL, ' + \
                 'dest_address varchar(255) NULL, ' + \
                 'dest_lat decimal(38, 10) NULL, ' + \
                 'dest_lng decimal(38, 10) NULL, ' + \
                 'trip_path_distance varchar(255) NULL, ' + \
                 'google_duration decimal(38, 1) NULL, '  + \
                 'reported_duration decimal(38, 1) NULL, ' + \
                 'hhmember1 varchar(255) NULL, ' + \
                 'hhmember2 varchar(255) NULL, ' + \
                 'hhmember3 varchar(255) NULL, ' + \
                 'hhmember4 varchar(255) NULL, ' + \
                 'hhmember5 varchar(255) NULL, ' + \
                 'hhmember6 varchar(255) NULL, ' + \
                 'hhmember7 varchar(255) NULL, ' + \
                 'hhmember8 varchar(255) NULL, ' + \
                 'hhmember9 varchar(255) NULL, ' + \
                 'hhmember_none decimal(38, 1) NULL, ' + \
                 'travelers_hh INT NULL, ' + \
                 'travelers_nonhh INT NULL, ' + \
                 'travelers_total INT NULL, ' + \
                 'origin_purpose decimal(38, 1) NULL, ' + \
                 'o_purpose_other varchar(255) NULL, '+ \
                 'dest_purpose INT NULL, ' + \
                 'dest_purpose_comment varchar(255) NULL, ' + \
                 'mode_1 INT NULL, ' + \
                 'mode_2 decimal(38, 1) NULL, ' + \
                 'mode_3 decimal(38, 1) NULL, ' + \
                 'mode_4 decimal(38, 1) NULL, ' + \
                 'driver decimal(38, 1) NULL, ' + \
                 'pool_start varchar(255) NULL, ' + \
                 'change_vehicles decimal(38, 1) NULL, ' + \
                 'park_ride_area_start decimal(38, 1) NULL, ' + \
                 'park_ride_area_end decimal(38, 1) NULL, ' + \
                 'park_ride_lot_start decimal(38, 1) NULL, ' + \
                 'park_ride_lot_end decimal(38, 1) NULL, ' + \
                 'toll decimal(38, 1) NULL, ' + \
                 'toll_pay decimal(38, 1) NULL, ' + \
                 'taxi_type decimal(38, 1) NULL, ' + \
                 'taxi_pay decimal(38, 1) NULL, ' + \
                 'bus_type decimal(38, 1) NULL, ' + \
                 'bus_pay decimal(38, 1) NULL, ' + \
                 'bus_cost_dk decimal(38, 1) NULL, ' + \
                 'ferry_type decimal(38, 1) NULL, ' + \
                 'ferry_pay decimal(38, 1) NULL, ' + \
                 'ferry_cost_dk decimal(38, 1) NULL, ' + \
                 'rail_type decimal(38, 1) NULL, ' + \
                 'rail_pay decimal(38, 1) NULL, ' + \
                 'rail_cost_dk decimal(38, 1) NULL, ' + \
                 'air_type decimal(38, 1) NULL, ' + \
                 'air_pay decimal(38, 1) NULL, ' + \
                 'airfare_cost_dk decimal(38, 1) NULL, ' + \
                 'mode_acc decimal(38, 1) NULL, ' + \
                 'mode_egr decimal(38, 1) NULL, ' + \
                 'park decimal(38, 1) NULL, ' + \
                 'park_type decimal(38, 1) NULL, ' + \
                 'park_pay decimal(38, 1) NULL, ' + \
                 'transit_system_1 decimal(38, 1) NULL, ' + \
                 'transit_system_2 decimal(38, 1) NULL, ' + \
                 'transit_system_3 decimal(38, 1) NULL, ' + \
                 'transit_system_4 decimal(38, 1) NULL, ' + \
                 'transit_system_5 decimal(38, 1) NULL, ' + \
                 'transit_line_1 decimal(38, 1) NULL, ' + \
                 'transit_line_2 decimal(38, 1) NULL, ' + \
                 'transit_line_3 decimal(38, 1) NULL, ' + \
                 'transit_line_4 decimal(38, 1) NULL, ' + \
                 'transit_line_5 decimal(38, 1) NULL, ' + \
                 'speed_mph decimal(38, 1) NULL, ' + \
                 'user_merged decimal(38, 1) NULL, ' + \
                 'user_split decimal(38, 1) NULL, ' + \
                 'analyst_merged decimal(38, 1) NULL, ' + \
                 'analyst_split decimal(38, 1) NULL, ' + \
                 'flag_teleport decimal(38, 1) NULL, ' + \
                 'proxy_added_trip varchar(255) NULL, ' + \
                 'nonproxy_derived_trip decimal(38, 1) NULL, ' + \
                 'child_trip_location_tripid decimal(38, 1) NULL, ' + \
                 'tripid_new INT NULL)' #used to be INT, but the length is more than default maxmium precision

                                           
sql_statement = sql_statement1  + sql_statement2                                                                                                                   
cursor.execute(sql_statement)
sql_conn.commit()


## 6. Insert the data into datatable 
print 'Add data to ' + my_tablename + ' in Sandbox'

'''
#str_c1 = '[recid], [hhid], [personid], [pernum], [tripid], [tripnum], [traveldate], [daynum], [dayofweek], [hhgroup], [copied_trip]'
str_c1 = '[completed_at], [revised_at], [revised_count], [svy_complete], [depart_time_mam]'

for index,row in final_data.iterrows():
    #print (index)
    #print (row)
    #sql_state = 'INSERT INTO ' + tablename + '(' + str_c + ')' + 'values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)'
    sql_state = 'INSERT INTO ' + my_tablename + '(' + str_c1 + ')' + 'values (?, ?, ?,?,?)'
    cursor.execute(sql_state, 
                   #row['recid'], row['hhid'], row['personid'], row['pernum'], row['tripid'], row['tripnum'],
                   #row['traveldate'],row['daynum'],row['dayofweek'],row['hhgroup']
                   #row['copied_trip'],
                   row['completed_at'], row['revised_at'],row['revised_count'],row['svy_complete'],row['depart_time_mam'])
                   #row['depart_time_hhmm'],row['depart_time_timestamp'],row['arrival_time_mam'],row['arrival_time_hhmm'],
                   #row['arrival_time_timestamp'],row['origin_name'],row['origin_address'],row['origin_lat'],row['origin_lng'],
                   #row['dest_name'],row['dest_address'],row['dest_lat'],row['dest_lng'],row['trip_path_distance'],row['google_duration'],
                   #row['reported_duration'],row['hhmember1'],row['hhmember2'],row['hhmember3'],row['hhmember4'],row['hhmember5'],row['hhmember6'],
                   #row['hhmember7'],row['hhmember8'],row['hhmember9'],row['hhmember_none'],row['travelers_hh'],row['travelers_nonhh'],row['travelers_total'],
                   #row['origin_purpose'],row['o_purpose_other'],row['dest_purpose'],row['dest_purpose_comment'],row['mode_1'],
                   #row['mode_2'],row['mode_3'],row['mode_4'],row['driver'],row['pool_start'],row['change_vehicles'],row['park_ride_area_start'],
                   #row['park_ride_area_end'],row['park_ride_lot_start'],row['park_ride_lot_end'],row['toll'],row['toll_pay'],
                   #row['taxi_type'],row['taxi_pay'],row['bus_type'],row['bus_pay'],row['bus_cost_dk'],row['ferry_type'],row['ferry_pay'],
                   #row['ferry_cost_dk'],row['rail_type'],row['rail_pay'],row['rail_cost_dk'],row['air_type'],row['air_pay'],
                   #row['airfare_cost_dk'],row['mode_acc'],row['mode_egr'],row['park'],row['park_type'],row['park_pay'],
                   #row['transit_system_1'],row['transit_system_2'],row['transit_system_3'],row['transit_system_4'],row['transit_system_5'],
                   #row['transit_line_1'],row['transit_line_2'],row['transit_line_3'],row['transit_line_4'],row['transit_line_5'],
                   #row['speed_mph'],row['user_merged'],row['user_split'],row['analyst_merged'],row['analyst_split'],
                   #row['flag_teleport'],row['proxy_added_trip'],row['nonproxy_derived_trip'],row['child_trip_location_tripid'],row['tripid_new']) 
    sql_conn.commit()

'''

## put the column name into a list
str_c = ''
for c in final_data.columns.tolist()[1:]:
    print c
    str_c = str_c + '[' + c + '],'   
str_c = str_c[:-1] 
print (str_c)


for index,row in final_data.iterrows():
    #print (index)
    #print (row)
    sql_state = 'INSERT INTO ' + my_tablename + '(' + str_c + ')' + 'values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)'
    cursor.execute(sql_state, row['recid'],
                   row['hhid'],row['personid'],row['pernum'],row['tripid'],row['tripnum'],
                   row['traveldate'],row['daynum'],row['dayofweek'],row['hhgroup'],row['copied_trip'],
                   row['completed_at'],row['revised_at'],row['revised_count'],row['svy_complete'],row['depart_time_mam'],
                   row['depart_time_hhmm'],row['depart_time_timestamp'],row['arrival_time_mam'],row['arrival_time_hhmm'],
                   row['arrival_time_timestamp'],row['origin_name'],row['origin_address'],row['origin_lat'],row['origin_lng'],
                   row['dest_name'],row['dest_address'],row['dest_lat'],row['dest_lng'],row['trip_path_distance'],row['google_duration'],
                   row['reported_duration'],row['hhmember1'],row['hhmember2'],row['hhmember3'],row['hhmember4'],row['hhmember5'],row['hhmember6'],
                   row['hhmember7'],row['hhmember8'],row['hhmember9'],row['hhmember_none'],row['travelers_hh'],row['travelers_nonhh'],row['travelers_total'],
                   row['origin_purpose'],row['o_purpose_other'],row['dest_purpose'],row['dest_purpose_comment'],row['mode_1'],
                   row['mode_2'],row['mode_3'],row['mode_4'],row['driver'],row['pool_start'],row['change_vehicles'],row['park_ride_area_start'],
                   row['park_ride_area_end'],row['park_ride_lot_start'],row['park_ride_lot_end'],row['toll'],row['toll_pay'],
                   row['taxi_type'],row['taxi_pay'],row['bus_type'],row['bus_pay'],row['bus_cost_dk'],row['ferry_type'],row['ferry_pay'],
                   row['ferry_cost_dk'],row['rail_type'],row['rail_pay'],row['rail_cost_dk'],row['air_type'],row['air_pay'],
                   row['airfare_cost_dk'],row['mode_acc'],row['mode_egr'],row['park'],row['park_type'],row['park_pay'],
                   row['transit_system_1'],row['transit_system_2'],row['transit_system_3'],row['transit_system_4'],row['transit_system_5'],
                   row['transit_line_1'],row['transit_line_2'],row['transit_line_3'],row['transit_line_4'],row['transit_line_5'],
                   row['speed_mph'],row['user_merged'],row['user_split'],row['analyst_merged'],row['analyst_split'],
                   row['flag_teleport'],row['proxy_added_trip'],row['nonproxy_derived_trip'],row['child_trip_location_tripid'],row['tripid_new']) 
    sql_conn.commit()
    
    
    
## 7. finished load data
print 'Closing the central database'
sql_conn.close()