import urllib2, json
import pandas as pd
import numpy as np
import datetime, time
from SECRET_KEY import secret_key

def main():
	# Load TAZ records with x and y coordinates attached
	taz = pd.read_csv(r'R:\Brice\googlemaps\taz_xy\taz_xy.txt')

	# Create a Google-formatted coordinates field
	taz['g_coord'] = taz['y_gps'].astype('str') + ',' + taz['x_gps'].astype('str')



	# set standard departure time for tomorrow at 8 AM
	dep_hr = 8
	dep_time = datetime.datetime.now()
	dep_time = dep_time.replace(hour=dep_hr,day=dep_time.day+1)
	dep_time = str(int(time.mktime(dep_time.timetuple())))

	# Skims can be auto, transit, bike, or walk
	mode = 'auto'

	# Create empty skims to be filled with results
	skims = {'auto_8_dist': np.zeros([4000,4000]),
	    'auto_8_time_ff': np.zeros([4000,4000]),
	    'auto_8_time_congested': np.zeros([4000,4000])}

	# list of TAZ IDs to find data for, max size of 25 per request
	taz_list = [range(1,25)]
	# taz_list = [xrange(i,i+25) for i in range(1,4000,25)]
	# taz_lists = [xrange(i,i+25) for i in range(1,200,25)]
	# taz_lists = [xrange(300,303)]

	for taz_list in taz_lists:

		# Look up 
		for otaz in taz_list:
		    results = {}
		    urlfeed = ""
		    print otaz
		    origin = taz[taz['ID'] == otaz]['g_coord'].values[0]
		    # get list of different destinations
		    destination = ''
		    dtaz_list = []
		    for dtaz in taz_list:
		        if otaz != dtaz:    # skip intrazonal trips where otaz==dtaz
		            destination += taz[taz['ID'] == dtaz]['g_coord'].values[0] + '|'
		            dtaz_list.append(dtaz)
		        # remove trailing |
		    destination = destination[:-1]

		    urlfeed += "https://maps.googleapis.com/maps/api/distancematrix/json?origins="+origin+"&destinations="+destination+ \
		            "&mode="+mode+"&departure_time="+dep_time+"&key="+secret_key+"&units=imperial"

		    # Fetch url and store
		    results[otaz] = json.loads(urllib2.urlopen(urlfeed).read())
		    results[otaz]['dtaz_list'] = taz_list


			# loop through each origin
		    for otaz, data in results.iteritems():
			    # loop through each destination
			    try:
				    for i in xrange(len(results[otaz]['rows'][0]['elements'])):
				    	dtaz = dtaz_list[i]
				        dist = results[otaz]['rows'][0]['elements'][i]['distance']['value']
				        time_ff = results[otaz]['rows'][0]['elements'][i]['duration']['value']    # free flow skim
				        time_cong = results[otaz]['rows'][0]['elements'][i]['duration_in_traffic']['value']    # congested

				        skims['auto_8_dist'][otaz-1][dtaz-1] = dist*0.000621371    # convert meters to miles
				        skims['auto_8_time_ff'][otaz-1][dtaz-1] = time_ff/60    # convert seconds to minutes
				        skims['auto_8_time_congested'][otaz-1][dtaz-1] = time_cong/60    # convert seconds to minutes
			    except:
					print 'no values returned'

	for skimname, data in skims.iteritems():
		try:
			pd.DataFrame(data).to_csv(skimname+'.csv')
		except:
			print 'error writing to file'

if __name__ == '__main__':
	main()