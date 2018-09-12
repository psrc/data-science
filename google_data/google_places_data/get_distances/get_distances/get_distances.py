from googleplaces import GooglePlaces
import pandas as pd
import os
import numpy as np

#where to find googleplaces: https://github.com/slimkrazy/python-google-places

working_dir = r'C:\Users\SChildress\Documents\google_places_data'
zone_file = 'zone_lat_long.csv'
tract_zone_hh_file = 'tract_zone_hh_file.csv'
zone_distances = 'zone_dist_amenity.csv'
out_file = 'tract_dist_amenity.csv'

amenity_types = ['supermarket','pharmacy','school', 'restaurant']

API_KEY = open(working_dir+'/google_api_key.txt').read()
google_places = GooglePlaces(API_KEY)
# 10K is the farther away to look
max_search =10000

def distance(s_lat, s_lng, e_lat, e_lng):
        # approximate radius of earth in km
    R = 3959.0
    
    s_lat = s_lat*np.pi/180.0                      
    s_lng = np.deg2rad(s_lng)     
    e_lat = np.deg2rad(e_lat)                       
    e_lng = np.deg2rad(e_lng)  
    
    d = np.sin((e_lat - s_lat)/2)**2 + np.cos(s_lat)*np.cos(e_lat) * np.sin((e_lng - s_lng)/2)**2
    
    return 2 * R * np.arcsin(np.sqrt(d))

def find_distance(zone_id, zone_lat, zone_long, amenity):
    query_result = google_places.nearby_search(keyword=amenity,
    lat_lng={'lat': zone_lat, 'lng': zone_long}, rankby = 'distance', 
    radius=max_search)

    try:
        nearest_lat = float(query_result.places[0].geo_location['lat'])
        nearest_long = float(query_result.places[0].geo_location['lng'])
        dist_between = distance(zone_lat, zone_long, nearest_lat, nearest_long)
    except:
        # if it can't find a distance, set the distance at the max distance (10K, 6.2 miles)
        dist_between = 6.2

    return pd.Series([zone_id, dist_between])

def get_distances(zones):
    amenity_count = 0
    for amenity in amenity_types:
        print amenity
        if amenity_count == 0:
            zones_out = zones.apply(lambda row: find_distance(row['ZoneID'], row['LAT'], row['LONG'], amenity), axis=1)
            zones_out.columns = ['ZoneID', amenity]
        else:
            zones_next = zones.apply(lambda row: find_distance(row['ZoneID'], row['LAT'], row['LONG'], amenity), axis=1)
            zones_next.columns = ['ZoneID', amenity]
            zones_out = pd.merge(zones_next, zones_out, on ='ZoneID')
        
        amenity_count = amenity_count + 1
        zones_out.to_csv(working_dir+'\\'+amenity + ' ' + zone_distances)

    return zones_out

def get_tract_distances(zones_distances,tract_zones_hh):
    zone_dist_tract = pd.merge(zones_distances, tract_zones_hh, left_on = 'ZoneID', right_on = 'taz_p')
    g= zone_dist_tract.groupby('GEOID')
    # have to also take care of if there is weird missing data (hh_p)
    tract_distances = g.apply(lambda x: pd.Series(np.average(x[amenity_types], weights=x['hh_p'], axis=0), amenity_types)
                                  if x['hh_p'].sum()>0 
                                  else 
                                  pd.Series(np.average(x[amenity_types], axis=0), amenity_types))

    return tract_distances

def main():
    zones = pd.read_csv(working_dir +'\\' +zone_file)
    tract_zones_hh = pd.read_csv(working_dir +'\\' +tract_zone_hh_file)
    zones_distances = get_distances(zones)
    #zones_distances = pd.read_csv(working_dir +'\\zone_dist_amenity.csv')
    zones_distances.to_csv(working_dir+'\\'+ zone_distances)
    tract_distances = get_tract_distances(zones_distances, tract_zones_hh)
    tract_distances.to_csv(working_dir+'\\'+out_file)

if __name__ == "__main__":
    main()

