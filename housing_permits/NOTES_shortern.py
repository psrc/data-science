# -*- coding: utf-8 -*-
"""
Created on Wed Jan 23 16:48:06 2019
to shorte the charater length of 'notes'
@author: AYang
"""

import pandas as pd 
import numpy as np 


my_data = pd.read_csv(r'J:\Projects\Permits\17Permit\database\working\KING\t33KENT_final.txt')

for i in range(len(my_data)):
    my_data['NOTES'][i] = my_data['NOTES'][i][:249]
    
my_data.to_csv(r'J:\Projects\Permits\17Permit\database\working\KING\t33KENT_final.txt')
