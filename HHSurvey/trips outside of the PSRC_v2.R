library(data.table)
library(tidyverse)
library(odbc)
library(DBI)
library(sf)
library(leaflet)
library(tigris)

db.connect <- function() {
  elmer_connection <- dbConnect(odbc(),
                                driver = "SQL Server",
                                server = "AWS-PROD-SQL\\COHO",
                                database = "Elmer",
                                trusted_connection = "yes"
  )
}

read.dt <- function(astring, type =c('table_name', 'sqlquery')) {
  elmer_connection <- db.connect()
  if (type == 'table_name') {
    dtelm <- dbReadTable(elmer_connection, SQL(astring))
  } else {
    dtelm <- dbGetQuery(elmer_connection, SQL(astring))
  }
  dbDisconnect(elmer_connection)
  setDT(dtelm)
}

#read in the trip data
sql.query <- paste("SELECT * FROM HHSurvey.v_trips_2017_2019_in_house")
trips_new_mobility = read.dt(sql.query, 'sqlquery')

####Check the trip weights outside of the region
#set rough boundaries of the PSRC region and query trip origins and trip destinations outside of the region
#here we want to work with the trips that have at least one of the weights
trips_with_weights = trips_new_mobility %>% filter(trip_weight_revised> 0 | trip_wt_2019>0 | trip_wt_combined >0)

# read tract shape from tigris and transform to sf object
psrc_tracts <- tracts("WA", county = c(033,035,053,061), cb = TRUE) %>%
  st_as_sf() %>%
  st_transform(crs=4326)

#drop rows with na
trips_with_weights = trips_with_weights[!is.na(trips_with_weights$origin_lat),]
trips_with_weights = trips_with_weights[!is.na(trips_with_weights$dest_lat),]

#processing origins
lat = trips_with_weights$origin_lat
lng = trips_with_weights$origin_lng
trip_id = trips_with_weights$trip_id

dat_o = data.frame(Latitude = lat,
                   Longitude = lng,
                   trip_id = trip_id)

#processing destinations
lat = trips_with_weights$dest_lat
lng = trips_with_weights$dest_lng
trip_id = trips_with_weights$trip_id

dat = data.frame(Latitude = lat,
                 Longitude = lng,
                 trip_id = trip_id )


# set points as sf
locations_sf_o <- st_as_sf(dat_o, coords = c("Longitude", "Latitude"), crs=4326)
locations_sf <- st_as_sf(dat, coords = c("Longitude", "Latitude"), crs=4326)

# spatial join origin and destination points with PSRC region
trip_in_tract_orig <- st_join(locations_sf_o, psrc_tracts)
trip_in_tract_dest <- st_join(locations_sf, psrc_tracts)

#I've noticed that there are more number of rows in joined data than in original data (73191 vs 73192). Need to check it 
trip_in_tract_dest[duplicated(trip_in_tract_dest$trip_id),]
trip_in_tract_orig[duplicated(trip_in_tract_orig$trip_id),]

#it looks like one of the trips was assigned to two tracts (maybe it was on the boarder) in both
#trip_in_tract_orig and trip_in_tract_dest and this trip is within the region. 
#So, i decide to delete one of the entries of this trip
trip_in_tract_dest = unique( trip_in_tract_dest[ , 1:3 ] )
trip_in_tract_orig = unique( trip_in_tract_orig[ , 1:3 ] )

#In the join table, if the row has NAs, it means that the point was outside the region.
#Hense, the new column will indicate if the trips was outside or inside of the region
trip_in_tract_orig$o_outside = is.na(trip_in_tract_orig$STATEFP)
trip_in_tract_dest$d_outside = is.na(trip_in_tract_dest$STATEFP)

#choosing the trip id and indication if the point is inside or outside for the future join
temp3 = subset(trip_in_tract_orig, select =c("trip_id","o_outside" ))
temp4 = subset(trip_in_tract_dest, select =c("trip_id","d_outside" ))

#removing any geometry to allow for merge
st_geometry(temp3) <- NULL
st_geometry(temp4) <- NULL

#merging origin points and destination points by trip id
trips_region_full = merge(temp3,temp4,by = "trip_id")

#creting new columns to indicate if both O and D are outside; O or D are outside; 
#or both O and D are inside the region
trips_region_full$both_outside = trips_region_full$o_outside & trips_region_full$d_outside
trips_region_full$one_outside = xor(trips_region_full$o_outside, trips_region_full$d_outside)
trips_region_full$both_inside = !trips_region_full$o_outside & !trips_region_full$d_outside

#merge with the trip table
trips_with_weights_upd = merge(trips_region_full,trips_with_weights, by = "trip_id")



#this one took too much time to run (stopped it after an hour of running)
#new column
trips_with_weights$trips_region = "999"
y = 1

for (row in seq(1, nrow(trip_in_tract), 2)){
  
  if (is.na(trip_in_tract$STATEFP)[row] == FALSE & is.na(trip_in_tract$STATEFP)[row+1] == FALSE) {
    
    trips_with_weights$trips_region[y] = "both inside"
    
  } else if(is.na(trip_in_tract$STATEFP)[row] == TRUE & is.na(trip_in_tract$STATEFP)[row+1] == TRUE){
    
    trips_with_weights$trips_region[y] = "both outside"
    
  } else {
    
    trips_with_weights$trips_region[y] = "O or D outside"
  }
  y= y+1
  
}

# set points as sf
locations_sf <- st_as_sf(dat, coords = c("Longitude", "Latitude"), crs=4326)

# map check
m <- leaflet()%>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addPolygons(data=psrc_tracts,
              stroke = T,
              weight = 1,
              color = "#D3D3D3") %>%
  addCircleMarkers(data=locations_sf,
                   stroke = T,
                   weight = 2) %>%
  setView(lng = -122.008546, lat = 47.549390, zoom = 7)
print(m)

# spatial join with sf
trip_in_tract <- st_join(locations_sf, psrc_tracts)
trip_in_tract$STATEFP[2]


for (i in seq(1, nrow(trips_with_weights), 2)){
  print(i)
  
}
