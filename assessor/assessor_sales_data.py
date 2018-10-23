# This script summarizes real estate transction from Assessor Records
# Summary data is calculated by type and median sales price
# Created by Puget Sound Regional Council Staff
# October 2018

import pandas as pd
import os

analysis_year = 2017

working_directory = os.getcwd()
input_directory = os.path.join(working_directory, 'data')
output_directory = os.path.join(working_directory, 'outputs')

# Create the output directory for the trip generation results
if not os.path.exists(output_directory):
    os.makedirs(output_directory)

sales = 'RPSale'
lu_lookup = 'LookUp'
building = 'ResBldg'
condo_units = 'CondoUnit2'
condo_complex = 'CondoComplex'

# Open entire TMC Identification and Speed Files and store in dataframes
print 'Reading the Extract Files into Memory'
df_sales = pd.read_csv(os.path.join(input_directory, 'EXTR_'+sales+'.csv'))
df_lookup = pd.read_csv(os.path.join(input_directory, 'EXTR_'+lu_lookup+'.csv'))
df_building = pd.read_csv(os.path.join(input_directory, 'EXTR_'+building+'.csv'))
df_condo_units = pd.read_csv(os.path.join(input_directory, 'EXTR_'+condo_units+'.csv'))
df_condo_complex = pd.read_csv(os.path.join(input_directory, 'EXTR_'+condo_complex+'.csv'))

# Create a Pin by first removing 0 value pins for major and minor and sales price
print 'Removing records that do not have a major, minor or sales price'
df_sales.columns = df_sales.columns.str.lower()
df_sales = df_sales[(df_sales.major != 0) & (df_sales.minor != 0) & (df_sales.saleprice != 0)] 
df_sales = df_sales[df_sales.propertytype != 0] 
df_sales['major'] = df_sales['major'].astype(float)
df_sales['minor'] = df_sales['minor'].astype(float)
df_sales['pin'] = df_sales['major']+df_sales['minor']
df_sales['pin'] = df_sales['pin'].astype(float)

# Create Trim Down by Principal Use to Condo (2), Apartment (4) or Residential (6)
print 'Trimming Sales data to only inlcude Condo, Apartments and Residential Units'
df_sales = df_sales[(df_sales.principaluse == 2) | (df_sales.principaluse == 4) | (df_sales.principaluse == 6)]

print 'Calculating Sales year and trimming data between 1997 and '+ str(analysis_year)
df_sales[['month', 'day','year']] = df_sales['documentdate'].str.split('/', expand=True)
df_sales['year'] = df_sales['year'].astype(int)
df_sales = df_sales[(df_sales.year >= 1997) & (df_sales.year <= analysis_year)] 

print 'Trimming columns in sales records for analysis'
columns_to_keep = ['pin','major','minor','documentdate','saleprice','propertytype','principaluse','year']
df_sales = df_sales[columns_to_keep]

# Add Number of Living Units to the Sales Transactions
print 'Cleaning up the Residential Building dataframe to assign Living Units in sales database'
# Trim down Building file to Pin, Living Units and Stories
df_building.columns = df_building.columns.str.lower()
columns_to_keep = ['major','minor','nbrlivingunits']
df_building = df_building[columns_to_keep]

# Remove records with 0 values on the columns being preserved
df_building = df_building[(df_building.major != 0)]
df_building = df_building[(df_building.minor != 0)]
df_building = df_building[(df_building.nbrlivingunits != 0)]

# Create a unique pin and then groupby to get a consolidated df of unit counts by unique pin
df_building['pin'] = df_building['major']+df_building['minor']
df_units = df_building.groupby(['pin','nbrlivingunits']).count()
df_units = df_units.reset_index()
columns_to_keep = ['pin','nbrlivingunits']
df_units = df_units[columns_to_keep]
df_units.rename(columns={'nbrlivingunits': 'units'}, inplace=True)
df_building_pin = df_units.groupby('pin').max()
df_building_pin = df_building_pin.reset_index()

# Join with the Sale dataframe to add units to the sale data
print 'Joining the Residential Building Units and Sales Dataframe'
df_sales = pd.merge(df_sales, df_building_pin, on='pin',suffixes=('_x','_y'),how='left')
df_sales.fillna(0,inplace=True)

print 'Cleaning up the Condo Unit dataframe to assign condos to types with pins in sales database'
# Trim down Condo Unit file to Pin, Unit Type and Stories
df_condo_units.columns = df_condo_units.columns.str.lower()
columns_to_keep = ['major','minor','unittype']
df_condo_units = df_condo_units[columns_to_keep]

# Remove records with 0 values on the columns being preserved
df_condo_units = df_condo_units[(df_condo_units.major != 0)]
df_condo_units = df_condo_units[(df_condo_units.minor != 0)]
df_condo_units = df_condo_units[(df_condo_units.unittype != 0)]

# Remove any Unit Types in the exclusion list - only want residential units, not parking and other items
df_condo_units = df_condo_units[df_condo_units.unittype < 5]
df_condo_units['pin'] = df_condo_units['major']+df_building['minor']
df_condos = df_condo_units.groupby(['pin','unittype']).count()
df_condos = df_condos.reset_index()
columns_to_keep = ['pin','unittype']
df_condos = df_condos[columns_to_keep]
df_condos.rename(columns={'unittype': 'condo_type'}, inplace=True)
df_condos_pin = df_condos.groupby('pin').max()
df_condos_pin = df_condos_pin.reset_index()

# Get the building type from the condo complex dataframe
df_condo_complex.columns = df_condo_complex.columns.str.lower()
columns_to_keep = ['major','constrclass']
df_condo_complex = df_condo_complex[columns_to_keep]
df_condo_complex['high_density'] = 0
df_condo_complex.loc[df_condo_complex['constrclass'] <= 2, 'high_density'] = 1
df_condo_complex = df_condo_complex.drop(['constrclass'],axis=1)
df_condo_complex['major'] = df_condo_complex['major'].astype(float)

# Join the Condo Pins with the Sales Database and replace NaN with 0
df_sales = pd.merge(df_sales, df_condos_pin, on='pin',suffixes=('_x','_y'),how='left')
df_sales.fillna(0,inplace=True)

# Merge in definition of high density units from the complex definition
df_sales = pd.merge(df_sales, df_condo_complex, on='major',suffixes=('_x','_y'),how='left')
df_sales.fillna(0,inplace=True)
df_sales['medium_density'] = 0
df_sales.loc[(df_sales['condo_type'] >= 1) & (df_sales['high_density'] == 0), 'medium_density'] = 1
df_sales['density'] = 0
df_sales.loc[df_sales['medium_density'] == 1 , 'density'] = 1
df_sales.loc[df_sales['high_density'] == 1 , 'density'] = 2

# Summarize Total Sales Transactions by Year and Density and output csv
print 'Calculating total transactions by year density type'
df_density = df_sales.groupby(['year','density']).count()
df_density = df_density.reset_index()
columns_to_keep = ['year','density','saleprice']
df_density = df_density[columns_to_keep]
df_density.rename(columns={'saleprice': 'transactions'}, inplace=True)
df_density.to_csv(os.path.join(output_directory,'residential_unit_transactions_w_density.csv'),index=False)

# Summarize Average Price for Transactions by Year and output csv
print 'Calculating median sales price by property type by year'
df_price_transactions = df_sales.groupby(['year','density']).quantile(0.50) 
df_price_transactions = df_price_transactions.reset_index()
columns_to_keep = ['year','density','saleprice']
df_price_transactions = df_price_transactions[columns_to_keep]
df_price_transactions.rename(columns={'saleprice': 'median-sales-price'}, inplace=True)
df_price_transactions.to_csv(os.path.join(output_directory,'median_price_all_transactions.csv'),index=False)

exit()

