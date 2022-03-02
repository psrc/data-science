#School-matching script

# Load Libraries ----------------------------------------------------------
library(tidyverse)
library(sf)
library(lwgeom)
library(stringdist)
library(leaflet)
library(stringr)

# Loading the data --------------------------------------------------------

#schools <- read.csv("J:/Projects/Surveys/HHTravel/Survey2019/Data/schools/schools.csv")
#person_est <-  read.csv("J:/Projects/Surveys/HHTravel/Survey2019/Data/schools/persons_for_estimation_20210413.csv")
#parcels <- read.csv("J:/Projects/Surveys/HHTravel/Survey2019/Data/schools/parcels_for_hh_survey.csv")

schools <- read.csv("schools.csv")
person_est <-  read.csv("persons_for_estimation_20210413.csv")
parcels <- read.csv("parcels_for_hh_survey.csv")

# output files
#new_school_file <- "J:/Projects/Surveys/HHTravel/Survey2019/Data/schools/Updated tables/upd_schools.csv"
new_school_file <- "new_schools.csv"

matched_students_file <- "J:/Projects/Surveys/HHTravel/Survey2019/Data/schools/Updated tables/matched_students_schools.csv"
matched_students_file <- "matched_students_schools.csv"

# School matching ----------------------------------------------------------------

# taking lat long of the reported school from the survey and matching to the closes one from the school table
#using the euclidean distance. Taking into account age of the student and reported school name

#filtering students only from person table

person_students = person_est %>% 
                  filter(school_parcel_id > 0)


schools_geo <- st_as_sf(schools, coords = c("x_coord_sp", "y_coord_sp"), crs=2285)
schools_geo = schools_geo %>% st_transform(crs=4326)

person_students_geo = st_as_sf(person_students, coords = c("school_lng_from_survey", "school_lat_from_survey"), crs=4326)

#adding new schools to the schools table
new_schools <- data.frame(school_id=max(schools$school_id)+1:13, 
                          sname=c("Gene Juarez Academy","Cedar Park Elementary School", "Tesla STEM High School","Bellevue College North Campus",
                                  "Louisa Boren STEM K-8","Queen Anne Elementary School","Cascade Parent Partnership Program","Seattle Maritime Academy",
                                  "McDonald International Elementary School","Science and Math Institute", "Hazel Wolf K-8 ESTEM School",
                                  "Machias Elementary School","Grace Fellowship Preschool"), 
                          category = c('U', "E", "H", "U", "EM","E","EM","U","E","H","H","E", "K" ),
                          lat = c(47.77861,47.72618037650668, 47.648658111974065, 47.63468582773083,47.549586599104245,47.637899264791734,47.646320239697914,
                                  47.66085142038369,47.66821474822901,47.30347631892787,47.71345812361867,47.994115673406675,47.87140496705509),
                          lon = c(-122.3126, -122.28706159151231,-122.0371774631871, -122.14542005498967,-122.36271140600677, -122.34920612686118, 
                                  -122.35822876012728, -122.37435957237449, -122.32659887900779, -122.52791779248497,-122.31450305603917, -122.02969266347733,
                                  -121.80101460197697))


if(!is.null(new_school_file))
    write.csv(new_schools, new_school_file, row.names = FALSE)

new_schools_geo <- st_as_sf(new_schools, coords = c("lon", "lat"), crs=4326)
new_schools_geo$school_latlong = as.character(new_schools_geo$geometry)


schools_geo[(nrow(schools_geo) + 1):(nrow(schools_geo) + nrow(new_schools_geo)), names(new_schools_geo)] <- new_schools_geo



#match schools by distance


school_ids = list()
distance = list()
for (i in 1:nrow(person_students_geo)) {
  
    if (person_students_geo$age[i] < 7) {
      school_queried = schools_geo %>% 
        filter(category %in% c("K","D","E","EM","EMH") )
    } else if ( person_students_geo$age[i] < 13 ) {
      school_queried = schools_geo %>% 
        filter(category %in% c("K","E","EM","EMH","M","MH","EMH") )
    } else if ( person_students_geo$age[i] < 19 ) {
      school_queried = schools_geo %>% 
        filter(category %in% c("EM","EMH","M","MH","EMH","H","U") )
    } else if ( person_students_geo$age[i] <= 25 ) {
      school_queried = schools_geo %>% 
        filter(category %in% c("MH","EMH","H","U") )
    } else if ( person_students_geo$age[i] > 25 ) {
      school_queried = schools_geo %>% 
        filter(category %in% c("U") )
    }
    temp = st_distance(person_students_geo[i,],school_queried,by_element = TRUE)
    index_row = which.min(temp)
    person_students_geo$school_id[i] = school_queried$school_id[index_row]
    person_students_geo$distance[i] = as.double(min(temp))
    
  
    #print(min(st_distance(test_person_student[i,],school_queried,by_element = TRUE)))
    distance = append(distance,as.double(min(temp)))
    
    school_ids = append(school_ids, school_queried$school_id[index_row])
    
    #index_t = append(index_t, which.min(st_distance(test_person_student[i,],schools_geo,by_element = TRUE)))
}


person_students_geo$school_id = school_ids
person_students_geo$distance = unlist(distance)

#matching schools that are above the threshold and have a valid school name entered by school name

#school_ids2 = list() 
for (i in 1:nrow(person_students_geo)) {
   if (person_students_geo$distance [i] > 500) {
      if (person_students_geo$school_name_from_survey[i] != "" ){
        a = grep(person_students_geo$school_name_from_survey[i], schools$sname,ignore.case = TRUE)
        
        if (length(a) == 1) {
          new_dist = as.numeric( st_distance(person_students_geo[i,], schools_geo[a,],by_element = TRUE))
          
          if(person_students_geo$distance[i] > new_dist){
            print(person_students_geo$distance[i])
            print(new_dist)
            print(person_students_geo[i,])
            print(schools_geo[a,])
            
            person_students_geo$school_id[i] = schools_geo$school_id[a]
            person_students_geo$distance[i] = new_dist
            
            }
        } 
      }
    }
  }
  


#Finding the matches are invalid:
# 1. That are above 500 m from assigned school AND
# school name IS NOT equal to University of Washington (due to the greater university area) 

schools_upd <- bind_rows(schools, new_schools)

students_and_schools = person_students_geo %>% 
  mutate(school_id = as.integer(school_id)) %>% 
  left_join(select(schools_upd, school_id, sname), by = "school_id") 

#create a map of the invalid matches
# In the map below we also filter out students  that are over 25 years old
students_and_schools_limited3 = students_and_schools %>% 
    filter(distance >500 & sname != "University Of Washington") %>% filter(age < 25)

# mapping the schools that didnt match

m <- leaflet(students_and_schools_limited3)%>%
    addTiles() %>%
    addCircleMarkers(
        radius = 6,
        color = "green",
        stroke = FALSE, 
        opacity = 1,
        fillOpacity = 0.7,
        popup = paste("School Name: ", students_and_schools_limited3$school_name_from_survey, ", age: ",students_and_schools_limited3$age, 
                      ", assigned: ",students_and_schools_limited3$sname,sep="")) #%>% 

print(m)

not_matched_students <- students_and_schools_limited3
not_matched_students$school_latlong = as.character(not_matched_students$geometry)
st_geometry(not_matched_students) <- NULL
write.csv(not_matched_students, "not_matched_students.csv", row.names = FALSE)


schools_geo$school_latlong = as.character(schools_geo$geometry)
schools_upd = schools_geo
st_geometry(schools_upd) = NULL



# we insert -99 for invalid matches - there are 94 invalid matches (about 9% of all students)
count = 0  
for (i in 1:nrow(students_and_schools)) {
  if (students_and_schools$distance [i] > 500 & students_and_schools$sname[i] != "University Of Washington") {
    students_and_schools$school_id [i] = -99
    students_and_schools$distance [i] = -99
    students_and_schools$sname [i] = ""
    count = count + 1
    
  }
}

students_and_schools$distance = as.numeric(students_and_schools$distance)
st_geometry(students_and_schools) <- NULL

if(!is.null(matched_students_file))
    write.csv(students_and_schools, matched_students_file, row.names = FALSE)


# TODO: try to match not matched schools from students_and_schools_limited3


# testing - checking if the name matches - if not, search name in the school table. If the name didn't match, then school is not present in the school table.

test = head(schools_geo, 100)

agrep(students_and_schools_limited3$school_name_from_survey[1], schools_geo$sname,ignore.case = TRUE, value = TRUE,)
agrep(word(students_and_schools_limited3$school_name_from_survey[1]), schools_geo$sname,ignore.case = TRUE, value = TRUE)
adist('mercer', 'mercer island high school')

a = c("mercer",'mercer island high sch', 'mercer island high school', "sherwood academy")
agrep('mercer island high school', a,ignore.case = TRUE)

for (i in 1:nrow(person_students_geo))

word(students_and_schools_limited2$school_name_from_survey[1])

str_extract_all('mercer island high school', a)


school_ids = list() 
for (i in 1:10){
  if (person_students$school_name_from_survey[i] != "" ){
  a = grep(person_students$school_name_from_survey[i], schools$sname,ignore.case = TRUE)
  school_ids = append(school_ids, schools$school_id[a])
  if (length(a) == 0) {
    school_ids = append(school_ids, 'NA')
  }  }
  else { school_ids = append(school_ids, 'NA')
        print ("nA")}
  
}


