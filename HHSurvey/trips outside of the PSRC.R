#This script helps to identify the trips that are outside of the PSRC region and have weights.

library(rgeos)
library(sp)
library(rgdal)
library(sf)
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

# sum of the weights for trips that have either O or D outside of the PSRC region
temp2 %>% select(trip_weight_revised,trip_wt_2019, trip_wt_combined) %>% 
  summarize(sum_wt_comb = sum(trip_wt_combined,na.rm = TRUE),sum_wt_2017 = sum(trip_weight_revised,na.rm = TRUE),sum_wt_2019 = sum(trip_wt_2019,na.rm = TRUE))

# sum of the weights for trips that have both O and D outside of the PSRC region
trips_both_outside %>% select(trip_weight_revised,trip_wt_2019, trip_wt_combined) %>% 
  summarize(sum_wt_comb = sum(trip_wt_combined,na.rm = TRUE),sum_wt_2017 = sum(trip_weight_revised,na.rm = TRUE),sum_wt_2019 = sum(trip_wt_2019,na.rm = TRUE))

# sum of the weights for ALL trips 
trips_new_mobility%>% select(trip_weight_revised,trip_wt_2019, trip_wt_combined) %>% 
  summarize(sum_wt_comb = sum(trip_wt_combined,na.rm = TRUE),sum_wt_2017 = sum(trip_weight_revised,na.rm = TRUE),sum_wt_2019 = sum(trip_wt_2019,na.rm = TRUE))

# estimating the precise out of the region trips using geograpghic locations

#download counties
county_psrc_counties <- tracts("WA", county = c(033,035,053,061), cb = TRUE)

#loop checking if the origin or destination of the trip outside of the region or not
for (row in 1:nrow(trips_with_weights)) {
  o_lat = trips_with_weights[row,"origin_lat"]
  o_lon = trips_with_weights[row,"origin_lng"]
  d_lat = trips_with_weights[row,"dest_lat"]
  d_lon = trips_with_weights[row,"dest_lng"]
  
  dat = data.frame(Latitude = c(o_lat, d_lat),
                   Longitude = c(o_lon,d_lon))
  
  coordinates(dat) <- ~ Longitude + Latitude
  
  proj4string(dat) <- proj4string(county_psrc_counties)
  
  over(dat, county_psrc_counties)
  
  
}

#test - join

for (row in 1:1) {
  o_lat = trips_with_weights$origin_lat[row]
  o_lon = trips_with_weights$origin_lng[row]
  d_lat = trips_with_weights$dest_lat[row]
  d_lon = trips_with_weights$dest_lng[row]
  
  dat =data.frame(Latitude = c(o_lat, d_lat),
                   Longitude = c(o_lon,d_lon))
  coordinates(dat) <- c('Latitude','Longitude') 
  
  locations_sf = st_as_sf(dat,dat = c("Longitude","Latitude" ), crs = 4326)
  locations_sf = st_set_crs(locations_sf, 4326)
  
  #dat <- spTransform(dat, proj4string(county_psrc_counties))
  #proj4string(dat) <- proj4string(county_psrc_counties)
  
  output_2 = st_intersects(locations_sf,county_psrc_counties)
}

trip_in_tract <- st_join(locations_sf,county_psrc_counties)
