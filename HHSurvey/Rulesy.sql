/*	Load and clean raw hh survey data via rules -- a.k.a. "Rulesy"
	Export meant to feed Angela's interactive review tool

	Required custom regex functions coded here as RgxFind, RgxExtract, RgxReplace
	--see https://www.codeproject.com/Articles/19502/A-T-SQL-Regular-Expression-Library-for-SQL-Server

*/

USE Sandbox --start in a fresh db if there is danger of overwriting tables. Queries use the default user schema.
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- STEP 1. Load data from fixed format .csv files.  
	--	Due to field import difficulties, the trip table is imported in two steps--a loosely typed table, then queried into a tightly typed table.

		CREATE TABLE household (
			hhid int NOT NULL,
			sample_segment int NOT NULL,
			sample_county nvarchar(50) NOT NULL,
			cityofseattle int NOT NULL,
			cityofredmond int NOT NULL,
			psrc int NOT NULL,
			sample_haddress nvarchar(100) NOT NULL,
			sample_lat float NULL,
			sample_lng float NULL,
			reported_haddress nvarchar(100) NOT NULL,
			reported_haddress_flag int NOT NULL,
			reported_lat float NOT NULL,
			reported_lng float NOT NULL,
			final_haddress nvarchar(100) NOT NULL,
			final_tract int NOT NULL,
			final_bg float NOT NULL,
			final_block float NOT NULL,
			final_puma15 int NOT NULL,
			final_rgcnum int NOT NULL,
			final_uvnum int NOT NULL,
			hhgroup int NOT NULL,
			travelweek int NOT NULL,
			traveldate datetime2(7) NOT NULL,
			dayofweek int NOT NULL,
			hhsize int NOT NULL,
			vehicle_count int NOT NULL,
			numadults int NOT NULL,
			numchildren int NOT NULL,
			numworkers int NOT NULL,
			lifecycle int NOT NULL,
			hhincome_detailed int NOT NULL,
			hhincome_followup nvarchar(50) NULL,
			hhincome_broad int NOT NULL,
			car_share int NOT NULL,
			rent_own int NOT NULL,
			res_dur int NOT NULL,
			res_type int NOT NULL,
			res_months int NOT NULL,
			offpark int NOT NULL,
			offpark_cost int NULL,
			streetpark int NOT NULL,
			prev_home_wa int NULL,
			prev_home_address nvarchar(100) NULL,
			prev_home_lat float NULL,
			prev_home_lng float NULL,
			prev_home_notwa_notus nvarchar(50) NULL,
			prev_home_notwa_city nvarchar(50) NULL,
			prev_home_notwa_state nvarchar(50) NULL,
			prev_home_notwa_zip nvarchar(50) NULL,
			prev_rent_own int NULL,
			prev_res_type int NULL,
			res_factors_30min int NOT NULL,
			res_factors_afford int NOT NULL,
			res_factors_closefam int NOT NULL,
			res_factors_hhchange int NOT NULL,
			res_factors_hwy int NOT NULL,
			res_factors_school int NOT NULL,
			res_factors_space int NOT NULL,
			res_factors_transit int NOT NULL,
			res_factors_walk int NOT NULL,
			rmove_optin nvarchar(50) NULL,
			diary_incentive_type int NULL,
			extra_incentive int NOT NULL,
			call_center int NOT NULL,
			mobile_device int NOT NULL,
			contact_email int NULL,
			contact_phone int NULL,
			foreign_language int NOT NULL,
			google_translate int NOT NULL,
			recruit_start_pt nvarchar(50) NOT NULL,
			recruit_end_pt nvarchar(50) NOT NULL,
			recruit_duration_min int NOT NULL,
			numdayscomplete int NOT NULL,
			day1complete int NOT NULL,
			day2complete nvarchar(50) NULL,
			day3complete nvarchar(50) NULL,
			day4complete nvarchar(50) NULL,
			day5complete nvarchar(50) NULL,
			day6complete nvarchar(50) NULL,
			day7complete nvarchar(50) NULL,
			num_trips int NOT NULL
		)

		CREATE TABLE person (
			hhid int NOT NULL,
			personid int NOT NULL,
			pernum int NOT NULL,
			sample_segment int NOT NULL,
			hhgroup int NOT NULL,
			traveldate datetime2(7) NOT NULL,
			relationship int NOT NULL,
			proxy_parent nvarchar(50) NULL,
			proxy int NOT NULL,
			age int NOT NULL,
			gender int NOT NULL,
			employment int NULL,
			jobs_count int NULL,
			worker int NOT NULL,
			student int NULL,
			schooltype nvarchar(50) NULL,
			education int NULL,
			license int NULL,
			vehicleused nvarchar(50) NULL,
			smartphone_type int NULL,
			smartphone_age int NULL,
			smartphone_qualified int NOT NULL,
			race_afam int NULL,
			race_aiak int NULL,
			race_asian int NULL,
			race_hapi int NULL,
			race_hisp int NULL,
			race_white int NULL,
			race_other int NULL,
			race_noanswer int NULL,
			workplace int NULL,
			hours_work int NULL,
			commute_freq int NULL,
			commute_mode int NULL,
			commute_dur int NULL,
			telecommute_freq int NULL,
			wpktyp int NULL,
			workpass int NULL,
			workpass_cost nvarchar(50) NULL,
			workpass_cost_dk int NULL,
			work_name nvarchar(100) NULL,
			work_address nvarchar(100) NULL,
			work_county nvarchar(50) NULL,
			work_lat float NULL,
			work_lng float NULL,
			prev_work_wa int NULL,
			prev_work_name nvarchar(100) NULL,
			prev_work_address nvarchar(100) NULL,
			prev_work_county nvarchar(50) NULL,
			prev_work_lat nvarchar(50) NULL,
			prev_work_lng nvarchar(50) NULL,
			prev_work_notwa_city nvarchar(50) NULL,
			prev_work_notwa_state nvarchar(50) NULL,
			prev_work_notwa_zip nvarchar(50) NULL,
			prev_work_notwa_notus nvarchar(50) NULL,
			school_freq nvarchar(50) NULL,
			school_loc_name nvarchar(100) NULL,
			school_loc_address nvarchar(100) NULL,
			school_loc_county nvarchar(50) NULL,
			school_loc_lat nvarchar(50) NULL,
			school_loc_lng nvarchar(50) NULL,
			completed_pref_survey int NULL,
			mode_freq_1 int NULL,
			mode_freq_2 int NULL,
			mode_freq_3 int NULL,
			mode_freq_4 int NULL,
			mode_freq_5 int NULL,
			tran_pass_1 nvarchar(50) NULL,
			tran_pass_2 nvarchar(50) NULL,
			tran_pass_3 nvarchar(50) NULL,
			tran_pass_4 nvarchar(50) NULL,
			tran_pass_5 nvarchar(50) NULL,
			tran_pass_6 nvarchar(50) NULL,
			tran_pass_7 nvarchar(50) NULL,
			tran_pass_8 nvarchar(50) NULL,
			tran_pass_9 nvarchar(50) NULL,
			tran_pass_10 nvarchar(50) NULL,
			tran_pass_11 nvarchar(50) NULL,
			tran_pass_12 nvarchar(50) NULL,
			benefits_1 int NULL,
			benefits_2 int NULL,
			benefits_3 int NULL,
			benefits_4 int NULL,
			av_interest_1 int NULL,
			av_interest_2 int NULL,
			av_interest_3 int NULL,
			av_interest_4 int NULL,
			av_interest_5 int NULL,
			av_interest_6 int NULL,
			av_interest_7 int NULL,
			av_concern_1 int NULL,
			av_concern_2 int NULL,
			av_concern_3 int NULL,
			av_concern_4 int NULL,
			av_concern_5 int NULL,
			wbt_transitmore_1 int NULL,
			wbt_transitmore_2 int NULL,
			wbt_transitmore_3 int NULL,
			wbt_bikemore_1 int NULL,
			wbt_bikemore_2 int NULL,
			wbt_bikemore_3 int NULL,
			wbt_bikemore_4 int NULL,
			wbt_bikemore_5 int NULL,
			rmove_incentive nvarchar(50) NULL,
			call_center int NULL,
			mobile_device int NULL,
			num_trips int NOT NULL
		)

		CREATE TABLE trip (
			[hhid] [int] NOT NULL,
			[personid] [int] NOT NULL,
			[pernum] [int] NOT NULL,
			[tripid] bigint NOT NULL,
			[tripnum] [int] NOT NULL,
			[traveldate] date NOT NULL,
			[daynum] [int] NOT NULL,
			[dayofweek] [int] NOT NULL,
			[hhgroup] [int] NOT NULL,
			[copied_trip] [int] NULL,
			[completed_at] datetime2 NULL,
			[revised_at] datetime2 NULL,
			[revised_count] int NULL,
			[svy_complete] [int] NULL,
			[depart_time_mam] [int] NULL,
			[depart_time_hhmm] [nvarchar](255) NULL,
			[depart_time_timestamp] datetime2 NOT NULL,
			[arrival_time_mam] [int] NULL,
			[arrival_time_hhmm] [nvarchar](255) NULL,
			[arrival_time_timestamp] datetime2 NOT NULL,
			[origin_name] [nvarchar](255) NULL,
			[origin_address] [nvarchar](255) NULL,
			[origin_lat] [float] NOT NULL,
			[origin_lng] [float] NOT NULL,
			[dest_name] [nvarchar](255) NULL,
			[dest_address] [nvarchar](255) NULL,
			[dest_lat] [float] NOT NULL,
			[dest_lng] [float] NOT NULL,
			[trip_path_distance] [float] NULL,
			[google_duration] [int] NULL,
			[reported_duration] [int] NULL,
			[hhmember1] int NULL,
			[hhmember2] int NULL,
			[hhmember3] int NULL,
			[hhmember4] int NULL,
			[hhmember5] int NULL,
			[hhmember6] int NULL,
			[hhmember7] int NULL,
			[hhmember8] int NULL,
			[hhmember9] int NULL,
			[hhmember_none] int NULL,
			[travelers_hh] [int] NOT NULL,
			[travelers_nonhh] [int] NOT NULL,
			[travelers_total] [int] NOT NULL,
			[origin_purpose] [int] NULL,
			[o_purpose_other] [nvarchar](max) NULL,
			[dest_purpose] [int] NULL,
			[dest_purpose_comment] [nvarchar](max) NULL,
			[mode_1] smallint NOT NULL,
			[mode_2] smallint NULL,
			[mode_3] smallint NULL,
			[mode_4] smallint NULL,
			[driver] smallint NULL,
			[pool_start] smallint NULL,
			[change_vehicles] smallint NULL,
			[park_ride_area_start] smallint NULL,
			[park_ride_area_end] smallint NULL,
			[park_ride_lot_start] smallint NULL,
			[park_ride_lot_end] smallint NULL,
			[toll] smallint NULL,
			[toll_pay] decimal(8,2) NULL,
			[taxi_type] smallint NULL,
			[taxi_pay] decimal(8,2) NULL,
			[bus_type] smallint NULL,
			[bus_pay] decimal(8,2) NULL,
			[bus_cost_dk] smallint NULL,
			[ferry_type] smallint NULL,
			[ferry_pay] decimal(8,2) NULL,
			[ferry_cost_dk] smallint NULL,
			[rail_type] smallint NULL,
			[rail_pay] decimal(8,2) NULL,
			[rail_cost_dk] smallint NULL,
			[air_type] smallint NULL,
			[air_pay] decimal(8,2) NULL,
			[airfare_cost_dk] smallint NULL,
			[mode_acc] smallint NULL,
			[mode_egr] smallint NULL,
			[park] smallint NULL,
			[park_type] smallint NULL,
			[park_pay] decimal(8,2) NULL,
			[transit_system_1] smallint NULL,
			[transit_system_2] smallint NULL,
			[transit_system_3] smallint NULL,
			[transit_system_4] smallint NULL,
			[transit_system_5] smallint NULL,
			[transit_line_1] smallint NULL,
			[transit_line_2] smallint NULL,
			[transit_line_3] smallint NULL,
			[transit_line_4] smallint NULL,
			[transit_line_5] smallint NULL,
			[speed_mph] [float] NULL,
			[user_merged] bit NULL,
			[user_split] bit NULL,
			[analyst_merged] bit NULL,
			[analyst_split] bit NULL,
			[flag_teleport] bit NULL,
			[proxy_added_trip] bit NULL,
			[nonproxy_derived_trip] bit NULL,
			[child_trip_location_tripid] bit NULL
		)

		CREATE TABLE tripx_raw (
			[hhid] [int] NULL,
			[personid] [int] NULL,
			[pernum] [int] NULL,
			[tripid] [nvarchar](255) NULL,
			[tripnum] [int] NULL,
			[traveldate] [nvarchar](255) NULL,
			[daynum] [int] NULL,
			[dayofweek] [int] NULL,
			[hhgroup] [int] NULL,
			[copied_trip] [int] NULL,
			[completed_at] [nvarchar](255) NULL,
			[revised_at] [nvarchar](255) NULL,
			[revised_count] [nvarchar](255) NULL,
			[svy_complete] [int] NULL,
			[depart_time_mam] [int] NULL,
			[depart_time_hhmm] [nvarchar](255) NULL,
			[depart_time_timestamp] [nvarchar](255) NULL,
			[arrival_time_mam] [int] NULL,
			[arrival_time_hhmm] [nvarchar](255) NULL,
			[arrival_time_timestamp] [nvarchar](255) NULL,
			[origin_name] [nvarchar](255) NULL,
			[origin_address] [nvarchar](255) NULL,
			[origin_lat] [float] NULL,
			[origin_lng] [float] NULL,
			[dest_name] [nvarchar](255) NULL,
			[dest_address] [nvarchar](255) NULL,
			[dest_lat] [float] NULL,
			[dest_lng] [float] NULL,
			[trip_path_distance] [float] NULL,
			[google_duration] [int] NULL,
			[reported_duration] [int] NULL,
			[hhmember1] [nvarchar](255) NULL,
			[hhmember2] [nvarchar](255) NULL,
			[hhmember3] [nvarchar](255) NULL,
			[hhmember4] [nvarchar](255) NULL,
			[hhmember5] [nvarchar](255) NULL,
			[hhmember6] [nvarchar](255) NULL,
			[hhmember7] [nvarchar](255) NULL,
			[hhmember8] [nvarchar](255) NULL,
			[hhmember9] [nvarchar](255) NULL,
			[hhmember_none] [nvarchar](255) NULL,
			[travelers_hh] [int] NULL,
			[travelers_nonhh] [int] NULL,
			[travelers_total] [int] NULL,
			[origin_purpose] [int] NULL,
			[o_purpose_other] [nvarchar](max) NULL,
			[dest_purpose] [int] NULL,
			[dest_purpose_comment] [nvarchar](max) NULL,
			[mode_1] [int] NULL,
			[mode_2] [nvarchar](255) NULL,
			[mode_3] [nvarchar](255) NULL,
			[mode_4] [nvarchar](255) NULL,
			[driver] [nvarchar](255) NULL,
			[pool_start] [nvarchar](255) NULL,
			[change_vehicles] [nvarchar](255) NULL,
			[park_ride_area_start] [nvarchar](255) NULL,
			[park_ride_area_end] [nvarchar](255) NULL,
			[park_ride_lot_start] [nvarchar](255) NULL,
			[park_ride_lot_end] [nvarchar](255) NULL,
			[toll] [nvarchar](255) NULL,
			[toll_pay] [nvarchar](255) NULL,
			[taxi_type] [nvarchar](255) NULL,
			[taxi_pay] [nvarchar](255) NULL,
			[bus_type] [nvarchar](255) NULL,
			[bus_pay] [nvarchar](255) NULL,
			[bus_cost_dk] [nvarchar](255) NULL,
			[ferry_type] [nvarchar](255) NULL,
			[ferry_pay] [nvarchar](255) NULL,
			[ferry_cost_dk] [nvarchar](255) NULL,
			[rail_type] [nvarchar](255) NULL,
			[rail_pay] [nvarchar](255) NULL,
			[rail_cost_dk] [nvarchar](255) NULL,
			[air_type] [nvarchar](255) NULL,
			[air_pay] [nvarchar](255) NULL,
			[airfare_cost_dk] [nvarchar](255) NULL,
			[mode_acc] [nvarchar](255) NULL,
			[mode_egr] [nvarchar](255) NULL,
			[park] [nvarchar](255) NULL,
			[park_type] [nvarchar](255) NULL,
			[park_pay] [nvarchar](255) NULL,
			[transit_system_1] [nvarchar](255) NULL,
			[transit_system_2] [nvarchar](255) NULL,
			[transit_system_3] [nvarchar](255) NULL,
			[transit_system_4] [nvarchar](255) NULL,
			[transit_system_5] [nvarchar](255) NULL,
			[transit_line_1] [nvarchar](255) NULL,
			[transit_line_2] [nvarchar](255) NULL,
			[transit_line_3] [nvarchar](255) NULL,
			[transit_line_4] [nvarchar](255) NULL,
			[transit_line_5] [nvarchar](255) NULL,
			[speed_mph] [float] NULL,
			[user_merged] [nvarchar](255) NULL,
			[user_split] [nvarchar](255) NULL,
			[analyst_merged] [nvarchar](255) NULL,
			[analyst_split] [nvarchar](255) NULL,
			[flag_teleport] [nvarchar](255) NULL,
			[proxy_added_trip] [nvarchar](255) NULL,
			[nonproxy_derived_trip] [nvarchar](255) NULL,
			[child_trip_location_tripid] [nvarchar](255) NULL
		)

		GO

		BULK INSERT household	FROM '\\aws-prod-file01\SQL2016\DSADEV\1-Household.csv'	WITH (FIELDTERMINATOR=',', FIRSTROW = 2);
		BULK INSERT person		FROM '\\aws-prod-file01\SQL2016\DSADEV\2-Person.csv'	WITH (FIELDTERMINATOR=',', FIRSTROW = 2);
		BULK INSERT tripx_raw	FROM '\\aws-prod-file01\SQL2016\DSADEV\5-Trip.csv'		WITH (FIELDTERMINATOR=',', FIRSTROW = 2);

		INSERT INTO trip(
			 [hhid]
			,[personid]
			,[pernum]
			,[tripid]
			,[tripnum]
			,[traveldate]
			,[daynum]
			,[dayofweek]
			,[hhgroup]
			,[copied_trip]
			,[completed_at]
			,[revised_at]
			,[revised_count]
			,[svy_complete]
			,[depart_time_mam]
			,[depart_time_hhmm]
			,[depart_time_timestamp]
			,[arrival_time_mam]
			,[arrival_time_hhmm]
			,[arrival_time_timestamp]
			,[origin_name]
			,[origin_address]
			,[origin_lat]
			,[origin_lng]
			,[dest_name]
			,[dest_address]
			,[dest_lat]
			,[dest_lng]
			,[trip_path_distance]
			,[google_duration]
			,[reported_duration]
			,[hhmember1]
			,[hhmember2]
			,[hhmember3]
			,[hhmember4]
			,[hhmember5]
			,[hhmember6]
			,[hhmember7]
			,[hhmember8]
			,[hhmember9]
			,[hhmember_none]
			,[travelers_hh]
			,[travelers_nonhh]
			,[travelers_total]
			,[origin_purpose]
			,[o_purpose_other]
			,[dest_purpose]
			,[dest_purpose_comment]
			,[mode_1]
			,[mode_2]
			,[mode_3]
			,[mode_4]
			,[driver]
			,[pool_start]
			,[change_vehicles]
			,[park_ride_area_start]
			,[park_ride_area_end]
			,[park_ride_lot_start]
			,[park_ride_lot_end]
			,[toll]
			,[toll_pay]
			,[taxi_type]
			,[taxi_pay]
			,[bus_type]
			,[bus_pay]
			,[bus_cost_dk]
			,[ferry_type]
			,[ferry_pay]
			,[ferry_cost_dk]
			,[rail_type]
			,[rail_pay]
			,[rail_cost_dk]
			,[air_type]
			,[air_pay]
			,[airfare_cost_dk]
			,[mode_acc]
			,[mode_egr]
			,[park]
			,[park_type]
			,[park_pay]
			,[transit_system_1]
			,[transit_system_2]
			,[transit_system_3]
			,[transit_system_4]
			,[transit_system_5]
			,[transit_line_1]
			,[transit_line_2]
			,[transit_line_3]
			,[transit_line_4]
			,[transit_line_5]
			,[speed_mph]
			,[user_merged]
			,[user_split]
			,[analyst_merged]
			,[analyst_split]
			,[flag_teleport]
			,[proxy_added_trip]
			,[nonproxy_derived_trip]
			,[child_trip_location_tripid]
			)
		SELECT 
			[hhid]
			,[personid]
			,[pernum]
			,[tripid]
			,[tripnum]
			,convert(date, [traveldate], 121)
			,[daynum]
			,[dayofweek]
			,[hhgroup]
			,[copied_trip]
			,convert(datetime2, [completed_at], 121)
			,convert(datetime2, [revised_at], 121)
			,cast([revised_count] AS int)
			,[svy_complete]
			,[depart_time_mam]
			,[depart_time_hhmm]
			,convert(datetime2, depart_time_timestamp, 121)
			,[arrival_time_mam]
			,[arrival_time_hhmm]
			,convert(datetime2, arrival_time_timestamp, 121)
			,[origin_name]
			,[origin_address]
			,[origin_lat]
			,[origin_lng]
			,[dest_name]
			,[dest_address]
			,[dest_lat]
			,[dest_lng]
			,[trip_path_distance]
			,[google_duration]
			,[reported_duration]
			,[hhmember1]
			,cast([hhmember2] as int)
			,cast([hhmember3] as int)
			,cast([hhmember4] as int)
			,cast([hhmember5] as int)
			,cast([hhmember6] as int)
			,cast([hhmember7] as int)
			,cast([hhmember8] as int)
			,cast([hhmember9] as int)
			,cast([hhmember_none] as int)
			,[travelers_hh]
			,[travelers_nonhh]
			,[travelers_total]
			,[origin_purpose]
			,[o_purpose_other]
			,[dest_purpose]
			,[dest_purpose_comment]
			,cast([mode_1] as smallint)
			,cast([mode_2] as smallint)
			,cast([mode_3] as smallint)
			,cast([mode_4] as smallint)
			,cast([driver] as smallint)
			,cast([pool_start] as smallint)
			,cast([change_vehicles] as smallint)
			,cast([park_ride_area_start] as smallint)
			,cast([park_ride_area_end] as smallint)
			,cast([park_ride_lot_start] as smallint)
			,cast([park_ride_lot_end] as smallint)
			,cast([toll] as smallint)
			,cast([toll_pay] as decimal(8,2))
			,cast([taxi_type] as smallint)
			,cast([taxi_pay] as decimal(8,2))
			,cast([bus_type] as smallint)
			,cast([bus_pay] as decimal(8,2))
			,cast([bus_cost_dk] as smallint)
			,cast([ferry_type] as smallint)
			,cast([ferry_pay] as decimal(8,2))
			,cast([ferry_cost_dk] as smallint)
			,cast([rail_type] as smallint)
			,cast([rail_pay] as decimal(8,2))
			,cast([rail_cost_dk] as smallint)
			,cast([air_type] as smallint)
			,cast([air_pay] as decimal(8,2))
			,cast([airfare_cost_dk] as smallint)
			,cast([mode_acc] as smallint)
			,cast([mode_egr] as smallint)
			,cast([park] as smallint)
			,cast([park_type] as smallint)
			,cast([park_pay] as decimal(8,2))
			,cast([transit_system_1] as smallint)
			,cast([transit_system_2] as smallint)
			,cast([transit_system_3] as smallint)
			,cast([transit_system_4] as smallint)
			,cast([transit_system_5] as smallint)
			,cast([transit_line_1] as smallint)
			,cast([transit_line_2] as smallint)
			,cast([transit_line_3] as smallint)
			,cast([transit_line_4] as smallint)
			,cast([transit_line_5] as smallint)
			,[speed_mph]
			,cast([user_merged] as bit)
			,cast([user_split] as bit)
			,cast([analyst_merged] as bit)
			,cast([analyst_split] as bit)
			,cast([flag_teleport] as bit)
			,cast((CASE [proxy_added_trip] when 'true' then 1 when 'false' then 0 ELSE NULL END) as bit)
			,cast([nonproxy_derived_trip] as bit)
			,cast([child_trip_location_tripid] as bit)
			FROM tripx_raw;
		GO
		DROP TABLE tripx_raw;
		GO

-- Step 2.  Fill missing fields & parse address fields

		ALTER TABLE trip --additional destination address fields
			ADD geom GEOMETRY NULL,
				recid int identity(1,1) NOT NULL PRIMARY KEY,
				dest_county	varchar(3) NULL,
				dest_city	varchar(25) NULL,
				dest_zip	varchar(5) NULL,
				dest_is_home bit NULL, 
				dest_is_work bit NULL,
				last_trip_per_person bit NULL;
		GO
		CREATE INDEX hhperson_idx ON trip (hhid ASC, personid ASC);
		CREATE INDEX tripnum_idx ON trip (tripnum ASC);
		UPDATE trip	SET geom = geometry::STPointFromText('POINT(' + CAST(dest_lat AS VARCHAR(20)) + ' ' + CAST(dest_lng AS VARCHAR(20)) + ')', 4326);
		GO
		CREATE SPATIAL INDEX geom_idx ON trip(geom)
			USING GEOMETRY_AUTO_GRID
			WITH (BOUNDING_BOX= (xmin=-20, ymin=-157.858, xmax=57.803, ymax=124.343));
		GO	

	--address parsing
		UPDATE trip	SET dest_zip 	= SUBSTRING(dbo.RgxExtract(dest_address, 'WA (\d{5}), USA', 0),4,5);
		UPDATE trip	SET dest_city 	= LTRIM(RTRIM(SUBSTRING(dbo.RgxExtract(dest_address, '[A-Za-z ]+, WA ', 0),0,PATINDEX('%,%',dbo.RgxExtract(dest_address, '[A-Za-z ]+, WA ', 0)))));
		UPDATE trip SET dest_county = zipwgs.county FROM trip JOIN dbo.zipcode_wgs AS zipwgs ON trip.dest_zip=zipwgs.zipcode;
		GO

	/*	UPDATE trip --fill missing zipcode THIS ISN'T UPDATING ANY FIELDS--DESPITE BEING THE SAME EPSG IT ISN'T EVALUATING RIGHT YET.
			SET trip.dest_zip = zipwgs.zipcode
			FROM trip join dbo.zipcode_wgs as zipwgs ON [trip].[geom].STIntersects([zipwgs].[geom])=1
			WHERE trip.dest_zip IS NULL;

		UPDATE trip --fill missing city --NOT SELECTED YET
			SET trip.dest_city = [ENTER CITY GEOGRAPHY HERE].City
			FROM trip join [ENTER CITY GEOGRAPHY HERE] ON [trip].[geom].STIntersects([ENTER CITY GEOGRAPHY HERE].[geom])=1
			WHERE trip.dest_city IS NULL;

		UPDATE trip --fill missing county--NOT SELECTED YET
			SET trip.dest_county = zipwgs.county
			FROM trip join dbo.zipcode_wgs as zipwgs ON [trip].[geom].STIntersects([zipwgs].[geom])=1
			WHERE trip.dest_county IS NULL;

	*** Create geographic check where assigned zip/county doesn't match the x,y.		

	*/

	--Create standard fields for home and work trips
		UPDATE trip
			SET dest_is_home = 1
			WHERE dest_name = 'HOME' 
				OR(
					(dbo.RgxFind([dest_name],' home',1) = 1 
					OR dbo.RgxFind([dest_name],'^h[om]?$',1) = 1) 
					and dbo.RgxFind([dest_name],'(their|her|s|from|near|nursing|friend) home',1) = 0
				)
				OR(dest_purpose = 1 AND dest_name IS NULL);

		UPDATE trip
			SET dest_is_work = 1
			WHERE dest_name = 'WORK' 
				OR((dbo.RgxFind([dest_name],' work',1) = 1 
					OR dbo.RgxFind([dest_name],'^w[or ]?$',1) = 1))
				OR(dest_purpose = 10 AND dest_name IS NULL);

	--Change 'Other' trip purpose when purpose is provided
		UPDATE trip 	SET dest_purpose = 1	WHERE dest_purpose = 97 AND dest_is_home = 1;
		UPDATE trip 	SET dest_purpose = 10	WHERE dest_purpose = 97 AND dest_is_work = 1;
		UPDATE trip		SET dest_purpose = 33	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'(bank|gas|post ?office)',1) = 1;		
		UPDATE trip		SET dest_purpose = 34	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'(doctor|dentist|hospital)',1) = 1;	
		UPDATE trip		SET dest_purpose = 50	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'(coffee|cafe|starbucks|lunch)',1) = 1;		
		UPDATE trip		SET dest_purpose = 51	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'dog',1) = 1 AND dbo.RgxFind(dest_name,'(walk|park)',1) = 1;
		UPDATE trip		SET dest_purpose = 51	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'park',1) = 1 AND dbo.RgxFind(dest_name,'(parking|ride)',1) = 0;
		UPDATE trip		SET dest_purpose = 54	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'church',1) = 1; 
GO
-- Step 3. Flag inconsistencies

		CREATE TABLE trip_error_flags(
			hhid int not NULL,
			personid int not NULL,
			tripnum int not null,
			error_flag varchar(100),
			rulesy_fixed varchar(10) default 'no'
			PRIMARY KEY (hhid, personid, tripnum, error_flag)
		);
		GO

	-- Data Integrity Checks

		INSERT INTO trip_error_flags (hhid, personid, tripnum, error_flag)
			SELECT trip.hhid, trip.personid, trip.tripnum, 'non-consecutive trip numbering' as error_flag
				FROM trip AS t1 
					JOIN trip AS t2 ON t1.personid=t2.personid
				WHERE ((t1.tripid - t2.tripid) / 
					(CASE WHEN datediff(minute, t1.depart_time_timestamp, t2.arrival_time_timestamp) = 0 THEN 1 
					ELSE datediff(minute, t1.depart_time_timestamp, t2.arrival_time_timestamp) END)) < 0;



	-- Logic Checks

		INSERT INTO trip_error_flags (hhid, personid, tripnum, error_flag)
			SELECT trip.hhid, trip.personid, trip.tripnum, 'speed unreasonably high' as error_flag
				FROM trip 									
				WHERE 	(mode_1 = 1 AND speed_mph > 20)
					OR 	(mode_1 = 2 AND speed_mph > 40)
					OR 	((mode_1 between 3 and 52 AND mode_1 <> 31) AND speed_mph > 85)
					OR 	(speed_mph > 600);

		INSERT INTO trip_error_flags (hhid, personid, tripnum, error_flag)
			SELECT hhid, personid, tripnum, 'non-home trip purpose, destination home' as error_flag
				FROM trip
				WHERE dest_purpose <> 1 AND dest_is_home = 1;

		INSERT INTO trip_error_flags (hhid, personid, tripnum, error_flag)
			SELECT hhid, personid, tripnum, 'home trip purpose, destination elsewhere' as error_flag
				FROM trip
				WHERE dest_purpose = 1 AND dest_is_home <> 1;

		INSERT INTO trip_error_flags (hhid, personid, tripnum, error_flag)
			SELECT trip.hhid, trip.personid, trip.tripnum, 'suspected drop-off or pick-up coded as school trip' as error_flag
				FROM trip 
					JOIN person ON trip.hhid=person.hhid AND trip.personid=person.personid 
					JOIN trip as next_trip ON trip.hhid=next_trip.hhid AND trip.personid=next_trip.personid
				WHERE trip.dest_purpose = 6 
					AND trip.tripnum + 1 = next_trip.tripnum
					AND ((person.student NOT IN(2,3,4))
						OR (DATEDIFF(minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 20));

		INSERT INTO trip_error_flags (hhid, personid, tripnum, error_flag)
			SELECT trip.hhid, trip.personid, trip.tripnum, 'unlicensed driver' as error_flag
				FROM trip JOIN person AS p ON p.personid=t.personid
				WHERE p.license = 3 AND t.driver=1;

		INSERT INTO trip_error_flags (hhid, personid, tripnum, error_flag)
			SELECT trip.hhid, trip.personid, trip.tripnum, 'non-worker reporting work trip' as error_flag
				FROM trip JOIN person AS p ON p.personid=t.personid
				WHERE p.worker = 0 AND trip.dest_purpose in(10,11,14);

GO
-- Step 4. Correct for known error patterns

	--a. Inconsistent coding of 'return home' as trip purpose
		UPDATE t1 --marks subsequent correction
			SET t1.rulesy_fixed ='yes'
			FROM trip_error_flags as t1 join trip on t1.hhid=trip.hhid AND t1.personid=trip.personid AND t1.tripnum=trip.tripnum
				JOIN trip AS prev_trip on trip.hhid=prev_trip.hhid AND trip.personid=prev_trip.personid
			WHERE trip.dest_purpose <> 1 and trip.dest_is_home = 1 AND t1.error_flag = 'non-home trip purpose, destination home'
				AND trip.tripnum - 1 = prev_trip.tripnum AND trip.dest_purpose=prev_trip.dest_purpose;

		UPDATE trip --revises purpose field for return portion of a single stop loop trip 
			SET trip.dest_purpose = 1 
			FROM trip 
				JOIN trip AS prev_trip on trip.hhid=prev_trip.hhid AND trip.personid=prev_trip.personid
			WHERE trip.dest_purpose <> 1 and trip.dest_is_home = 1
				AND trip.tripnum - 1 = prev_trip.tripnum AND trip.dest_purpose=prev_trip.dest_purpose;
GO
	--b. Drop-off and pick-up trips coded incorrectly as school trips (or other codes)
		UPDATE t1 --marks subsequent correction
			SET t1.rulesy_fixed ='yes'
			FROM trip_error_flags as t1 
				JOIN trip ON t1.hhid=trip.hhid AND t1.personid=trip.personid AND t1.tripnum=trip.tripnum 
				JOIN person ON trip.hhid=person.hhid AND trip.personid=person.personid 
				JOIN trip as next_trip ON trip.hhid=next_trip.hhid AND trip.personid=next_trip.personid
			WHERE trip.dest_purpose = 6 AND t1.error_flag = 'suspected drop-off or pick-up coded as school trip'
				AND trip.tripnum + 1 = next_trip.tripnum
				AND trip.travelers_total <> next_trip.travelers_total
				AND DATEDIFF(minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 40;

		UPDATE trip --changes purpose code from school to pickup/dropoff when passenger number changes and duration is under 40 minutes
			SET trip.dest_purpose = 9
			FROM trip 
				JOIN person ON trip.hhid=person.hhid AND trip.personid=person.personid 
				JOIN trip as next_trip ON trip.hhid=next_trip.hhid AND trip.personid=next_trip.personid
			WHERE trip.dest_purpose = 6
				AND trip.tripnum + 1 = next_trip.tripnum
				AND trip.travelers_total <> next_trip.travelers_total
				AND DATEDIFF(minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 40;
		
		UPDATE trip --changes code from everything else to pickup/dropoff when passenger number changes, duration is under 40 minutes, and pickup/dropoff mentioned in dest_name
			SET trip.dest_purpose = 9
			FROM trip 
				JOIN person ON trip.hhid=person.hhid AND trip.personid=person.personid 
				JOIN trip as next_trip ON trip.hhid=next_trip.hhid AND trip.personid=next_trip.personid							
			WHERE trip.tripnum + 1 = next_trip.tripnum
				AND dbo.RgxFind([trip].[dest_name],'(drop|pick)',1) = 1
				AND trip.dest_purpose <> 9
				AND trip.travelers_total <> next_trip.travelers_total
				AND DATEDIFF(minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 40;

		UPDATE t1 --marks subsequent correction
			SET t1.rulesy_fixed ='yes'
			FROM trip_error_flags as t1 
				JOIN trip ON t1.hhid=trip.hhid AND t1.personid=trip.personid AND t1.tripnum=trip.tripnum 
				JOIN person ON trip.hhid=person.hhid AND trip.personid=person.personid 
				JOIN trip as next_trip ON trip.hhid=next_trip.hhid AND trip.personid=next_trip.personid
			WHERE trip.dest_purpose = 6
				AND trip.tripnum + 1 = next_trip.tripnum
				AND trip.travelers_total <> next_trip.travelers_total
				AND dbo.RgxFind(trip.dest_name,'(school|care)',1) = 1
				AND DATEDIFF(minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) Between 40 and 240;	

		UPDATE trip --changes code to 'family activity' when passenger number changes and duration is from 40mins to 4hrs
			SET trip.dest_purpose = 56
			FROM trip 
				JOIN person ON trip.hhid=person.hhid AND trip.personid=person.personid 
				JOIN trip as next_trip ON trip.hhid=next_trip.hhid AND trip.personid=next_trip.personid
			WHERE trip.dest_purpose = 6
				AND trip.tripnum + 1 = next_trip.tripnum
				AND trip.travelers_total <> next_trip.travelers_total
				AND dbo.RgxFind(trip.dest_name,'(school|care)',1) = 1
				AND DATEDIFF(minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) Between 40 and 240;				
GO
