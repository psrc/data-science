
import pandas as pd
import os
import numpy as np

working_dir = r'C:\data-science\google_data\google_places_data'
tract_zone_file = 'tract_zone_hh_file.csv'
zone_distances = 'zone_dist_amenity.csv'
out_file = 'tract_dist_amenity.csv'

amenity_types = ['supermarket','pharmacy', 'restaurant']




def get_tract_distances(zones_distances,tract):
    zone_dist_tract = pd.merge(zones_distances, tract, left_on = 'ZoneID', right_on = 'TAZ')
    g= zone_dist_tract.groupby('GEOID10')
    # have to also take care of if there is weird missing data (hh_p)
    tract_distances = g.apply(lambda x: pd.Series(np.average(x[amenity_types], weights=x['hh_p'], axis=0), amenity_types)
                                  if x['hh_p'].sum()>0 
                                  else 
                                  pd.Series(np.average(x[amenity_types], axis=0), amenity_types))

    return tract_distances

def main():
    
    tracts = pd.read_csv(working_dir +'\\' +tract_zone_file)
    first_amenity = True

    for amenity in amenity_types:
        if first_amenity:
            zones_distances_df = pd.read_csv(working_dir+'\\'+amenity+ ' '+ zone_distances)
            first_amenity = False
        else:
            zones_distances_df = pd.merge(zones_distances_df, pd.read_csv(working_dir+'\\'+amenity+ ' '+ zone_distances), on = 'ZoneID')
    
    zones_distances_df = zones_distances_df[['ZoneID', 'supermarket_x', 'pharmacy', 'restaurant']]
    zones_distances_df.rename(columns = {'supermarket_x': 'supermarket'}, inplace = True)
    tract_distances = get_tract_distances(zones_distances_df,tracts)
    tract_distances.to_csv(working_dir+'\\'+out_file)

if __name__ == "__main__":
    main()

