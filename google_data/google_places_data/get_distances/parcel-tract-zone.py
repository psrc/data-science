# this aggregates population to zonal level, then tags the population onto the tract file
import pandas as pd


working_dir = r'C:\Users\SChildress\Documents\google_places_data'
parcel_pop_file =  'parcels_urbansim.txt'
tract_zone_file = 'tract_zone.csv'
tract_zone_hh_file = 'tract_zone_hh.csv'


parcel_pop = pd.read_csv(working_dir+'\\'+ parcel_pop_file, sep = ' ')
tract_zone_file = pd.read_csv(working_dir+'\\'+tract_zone_file)

zone_pop = parcel_pop.groupby('taz_p').sum()['hh_p'].reset_index()
zone_tract_hh= pd.merge(tract_zone_file, zone_pop, on= 'taz_p')

zone_tract_hh.to_csv(working_dir +'\\'+'tract_zone_hh_file.csv')