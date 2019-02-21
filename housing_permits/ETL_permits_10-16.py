# -*- coding: utf-8 -*-
"""
Created on Tue Jan 29 14:26:47 2019
This script is to update permits database before 2017 from access database to SQL 
@author: AYang
"""

import pandas as pd
import pyodbc
import numpy as np
import os 



DATA_PATH = r'J:\Projects\Permits\17Permit\database\10-16permits'
my_tablename = 'REG10-16PMT'
file_name = 'REG16PMT.txt'

def read_data(DATA_PATH, COUNTY, file_name):
    my_file = pd.DataFrame.from_csv(os.path.join(DATA_PATH, COUNTY, file_name), sep=',', index_col=None)
    return my_file