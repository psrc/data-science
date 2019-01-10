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
'''
NOTE:
there is a few -5 in depature time mam 
but we not considering any negative value here, we will transfer negative value to positive 
1440-5 = 1435 
'''
time_mam_clock['pernum'] = 1
   
# 2. get full clock for other persons in the hosehold: person 2 to 9    
my_time_clock = time_mam_clock       
for p in range(2, 10):
    print p 
    this_p_time_clock = time_mam_clock
    this_p_time_clock['pernum'] = p 
    
    my_time_clock = pd.concat([my_time_clock, this_p_time_clock])
    print ('tot time mam is:'), (len(my_time_clock))

# 3. insert rows for departure time mam is -5

# 4. 
my_time_clock['time_mam'] = my_time_clock['Id']

# 5. output 
output_file_name = 'full_time_mam_clock.csv'
my_time_clock.to_csv(os.path.join(DATA_PATH, output_file_name), sep=',')



