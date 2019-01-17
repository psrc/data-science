# -*- coding: utf-8 -*-
"""
Created on Thu Jan 10 11:10:42 2019
@author: ayang
This scirpts is to make a perfect time clock for the tableau visualization 
This time clock act as a background trace for dep_time_mam or arr_time_mam 
so the specific trip detarture/arrival time will drop into the circle.
"""

import pandas as pd 
import numpy as np 
import os 

DATA_PATH = r'H:\Tableau\HHSurvey2017\toolsie\3hhsample'
file_name = 'time_mam_clock.csv'

time_mam_clock = pd.DataFrame.from_csv(os.path.join(DATA_PATH, file_name), sep=',', index_col=None)

# 1. get the full clock for person 1 
# maimum of arrival time mam is 1440
new_index = list(np.arange(1,1441,1))
time_mam_clock = time_mam_clock.reindex(new_index)
time_mam_clock['Id'] = time_mam_clock.index
time_mam_clock['time_mam'] = time_mam_clock['Id']


'''
NOTE:
there is a few -5 in depature time mam 
but we not considering any negative value here, we will transfer negative value to positive 
1440-5 = 1435 
'''

'''
time_mam_clock['pernum'] = 1
   
# 2. get full clock for other persons in the hosehold: person 2 to 9    
my_time_clock = time_mam_clock     
print np.unique(my_time_clock['pernum'])  
for p in range(2,10):
    print p 
    this_p_time_clock = time_mam_clock
    this_p_time_clock['pernum'] = p 
    my_time_clock = pd.concat([my_time_clock, this_p_time_clock])
    print np.unique(my_time_clock['pernum'])
    print ('tot time mam is:'), (len(my_time_clock))
    
print (my_time_clock['pernum'].value_counts())

# 3. massage the table to make it accurate
my_time_clock['time_mam'] = my_time_clock['Id']
my_time_clock = my_time_clock.reset_index()

my_time_clock.loc[0:1439, 'pernum']  = 1
print (my_time_clock['pernum'].value_counts())

# 4. insert rows for departure time mam is -5
 
# 5. output 
output_file_name = 'full_time_mam_clock.csv'
my_time_clock.to_csv(os.path.join(DATA_PATH, output_file_name), sep=',')

'''

# 6. create a master table for all survey trips to get the full clock info
trip_sample_file = 'trips_3hhsample.csv'
trip_sample = pd.DataFrame.from_csv(os.path.join(DATA_PATH, trip_sample_file), sep=',', index_col=None)
print (np.unique(trip_sample['personid']))

personid_list = list(np.unique(trip_sample['personid']))
time_mam_clock_col = time_mam_clock.columns
my_time_mam_clock = pd.DataFrame(columns = time_mam_clock_col)

for personid in personid_list:
    print personid 
    personnum = str(personid)[-1:]
    print personnum
    time_mam_clock['personid'] = personid 
    time_mam_clock['time_id'] = time_mam_clock['personid'].astype(str) + '_' + time_mam_clock['time_mam'].astype(str)
    time_mam_clock['pernum'] = personnum
    my_time_mam_clock = pd.concat([my_time_mam_clock, time_mam_clock])
    
    
## seperate depart time and arrival time into two rows 
test1 = trip_sample.copy()
test1['D/A'] = 'D' #this data table will host all origin information
test2 = trip_sample.copy()
test2['D/A'] = 'A' # destination info

     
 
########## prepare for Tableau mapping ############
## reshape the trip table, by puting all origin and destination lat, long together

# origin == departure
test1['AY_OD_lat'] = test1['origin_lat']
test1['AY_OD_lng'] = test1['origin_lng']
test1['AY_address_name'] = test1['origin_name']
# destination == arrival
test2['AY_OD_lat'] = test2['dest_lat']
test2['AY_OD_lng'] = test2['dest_lng']    
test2['AY_address_name'] = test2['dest_name']
## 
test1['AY_DA_time_mam'] = test1['depart_time_mam']
test2['AY_DA_time_mam'] = test2['arrival_time_mam']

 
######### for time clock mapping ##############
####### departure time clock position 
test = test1.copy()

## get unique id for every time mam clock position
test['depart_time_mam'] = test['depart_time_mam'].fillna(0)
test['depart_time_mam'] = test['depart_time_mam'].astype(int)
test['arrival_time_mam'] = test['arrival_time_mam'].fillna(0)
test['arrival_time_mam'] = test['arrival_time_mam'].astype(int)
test['depart_time_id'] = test['personid'].astype(str) + '_' + test['depart_time_mam'].astype(str)
test['arrival_time_id'] = test['personid'].astype(str) + '_' + test['arrival_time_mam'].astype(str)

## get the time clock place for the departure travel time

# for departure time clock position mark
my_merge1 = pd.merge(left = my_time_mam_clock, right = test, how='left', left_on = 'time_id', right_on = 'depart_time_id')

  
####### arrival time clock position mark  
test = test2.copy()

## get unique id for every time mam clock position
test['depart_time_mam'] = test['depart_time_mam'].fillna(0)
test['depart_time_mam'] = test['depart_time_mam'].astype(int)
test['arrival_time_mam'] = test['arrival_time_mam'].fillna(0)
test['arrival_time_mam'] = test['arrival_time_mam'].astype(int)
test['depart_time_id'] = test['personid'].astype(str) + '_' + test['depart_time_mam'].astype(str)
test['arrival_time_id'] = test['personid'].astype(str) + '_' + test['arrival_time_mam'].astype(str)


## get the time clock spot for the arrival travel time
my_merge2 = pd.merge(left = my_time_mam_clock, right = test, how='left', left_on = 'time_id', right_on = 'arrival_time_id')


################ combine all o-d data ########################
my_df = pd.concat([my_merge1, my_merge2])
my_df = my_df.reset_index()



output_file_name = 'trip_sample_merged_time_mam.csv'
my_df.to_csv(os.path.join(DATA_PATH, output_file_name), sep=',')

print ('done')


'''
there are a few steps have to set up before Tableau could mapping out everything 
step1: create the angel_time_mam
step2: create radius 
setp3: create x,y

'''
