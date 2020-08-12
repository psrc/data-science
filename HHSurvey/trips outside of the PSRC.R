#This script helps to identify the trips that are outside of the PSRC region and have weights.

#first, we need to lead some functions including connections to Elmer
source('global.R')

#read in the trip data
sql.query <- paste("SELECT * FROM HHSurvey.v_trips_2017_2019_in_house" )
trips_new_mobility = read.dt(sql.query, 'sqlquery')

####Check the trip weights outside of the region
#set rough boundaries of the PSRC region and query trip origins and trip destinations outside of the region
#here we want to work with the trips that have at least one of the weights
trips_with_weights = trips_new_mobility %>% filter(trip_weight_revised> 0 | trip_wt_2019>0 | trip_wt_combined >0)

#trips with either origin or destination outside of the PSRC region
temp2 = trips_with_weights %>% filter(((origin_lat > 48.295356 | origin_lat < 46.728387) | (dest_lat > 48.295356 | dest_lat < 46.728387)) & 
                                        ((origin_lng < -123.022946 | origin_lng > -121.065973) | (dest_lng < -123.022946 | dest_lng > -121.065973) ))

#There are 1139 trips with either origin or destination outside of the region AND that have one of the weights
nrow(temp2)

#here is the map for origin of these trips
coords = as.data.frame(cbind(lon=temp2$origin_lng, lat = temp2$origin_lat))

m = leaflet(data = coords) %>% 
  addProviderTiles(providers$CartoDB.Positron) %>% 
  addCircleMarkers(~lon, ~lat)

print(m)

#Trips that have both origin and destination outside of PSRC region
trips_both_outside = trips_with_weights %>% filter(((origin_lat > 48.295356 | origin_lat < 46.728387) & (dest_lat > 48.295356 | dest_lat < 46.728387)) & 
                                        ((origin_lng < -123.022946 | origin_lng > -121.065973) & (dest_lng < -123.022946 | dest_lng > -121.065973) ))

#There are 912 trips with both origin and destination outside of the region AND that have one of the weights
nrow(trips_both_outside)

#here is the map for origin of these trips
coords = as.data.frame(cbind(lon=trips_both_outside$origin_lng, lat = trips_both_outside$origin_lat))

m = leaflet(data = coords) %>% 
  addProviderTiles(providers$CartoDB.Positron) %>% 
  addCircleMarkers(~lon, ~lat)

print(m)

