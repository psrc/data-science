import pandas as pd
import numpy as np 
import datetime 
import os 
import matplotlib.pyplot as plt

'''
################ read 2017 ONLINE SURVEY
data_path = r'J:\Projects\Surveys\HHTravel\Survey2017\Data\Cleaning Process'
household = pd.DataFrame.from_csv(os.path.join(data_path, '1-Household.csv'), sep=',', index_col=False)
person = pd.DataFrame.from_csv(os.path.join(data_path, '2-Person.csv'), sep=',', index_col=False)
trip = pd.DataFrame.from_csv(os.path.join(data_path, '5-Trip.csv'), sep=',', index_col=False)
trip_id_file = pd.DataFrame.from_csv(os.path.join(data_path, '5-Trip-ID.csv'), sep=',', index_col=False)
trip_id_file = trip_id_file.rename(columns={'tripid':'tripid_new'})
trip = pd.merge(trip, trip_id_file[['personid', 'tripnum', 'tripid_new']], on=['personid', 'tripnum'], how='left')
'''



############ 3. data quality check & scoring on 10 samples
sample_path = r'R:\Angela\household_survey\data_cleaning\sample_data' 
## READ SAMPLE DATA
household_sample_name = 'hh_10sample_' + '2018-11-15' + '.txt'
household_sample = pd.read_csv(os.path.join(sample_path, household_sample_name))
person_sample_name = 'ps_10sample_' + '2018-11-15' + '.txt'
person_sample = pd.read_csv(os.path.join(sample_path, person_sample_name))
trip_sample_name = 'tp_10sample_' + '2018-11-15' + '.txt'
trip_sample = pd.read_csv(os.path.join(sample_path, trip_sample_name))

## create diff household group based on household size - temporary 
hhsize_dict = household_sample.set_index(['hhid']).to_dict()['hhsize']
trip_sample['hhsize'] = trip_sample['hhid'].map(hhsize_dict)

## merge household, person and trip information all together 
my_data = pd.merge(trip_sample, household_sample, on=['hhid'], how='left')
my_data = pd.merge(my_data, person_sample, on=['personid'], how='left')
my_data.to_csv(r'T:\2018December\Angela\sample_trip_hh_person.csv')


########## prepare for Tableau mapping 
## reshape the trip table, by puting all origin and destination lat, long together
def reshape_lat_long(df, orgin, des, col1, col2):
    my_tp = df[[orgin, des]]
    my_tp = my_tp.stack()
    my_tp = pd.DataFrame(my_tp, columns=[col2])
    my_tp.reset_index(inplace=True) 
    my_tp.columns = ['tripid_new', col1, col2]
    return my_tp

tp_valid_time = my_data
tp_lat = reshape_lat_long(tp_valid_time, 'origin_lat', 'dest_lat', 'od_lat', 'lat')
tp_lng = reshape_lat_long(tp_valid_time, 'origin_lng', 'dest_lng', 'od_lng', 'lng')
tp_stacked = pd.concat([tp_lat, tp_lng], axis=1)
tp_stacked = tp_stacked.iloc[:, 1:] # get rid of the duplicated Trip ID column 

## map information into the (lat,long) rows 
tp_valid_time['tripid_new'] = tp_valid_time.index
result = pd.merge(tp_stacked, tp_valid_time, on='tripid_new', how='left')

## write out trip data
today = datetime.date.today()
trip_file_name = 'trip_sample_OD_' + str(today) + '.txt'
output_path = r'T:\2018December\Angela\tableau'
result.to_csv(os.path.join(output_path, trip_file_name), index=False)





'''trip sample columns 
recid
hhid
personid
pernum
tripid
tripnum
traveldate
daynum
dayofweek
hhgroup
copied_trip
completed_at
revised_at
revised_count
svy_complete
depart_time_mam
depart_time_hhmm
depart_time_timestamp
arrival_time_mam
arrival_time_hhmm
arrival_time_timestamp
origin_name
origin_address
origin_lat
origin_lng
dest_name
dest_address
dest_lat
dest_lng
trip_path_distance
google_duration
reported_duration
hhmember1
hhmember2
hhmember3
hhmember4
hhmember5
hhmember6
hhmember7
hhmember8
hhmember9
hhmember_none
travelers_hh
travelers_nonhh
travelers_total
origin_purpose
o_purpose_other
dest_purpose
dest_purpose_comment
mode_1
mode_2
mode_3
mode_4
driver
pool_start
change_vehicles
park_ride_area_start
park_ride_area_end
park_ride_lot_start
park_ride_lot_end
toll
toll_pay
taxi_type
taxi_pay
bus_type
bus_pay
bus_cost_dk
ferry_type
ferry_pay
ferry_cost_dk
rail_type
rail_pay
rail_cost_dk
air_type
air_pay
airfare_cost_dk
mode_acc
mode_egr
park
park_type
park_pay
transit_system_1
transit_system_2
transit_system_3
transit_system_4
transit_system_5
transit_line_1
transit_line_2
transit_line_3
transit_line_4
transit_line_5
speed_mph
user_merged
user_split
analyst_merged
analyst_split
flag_teleport
proxy_added_trip
nonproxy_derived_trip
child_trip_location_tripid
tripid_new
hhsize
'''





