
import pandas as pd
import os
import numpy as np

working_dir = r'C:\data-science2\google_data\google_places_data'
tract_zone_file = 'tract_zone_hh_file.csv'
zone_distances = 'TAZ_Near_Analysis_school.xlsx'
out_file_school = 'tract_dist_school.csv'
out_file_parks = 'tract_dist_parks.csv'




def get_tract_distances(zones_distances,tract, amenity_types):
    zone_dist_tract = pd.merge(zones_distances, tract, left_on = 'TAZ', right_on = 'TAZ')
    g= zone_dist_tract.groupby('GEOID10')
    # have to also take care of if there is weird missing data (hh_p)
    tract_distances = g.apply(lambda x: pd.Series(np.average(x[amenity_types], weights=x['hh_p'], axis=0), amenity_types)
                                  if x['hh_p'].sum()>0 
                                  else 
                                  pd.Series(np.average(x[amenity_types], axis=0), amenity_types))

    return tract_distances

def main():
    
    tracts = pd.read_csv(working_dir +'\\' +tract_zone_file)

    amenity_types = ['school']
    zones_distance_school = pd.read_excel(working_dir +'\\'+ zone_distances, sheetname= 'Schools')
    zones_distance_school_df = zones_distance_school[['TAZ','school']]
    tract_distances = get_tract_distances(zones_distance_school_df,tracts, amenity_types)
    tract_distances.to_csv(working_dir+'\\'+out_file_school)

    amenity_types = ['parks']
    zones_distance_park = pd.read_excel(working_dir +'\\'+ zone_distances, sheetname= 'Parks')
    zones_distance_park_df = zones_distance_park[['TAZ','parks']]
    tract_distances = get_tract_distances(zones_distance_park_df,tracts, amenity_types)
    tract_distances.to_csv(working_dir+'\\'+out_file_parks)

if __name__ == "__main__":
    main()

