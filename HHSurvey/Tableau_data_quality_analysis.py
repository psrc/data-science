import pandas as pd
import numpy as np 
import datetime 
import os 
import matplotlib.pyplot as plt

################ read 2017 ONLINE SURVEY
data_path = r'J:\Projects\Surveys\HHTravel\Survey2017\Data\Cleaning Process'
household = pd.DataFrame.from_csv(os.path.join(data_path, '1-Household.csv'), sep=',', index_col=False)
person = pd.DataFrame.from_csv(os.path.join(data_path, '2-Person.csv'), sep=',', index_col=False)
trip = pd.DataFrame.from_csv(os.path.join(data_path, '5-Trip.csv'), sep=',', index_col=False)
trip_id_file = pd.DataFrame.from_csv(os.path.join(data_path, '5-Trip-ID.csv'), sep=',', index_col=False)
trip_id_file = trip_id_file.rename(columns={'tripid':'tripid_new'})
trip = pd.merge(trip, trip_id_file[['personid', 'tripnum', 'tripid_new']], on=['personid', 'tripnum'], how='left')

'''
hh_cols = ['hhid', 'reported_lat', 'reported_lng', 'final_haddress', 'sample_haddress']
hh = household[hh_cols]
ps_cols = ['hhid', 'personid', 'pernum', 'age']
ps = person[ps_cols]

tp_cols = ['hhid', 'personid', 'pernum', 'tripid_new', 'tripnum', 
           'depart_time_timestamp', 'arrival_time_timestamp', 
           'origin_lat', 'origin_lng', 'dest_lat', 'dest_lng',
           'depart_time_mam', 'depart_time_hhmm', 'arrival_time_mam', 'arrival_time_hhmm',
           'origin_purpose', 'dest_purpose', 'mode_1', 'travelers_hh', 'travelers_nonhh']
tp = trip[tp_cols]
#tp['ID_AY'] = tp.index
tp = tp.set_index(['tripid_new'])

########## 0. get trips with valid time stamp: 
tp_valid_time = tp[~tp.loc[:, 'depart_time_mam'].isnull()]
'''



'''
########### 2. get a sample from whole dataset 
hhid_list = np.unique(result['hhid'])[:20].tolist()
household_sample = household[household['hhid'].isin(hhid_list)]
print household_sample.shape
person_sample = person[person['hhid'].isin(hhid_list)]
print person_sample.shape
trip_sample = trip[trip['hhid'].isin(hhid_list)]
print trip_sample.shape
result_sample = result[result['hhid'].isin(hhid_list)]
print result_sample.shape

output_path = r'T:\2018November\Angela\Household_Survey\raw_data'
result_sample_name = 'tp_result_10sample_' + str(today) + '.txt'
result_sample.to_csv(os.path.join(output_path, result_sample_name), index=False)
household_sample_name = 'hh_10sample_' + str(today) + '.txt'
household_sample.to_csv(os.path.join(output_path, household_sample_name), index=False)
person_sample_name = 'ps_10sample_' + str(today) + '.txt'
person_sample.to_csv(os.path.join(output_path, person_sample_name), index=False)
trip_sample_name = 'tp_10sample_' + str(today) + '.txt'
trip_sample.to_csv(os.path.join(output_path, trip_sample_name), index=False)
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

# quality check dataframe
trip_data_quality = pd.DataFrame()
trip_data_quality = pd.DataFrame(trip_sample.groupby(['hhsize']).size(), columns = ['size'])



## Q - home trips 
'''
From Document: 
The first thing I look at is PURPOSE = 1 (Home trips) 
And check them against PLACE and ADDRESS to make sure they agree where the destination is actually the home address. 
There were a lot of links coded as PURPOSE = 1 that involved change mode. 
These were usually easily identified by a combination of short duration , various strings for ‘bus stop’, ‘transit station’, etc., 
and address string that’s a cross street or point location. 
I left these purposes as ‘1’, to be handled later when we linked trips.
I first sorted by PURPOSE then PLACE_END to look at cases where PURPOSE = 1 and PLACE_END  ≠ ‘HOME’. 
Many of these cases were as described above. 
But there were a couple hundred that needed to be changed to some other purpose, typically ‘2’, ‘10’ or ‘12’.
'''
## Q1 MISMATCH: trip purpose & destination name 
trip_sample.loc[:, 'Q1'] = ((trip_sample.loc[:, 'dest_purpose']==1)
                           &(trip_sample.loc[:, 'dest_name']!='HOME')).astype(int)
# group by based on household size group - temproray 
trip_data_quality['Q1_score'] = trip_sample.groupby(['hhsize'])['Q1'].sum()/trip_sample.groupby(['hhsize'])['Q1'].size()


## Q2 MISMATCH: destination & home addresses 
'''
note: the mismatch pattern could be typo/writing order/comma in address names 
'''
## compare home address
# get official home address
haddress_dict = household_sample.set_index(['hhid']).to_dict()['sample_haddress'] #sample_address is the home address
hbg_dict = household_sample.set_index(['hhid']).to_dict()['final_bg'] # sampel home census block
trip_sample['sample_haddress'] = trip_sample['hhid'].map(haddress_dict)
trip_sample['final_bg'] = trip_sample['hhid'].map(hbg_dict)
# check home address
trip_sample.loc[:, 'Q2_temp1'] = ((trip_sample['dest_name']=='HOME')
                                &(trip_sample['dest_address']!=trip_sample['sample_haddress'])).astype(int)

## compare x,y coordinate for trip destinations and home address:
# get x, y
restricted_hh_path = r'T:\2018December\Angela\2017-internal-v2-R-1-household.csv' #'J:\Projects\Surveys\HHTravel\Survey2017\Data\Export\Version 2\Restricted\In-house\2017-internal-v2-R-1-household.csv'
restricted_hh = pd.read_csv(restricted_hh_path)
hx_dict = restricted_hh.set_index(['hhid']).to_dict()['final_home_lat'] # home latitude
hy_dict = restricted_hh.set_index(['hhid']).to_dict()['final_home_lng'] # home longtitude
trip_sample['final_home_lat'] = trip_sample['hhid'].map(hx_dict)
trip_sample['final_home_lng'] = trip_sample['hhid'].map(hy_dict)
# check x, y on the top of mismatched home address, NOTES: we just want to check home trip here 
trip_sample['Q2_temp2'] = ((trip_sample['Q2_temp1'] == 1)
                    &((trip_sample['dest_lat']!=trip_sample['final_home_lat']) 
                    |(trip_sample['dest_lng']!=trip_sample['final_home_lng']))).astype(int)


## Q3 MISMATCH: destination & home x,y coordinates
## calculate the distance between home and destination
from math import sin, cos, sqrt, atan2, radians
def calculate_distance(row):
    # approximate radius of earth in kilow meter (I can't find foot version, so let's do km at first)
    R = 6373.0
    lat1 = radians(row['dest_lat'])
    lon1 = radians(row['dest_lng'])
    lat2 = radians(row['final_home_lat'])
    lon2 = radians(row['final_home_lng'])
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = sin(dlat / 2)**2 + cos(lat1) * cos(lat2) * sin(dlon / 2)**2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    distance = R * c
    return distance

trip_sample['Q2_distance'] = trip_sample.apply(lambda row: row['Q2_temp2']*calculate_distance(row), axis=1)
#trip_sample['Q2_distance'] = trip_sample['Q2_distance']*3280 #convert KM to foot
trip_sample['Q2_distance'] = trip_sample['Q2_distance']*0.62 #convert KM to mile

## histogram plotf 
plt.hist(trip_sample.loc[:, 'Q2_distance'], bins=50, range=(0, 5000))
plt.xlabel('Q2_DISTANCE_fake home destination to registered home')
plt.ylabel('frequency')
plt.show()
## scatter 
plt.scatter(trip_sample['tripid_new'], trip_sample['Q2_distance'])
plt.xlabel('trip_id')
plt.ylabel('distance')
plt.show()

## decide any place more than 0.5 miles away, we will mark as abnormal data, we can look into it later 
trip_sample['Q2_1miles'] = (trip_sample['Q2_distance'] > 1).astype(int)
trip_data_quality['Q2_1miles_score'] = trip_sample.groupby(['hhsize'])['Q2_1miles'].sum()/trip_sample.groupby(['hhsize'])['Q1'].size()
trip_sample['Q2_0.5miles'] = (trip_sample['Q2_distance'] > 0.5).astype(int)
trip_data_quality['Q2_0.5mils_score'] = trip_sample.groupby(['hhsize'])['Q2_0.5miles'].sum()/trip_sample.groupby(['hhsize'])['Q1'].size()

'''
note: within same household, there could be same type of abnormal trips; because all persons in that hh made the same trip
'''
########## prepare for Tableau mapping 
## reshape the trip table, by puting all origin and destination lat, long together
def reshape_lat_long(df, orgin, des, col1, col2):
    my_tp = df[[orgin, des]]
    my_tp = my_tp.stack()
    my_tp = pd.DataFrame(my_tp, columns=[col2])
    my_tp.reset_index(inplace=True) 
    my_tp.columns = ['tripid_new', col1, col2]
    return my_tp

tp_valid_time = trip_sample
tp_lat = reshape_lat_long(tp_valid_time, 'origin_lat', 'dest_lat', 'od_lat', 'lat')
tp_lng = reshape_lat_long(tp_valid_time, 'origin_lng', 'dest_lng', 'od_lng', 'lng')
tp_stacked = pd.concat([tp_lat, tp_lng], axis=1)
tp_stacked = tp_stacked.iloc[:, 1:] # get rid of the duplicated Trip ID column 

## map information into the (lat,long) rows 
tp_valid_time['tripid_new'] = tp_valid_time.index
result = pd.merge(tp_stacked, tp_valid_time, on='tripid_new', how='left')
result['dot_id_AY'] = result.index # for tableau mapping dots 

## write out trip data
today = datetime.date.today()
trip_file_name = 'trip_sample_OD_' + str(today) + '.txt'
output_path = r'T:\2018December\Angela\tableau'
result.to_csv(os.path.join(output_path, trip_file_name), index=False)

## write out quality data
trip_data_quality.reset_index(level=0, inplace=True)
quality_file_name = 'quality_check_hhsize_' + str(today) + '.txt'
trip_data_quality.to_csv(os.path.join(output_path, quality_file_name), index=False)















