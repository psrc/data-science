# -*- coding: utf-8 -*-
"""
Created on Thu Jan 03 16:08:04 2019
@author: AYang
This srcipt is to pre-process long string notes, so it would fit in 
"""

import pandas as pd 
import numpy as np 
import os 

JURI_NAME = 'ISSAQUAH'
COUNTY_CODE = '33'
file_name = 't' + COUNTY_CODE + JURI_NAME + '_final.txt'

DATA_PATH = r'J:\Projects\Permits\17Permit\database\working\KING'  
my_data = pd.DataFrame.from_csv(os.path.join(DATA_PATH, file_name), sep=',', index_col=None)

my_data['NOTES'] = my_data['NOTES'].str[500:]

output_file_name = 't' + COUNTY_CODE + JURI_NAME + '2_final.txt'
my_data.to_csv(os.path.join(DATA_PATH, output_file_name))

