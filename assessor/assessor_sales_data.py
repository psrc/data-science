# This script summarizes real estate transction from Assessor Records
# Summary data is calculated by type and median sales price
# Created by Puget Sound Regional Council Staff
# October 2018

import pandas as pd
import os

start_year = 2008
end_year = 2018

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

# Create Trim Down by Principal Use to Condo (2), Apartment (4) or Residential (6)
print 'Trimming Sales data to only inlcude Condo, Apartments and Residential Units'
df_sales = df_sales[(df_sales.principaluse == 2) | (df_sales.principaluse == 4) | (df_sales.principaluse == 6)]

print 'Calculating Sales year and trimming data between ' + str(start_year) + ' and '+ str(end_year)
df_sales[['month', 'day','year']] = df_sales['documentdate'].str.split('/', expand=True)
df_sales['year'] = df_sales['year'].astype(int)
df_sales = df_sales[(df_sales.year >= start_year) & (df_sales.year <= end_year)] 

print 'Trimming columns in sales records for analysis'
columns_to_keep = ['pin','major','minor','documentdate','saleprice','propertytype','principaluse','year']
df_sales = df_sales[columns_to_keep]

#####################################################################################################
#####################################################################################################
### Residential Building Data
#####################################################################################################
#####################################################################################################
print 'Cleaning up the Residential Building dataframe to assign Living Units, Size and Zipcode to the sales database'
df_building.columns = df_building.columns.str.lower()
columns_to_keep = ['major','minor','nbrlivingunits','sqfttotliving','zipcode']
df_building = df_building[columns_to_keep]

# Remove records with 0 values on the columns being preserved
df_building = df_building[(df_building.major != 0)]
df_building = df_building[(df_building.minor != 0)]
df_building = df_building[(df_building.nbrlivingunits != 0)]
df_building = df_building[(df_building.zipcode != 0)]
df_building = df_building[(df_building.sqfttotliving != 0)]

# Create a unique pin and then groupby to get a consolidated df of unit counts by unique pin
df_building['major'] = df_building['major'].astype(float)
df_building['minor'] = df_building['minor'].astype(float)
df_building['pin'] = df_building['major']+df_building['minor']

working_columns = ['nbrlivingunits','sqfttotliving','zipcode']

for current_column in working_columns:
    working_df = df_building.groupby(['pin',current_column]).count()
    working_df = working_df.reset_index()
    columns_to_keep = ['pin',current_column]
    working_df = working_df[columns_to_keep]
    df_working_pin = working_df.groupby('pin').max()
    df_working_pin = df_working_pin.reset_index()
    print 'Joining the ' + current_column + ' to the Sales Dataframe'
    df_sales = pd.merge(df_sales, df_working_pin, on='pin',suffixes=('_x','_y'),how='left')

# Celan up columns in the sales data
df_sales.rename(columns={'nbrlivingunits': 'units'}, inplace=True)
df_sales.rename(columns={'sqfttotliving': 'sqft'}, inplace=True)
df_sales.fillna(0,inplace=True)
df_sales = df_sales[df_sales.zipcode >= 1] 
df_sales = df_sales[df_sales.sqft >= 100] 
df_sales = df_sales[(df_sales.saleprice >= 1000) & (df_sales.saleprice <= 2500000)] 
df_sales = df_sales[df_sales.propertytype <= 15]

#####################################################################################################
#####################################################################################################
### Condo Units
#####################################################################################################
#####################################################################################################
print 'Cleaning up the Condo Unit dataframe to assign condos to types with pins in sales database'
df_condo_units.columns = df_condo_units.columns.str.lower()
columns_to_keep = ['major','minor','unittype']
df_condo_units = df_condo_units[columns_to_keep]

# Remove records with 0 values on the columns being preserved
df_condo_units = df_condo_units[(df_condo_units.major != 0)]
df_condo_units = df_condo_units[(df_condo_units.minor != 0)]
df_condo_units = df_condo_units[(df_condo_units.unittype != 0)]

# Remove any Unit Types in the exclusion list - only want residential units, not parking and other items
df_condo_units = df_condo_units[df_condo_units.unittype < 5]
df_condo_units['major'] = df_condo_units['major'].astype(float)
df_condo_units['minor'] = df_condo_units['minor'].astype(float)
df_condo_units['pin'] = df_condo_units['major']+df_building['minor']
df_condos = df_condo_units.groupby(['pin','unittype']).count()
df_condos = df_condos.reset_index()
columns_to_keep = ['pin','unittype']
df_condos = df_condos[columns_to_keep]
df_condos.rename(columns={'unittype': 'condo_type'}, inplace=True)
df_condos_pin = df_condos.groupby('pin').max()
df_condos_pin = df_condos_pin.reset_index()

# Join the Condo Pins with the Sales Database and replace NaN with 0
df_sales = pd.merge(df_sales, df_condos_pin, on='pin',suffixes=('_x','_y'),how='left')
df_sales.fillna(0,inplace=True)

#####################################################################################################
#####################################################################################################
### High End Condo Units
#####################################################################################################
#####################################################################################################
print 'Assigning Construction Type to Condo Units'
df_condo_complex.columns = df_condo_complex.columns.str.lower()
columns_to_keep = ['major','constrclass']
df_condo_complex = df_condo_complex[columns_to_keep]
df_condo_complex['high_density'] = 0
df_condo_complex.loc[df_condo_complex['constrclass'] <= 2, 'high_density'] = 1
df_condo_complex = df_condo_complex.drop(['constrclass'],axis=1)
df_condo_complex['major'] = df_condo_complex['major'].astype(float)

# Merge in definition of high density units from the complex definition
df_sales = pd.merge(df_sales, df_condo_complex, on='major',suffixes=('_x','_y'),how='left')
df_sales.fillna(0,inplace=True)

#####################################################################################################
#####################################################################################################
### Define Single Family and Non-Single Family
#####################################################################################################
#####################################################################################################
print 'Defining Housing Type in Sales data'
df_sales['Housing_Type'] = 0
df_sales.loc[df_sales['principaluse'] < 6 , 'Housing_Type'] = 2
df_sales.loc[(df_sales['principaluse'] == 6 ) & (df_sales['condo_type'] > 0 ), 'Housing_Type'] = 2
df_sales.loc[(df_sales['condo_type'] == 2 ) | (df_sales['condo_type'] == 4 ), 'Housing_Type'] = 2
df_sales.loc[(df_sales['condo_type'] == 1 ) | (df_sales['condo_type'] == 3 ), 'Housing_Type'] = 3
df_sales.loc[df_sales['high_density'] == 1, 'Housing_Type'] = 4
df_sales.loc[df_sales['Housing_Type'] == 0, 'Housing_Type'] = 1

#####################################################################################################
#####################################################################################################
### Define Sales Price Bins
#####################################################################################################
#####################################################################################################
print 'Defining Housing Sales Price Bin'
df_sales['Price_Bin'] = 0
starting_price = 0

for current_bin in range (1,51):
    df_sales.loc[(df_sales['saleprice'] >= starting_price) & (df_sales['saleprice'] < starting_price + 50000 ), 'Price_Bin'] = current_bin
    starting_price = starting_price + 50000
    
#####################################################################################################
#####################################################################################################
### Summarize Transactions
#####################################################################################################
#####################################################################################################
# Export Fulls Sales Transactions
df_sales.to_csv(os.path.join(output_directory,'total_residential_sales_transactions.csv'),index=False)

print 'Calculating total transactions by year and housing type'
df_summary = df_sales.groupby(['year','Housing_Type']).count()
df_summary = df_summary.reset_index()
columns_to_keep = ['year','Housing_Type','saleprice']
df_summary = df_summary[columns_to_keep]
df_summary.rename(columns={'saleprice': 'transactions'}, inplace=True)
df_summary.to_csv(os.path.join(output_directory,'summarized_transactions_by_year_type.csv'),index=False)

print 'Calculating total transactions by year, housing type and price bin'
df_summary = df_sales.groupby(['year','Housing_Type','Price_Bin']).count()
df_summary = df_summary.reset_index()
columns_to_keep = ['year','Housing_Type','Price_Bin','saleprice']
df_summary = df_summary[columns_to_keep]
df_summary.rename(columns={'saleprice': 'transactions'}, inplace=True)
df_summary.to_csv(os.path.join(output_directory,'summarized_transactions_by_year_type_price.csv'),index=False)

# Summarize Average Price for Transactions by Year and output csv
print 'Calculating median sales price by property type and year'
df_summary = df_sales.groupby(['year','Housing_Type']).quantile(0.50) 
df_summary = df_summary.reset_index()
columns_to_keep = ['year','Housing_Type','saleprice']
df_summary = df_summary[columns_to_keep]
df_summary.rename(columns={'saleprice': 'median-sales-price'}, inplace=True)
df_summary.to_csv(os.path.join(output_directory,'median_price_by_type.csv'),index=False)

exit()

