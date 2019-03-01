/*	Load and clean raw hh survey data via rules -- a.k.a. "Rulesy"
	Export meant to feed Angela's interactive review tool

	Required CLR regex functions coded here as RgxFind, RgxExtract, RgxReplace
	--see https://www.codeproject.com/Articles/19502/A-T-SQL-Regular-Expression-Library-for-SQL-Server
	Required CLR string_agg function coded here as 


*/

USE Sandbox --start in a fresh db if there is danger of overwriting tables. Queries use the default user schema.
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP SEQUENCE IF EXISTS tripid_increment, workhorse_sequence;
DROP TABLE IF EXISTS household, person, tripx_raw, trip, transitmodes, automodes, pedmodes, walkmodes, nontransitmodes, trip_ingredients;

CREATE TABLE transitmodes (mode_id int PRIMARY KEY NOT NULL);
CREATE TABLE automodes (mode_id int PRIMARY KEY NOT NULL);
CREATE TABLE pedmodes (mode_id int PRIMARY KEY NOT NULL);
CREATE TABLE nontransitmodes (mode_id int PRIMARY KEY NOT NULL);
GO
INSERT INTO transitmodes(mode_id) VALUES (23),(24),(26),(27),(28),(31),(32),(41),(42),(52);
INSERT INTO automodes(mode_id) values (3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(16),(17),(18),(21),(22),(33),(34),(36),(37),(47);
INSERT INTO pedmodes(mode_id) values(1),(2);
INSERT INTO nontransitmodes(mode_id) SELECT mode_id FROM pedmodes UNION SELECT mode_id FROM automodes;	

/* STEP 1. 	Load data from fixed format .csv files.  */
	--	Due to field import difficulties, the trip table is imported in two steps--a loosely typed table, then queried using CAST into a tightly typed table.

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

		CREATE TABLE hhts_tripx (
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

		CREATE TABLE trip (
			[hhid] [int] NOT NULL,
			[personid] [int] NOT NULL,
			[pernum] [int] NULL,
			[tripid] bigint NOT NULL,
			[tripnum] [int] NOT NULL DEFAULT 0,
			[traveldate] date NULL,
			[daynum] [int] NULL,
			[dayofweek] [int] NULL,
			[hhgroup] [int] NULL,
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
			FROM dbo.hhts_tripx
			ORDER BY tripid;
		GO

		ALTER TABLE trip --additional destination address fields
			ADD origin_geom 	GEOMETRY NULL,
				dest_geom 		GEOMETRY NULL,
				dest_county		varchar(3) NULL,
				dest_city		varchar(25) NULL,
				dest_zip		varchar(5) NULL,
				dest_is_home	bit NULL, 
				dest_is_work 	bit NULL,
				modes 			nvarchar(MAX),
				transit_systems nvarchar(MAX),
				transit_lines 	nvarchar(MAX),
				psrc_inserted 	bit NULL,
				revision_code 	nvarchar(MAX) NULL;
		GO
						
		/*ALTER TABLE household -- add home geometry
			ADD home_geom GEOMETRY NULL;

		ALTER TABLE person --add work geometry	
			ADD work_geom GEOMETRY NULL;*/
		
		GO
		
		UPDATE trip	SET dest_geom = 	geometry::STPointFromText('POINT(' + CAST(dest_lng 	 AS VARCHAR(20)) + ' ' + CAST(dest_lat 	 AS VARCHAR(20)) + ')', 4326),
						origin_geom = 	geometry::STPointFromText('POINT(' + CAST(origin_lng AS VARCHAR(20)) + ' ' + CAST(origin_lat AS VARCHAR(20)) + ')', 4326);
		ALTER TABLE trip ADD CONSTRAINT PK_trip PRIMARY KEY CLUSTERED (tripid) WITH FILLFACTOR=80;
		DROP SEQUENCE IF EXISTS tripid_increment;
		CREATE SEQUENCE tripid_increment AS int START WITH 1 INCREMENT BY 1 NO CYCLE;  -- Create sequence object to generate tripid for new records & add indices
	/*	DROP SEQUENCE IF EXISTS workhorse_sequence;
		CREATE SEQUENCE workhorse_sequence AS int START WITH 1 INCREMENT BY 1 NO CYCLE; -- Create second sequence object for linking purposes; doesn't appear to be necessary */
		ALTER TABLE trip ADD CONSTRAINT tripid_autonumber DEFAULT NEXT VALUE FOR tripid_increment FOR tripid;
		CREATE INDEX person_idx ON trip (personid ASC);
		CREATE INDEX tripnum_idx ON trip (tripnum ASC);
		CREATE INDEX dest_purpose_idx ON trip (dest_purpose);
		CREATE INDEX travelers_total_idx ON trip(travelers_total);
		
		/*UPDATE household SET home_geom = geometry::STPointFromText('POINT(' + CAST(reported_lng AS VARCHAR(20)) + ' ' + CAST(reported_lat AS VARCHAR(20)) + ')', 4326);
		UPDATE person SET work_geom = geometry::STPointFromText('POINT(' + CAST(work_lng AS VARCHAR(20)) + ' ' + CAST(work_lat AS VARCHAR(20)) + ')', 4326);*/

		GO
	 
		CREATE SPATIAL INDEX dest_geom_idx ON trip(dest_geom)
			USING GEOMETRY_AUTO_GRID
			WITH (BOUNDING_BOX= (xmin=-157.858, ymin=-20, xmax=124.343, ymax=57.803));
	

	-- Tripnum must be sequential or later steps will fail. Create procedure and employ where required.
		DROP PROCEDURE IF EXISTS tripnum_update;
		GO
		CREATE PROCEDURE tripnum_update AS
		BEGIN
		WITH tripnum_rev(tripid, personid, tripnum) AS
			(SELECT tripid, personid, ROW_NUMBER() OVER(PARTITION BY personid ORDER BY depart_time_timestamp ASC) AS tripnum FROM trip)
		UPDATE t
			SET t.tripnum = tripnum_rev.tripnum
			FROM trip AS t JOIN tripnum_rev ON t.tripid=tripnum_rev.tripid AND t.personid = tripnum_rev.personid;
		END
		GO
		EXECUTE tripnum_update;

/* STEP 2.  Parse/Fill missing address fields */

	--address parsing
		UPDATE trip	SET dest_zip 	= SUBSTRING(dbo.RgxExtract(dest_address, 'WA (\d{5}), USA', 0),4,5);
		UPDATE trip	SET dest_city 	= LTRIM(RTRIM(SUBSTRING(dbo.RgxExtract(dest_address, '[A-Za-z ]+, WA ', 0),0,PATINDEX('%,%',dbo.RgxExtract(dest_address, '[A-Za-z ]+, WA ', 0)))));
		UPDATE trip SET dest_county = zipwgs.county FROM trip JOIN dbo.zipcode_wgs AS zipwgs ON trip.dest_zip=zipwgs.zipcode;
		GO

		UPDATE trip --fill missing zipcode
			SET trip.dest_zip = zipwgs.zipcode
			FROM trip join dbo.zipcode_wgs as zipwgs ON trip.dest_geom.STIntersects(zipwgs.geom)=1
			WHERE trip.dest_zip IS NULL;

	/*	UPDATE trip --fill missing city --NOT YET AVAILABLE
			SET trip.dest_city = [ENTER CITY GEOGRAPHY HERE].City
			FROM trip join [ENTER CITY GEOGRAPHY HERE] ON trip.dest_geom.STIntersects([ENTER CITY GEOGRAPHY HERE].geom)=1
			WHERE trip.dest_city IS NULL;
	*/
		UPDATE trip --fill missing county
			SET trip.dest_county = zipwgs.county
			FROM trip join dbo.zipcode_wgs as zipwgs ON trip.dest_geom.STIntersects(zipwgs.geom)=1
			WHERE trip.dest_county IS NULL;

	-- -- [Create geographic check where assigned zip/county doesn't match the x,y.]		

/* STEP 3.  Corrections to purpose, etc fields -- utilized in subsequent steps */
	
		DROP PROCEDURE IF EXISTS dest_purpose_updates;
		GO
		CREATE PROCEDURE dest_purpose_updates AS 
		BEGIN
			
			UPDATE trip --Classify home destinations
				SET dest_is_home = 1
				FROM trip JOIN household ON trip.hhid = household.hhid
				WHERE (dest_name = 'HOME' 
					OR(
						(dbo.RgxFind([dest_name],' home',1) = 1 
						OR dbo.RgxFind([dest_name],'^h[om]?$',1) = 1) 
						and dbo.RgxFind([dest_name],'(their|her|s|from|near|nursing|friend) home',1) = 0
					)
					OR(dest_purpose = 1 AND dest_name IS NULL))
					AND trip.dest_geom.STIntersects(household.home_geom.STBuffer(0.0009))=1;

			UPDATE trip --Classify primary work destinations
				SET dest_is_work = 1
				FROM trip JOIN person ON trip.personid  =person.personid
				WHERE (dest_name = 'WORK' 
					OR((dbo.RgxFind([dest_name],' work',1) = 1 
						OR dbo.RgxFind([dest_name],'^w[or ]?$',1) = 1))
					OR(dest_purpose = 10 AND dest_name IS NULL))
					AND trip.dest_geom.STIntersects(person.work_geom.STBuffer(0.0009))=1;
		
			
			UPDATE trip --revises purpose field for return portion of a single stop loop trip 
				SET trip.dest_purpose = (CASE WHEN trip.dest_is_home = 1 THEN 1 WHEN trip.dest_is_work = 1 THEN 10 ELSE trip.dest_purpose END), trip.revision_code = CONCAT(trip.revision_code,'1,')
				FROM trip 
					JOIN trip AS prev_trip on trip.personid=prev_trip.personid AND trip.tripnum - 1 = prev_trip.tripnum
				WHERE (trip.dest_purpose <> 1 and trip.dest_is_home = 1) OR (trip.dest_purpose <> 10 and trip.dest_is_work = 1)
					AND trip.dest_purpose=prev_trip.dest_purpose;

			UPDATE trip --Change code to pickup/dropoff when passenger number changes, duration is under 30 minutes, and pickup/dropoff mentioned in dest_name
				SET trip.dest_purpose = 9, trip.revision_code = CONCAT(trip.revision_code,'2,')
				FROM trip 
					JOIN person ON trip.personid=person.personid 
					JOIN trip as next_trip ON trip.personid=next_trip.personid	AND trip.tripnum + 1 = next_trip.tripnum						
				WHERE dbo.RgxFind([trip].[dest_name],'(drop|pick)',1) = 1
					AND trip.dest_purpose <> 9
					AND trip.travelers_total <> next_trip.travelers_total
					AND DATEDIFF(minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 30;

			UPDATE trip --changes purpose code from school to pickup/dropoff when passenger number changes and duration is under 30 minutes
				SET trip.dest_purpose = 9, trip.revision_code = CONCAT(trip.revision_code,'2,')
				FROM trip 
					JOIN person ON trip.personid=person.personid 
					JOIN trip as next_trip ON trip.hhid=next_trip.hhid AND trip.personid=next_trip.personid AND trip.tripnum + 1 = next_trip.tripnum
				WHERE trip.dest_purpose = 6
					AND trip.travelers_total <> next_trip.travelers_total
					AND DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 40;
			
			UPDATE trip --changes code to 'family activity' when passenger number changes and duration is from 30mins to 4hrs
				SET trip.dest_purpose = 56, trip.revision_code = CONCAT(trip.revision_code,'3,')
				FROM trip 
					JOIN person ON trip.personid=person.personid 
					JOIN trip as next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 = next_trip.tripnum
				WHERE trip.dest_purpose = 6
					AND trip.travelers_total <> next_trip.travelers_total
					AND dbo.RgxFind(trip.dest_name,'(school|care)',1) = 1
					AND DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) Between 30 and 240;

		--Change 'Other' trip purpose when purpose is given in destination
			UPDATE trip 	SET dest_purpose = 1,  revision_code = CONCAT(revision_code,'4,')	WHERE dest_purpose = 97 AND dest_is_home = 1;
			UPDATE trip 	SET dest_purpose = 10, revision_code = CONCAT(revision_code,'4,')	WHERE dest_purpose = 97 AND dest_is_work = 1;
			UPDATE trip		SET dest_purpose = 33, revision_code = CONCAT(revision_code,'4,')	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'(bank|gas|post ?office)',1) = 1;		
			UPDATE trip		SET dest_purpose = 34, revision_code = CONCAT(revision_code,'4,')	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'(doctor|dentist|hospital)',1) = 1;	
			UPDATE trip		SET dest_purpose = 50, revision_code = CONCAT(revision_code,'4,')	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'(coffee|cafe|starbucks|lunch)',1) = 1;		
			UPDATE trip		SET dest_purpose = 51, revision_code = CONCAT(revision_code,'4,')	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'dog',1) = 1 AND dbo.RgxFind(dest_name,'(walk|park)',1) = 1;
			UPDATE trip		SET dest_purpose = 51, revision_code = CONCAT(revision_code,'4,')	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'park',1) = 1 AND dbo.RgxFind(dest_name,'(parking|ride)',1) = 0;
			UPDATE trip		SET dest_purpose = 54, revision_code = CONCAT(revision_code,'4,')	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'church',1) = 1; 
		END
		GO
		EXECUTE dest_purpose_updates;

/* STEP 4.	Trip linking */

		/*	These are MSSQL17 commands for the UPDATE query below--faster and clearer, once we upgrade.
		UPDATE trip
			SET modes 			= CONCAT_WS(',',ti_wndw.transit_system_1, ti_wndw.transit_system_2, ti_wndw.transit_system_3, ti_wndw.transit_system_4, ti_wndw.transit_system_5),
				transit_systems = CONCAT_WS(',',ti_wndw.transit_system_1, ti_wndw.transit_system_2, ti_wndw.transit_system_3, ti_wndw.transit_system_4, ti_wndw.transit_system_5),
				transit_lines 	= CONCAT_WS(',',ti_wndw.transit_line_1, ti_wndw.transit_line_2, ti_wndw.transit_line_3, ti_wndw.transit_line_4, ti_wndw.transit_line_5)
		*/
		UPDATE trip
				SET modes = STUFF(	COALESCE(',' + CAST(mode_acc AS nvarchar), '') +
									COALESCE(',' + CAST(mode_1 	 AS nvarchar), '') + 
									COALESCE(',' + CAST(mode_2 	 AS nvarchar), '') + 
									COALESCE(',' + CAST(mode_3 	 AS nvarchar), '') + 
									COALESCE(',' + CAST(mode_4 	 AS nvarchar), '') + 
									COALESCE(',' + CAST(mode_egr AS nvarchar), ''), 1, 1, ''),
		  transit_systems = STUFF(	COALESCE(',' + CAST(transit_system_1 AS nvarchar), '') + 
									COALESCE(',' + CAST(transit_system_2 AS nvarchar), '') + 
									COALESCE(',' + CAST(transit_system_3 AS nvarchar), '') + 
									COALESCE(',' + CAST(transit_system_4 AS nvarchar), '') + 
									COALESCE(',' + CAST(transit_system_5 AS nvarchar), ''), 1, 1, ''),
			transit_lines = STUFF(	COALESCE(',' + CAST(transit_line_1 AS nvarchar), '') + 
									COALESCE(',' + CAST(transit_line_2 AS nvarchar), '') + 
									COALESCE(',' + CAST(transit_line_3 AS nvarchar), '') + 
									COALESCE(',' + CAST(transit_line_4 AS nvarchar), '') + 
									COALESCE(',' + CAST(transit_line_5 AS nvarchar), ''), 1, 1, '')							

		DROP TABLE IF EXISTS trip_ingredient;
		SELECT TOP 1 *, CAST(-1 AS int) AS trip_link INTO trip_ingredient FROM trip;
		TRUNCATE TABLE trip_ingredient;
		GO

		-- remove component records into separate table, starting w/ 2nd component (i.e., first is left in trip table).  The criteria here determine which get considered components.
		DELETE next_trip  
		OUTPUT DELETED.*, CAST(0 AS int) AS trip_link INTO trip_ingredient
		FROM trip JOIN trip AS next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 = next_trip.tripnum
			WHERE 	trip.dest_is_home IS NULL AND trip.dest_is_work IS NULL AND 
				((trip.dest_purpose = 60 AND DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 30)
			OR 	(trip.dest_purpose = next_trip.dest_purpose AND trip.dest_purpose <> 9 
					AND DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 15 
					AND (trip.mode_1<>next_trip.mode_1 OR (trip.mode_1 = next_trip.mode_1 AND EXISTS (SELECT trip.mode_1 FROM transitmodes)))));
		
		-- set the trip_link value of the 2nd component to the tripnum of the 1st component.
		UPDATE ti  
			SET ti.trip_link = (ti.tripnum - 1)
			FROM trip_ingredient AS ti LEFT JOIN trip_ingredient AS previous_et ON ti.personid = previous_et.personid AND (ti.tripnum - 1) = previous_et.tripnum
			WHERE (CONCAT(ti.personid, (ti.tripnum - 1)) <> CONCAT(previous_et.personid, previous_et.tripnum));
		
		-- assign trip_link value to remaining records in the trip.
		WITH cte (tripid, ref_link) AS 
		(SELECT ti1.tripid, MAX(ti1.trip_link) OVER(PARTITION BY ti1.personid ORDER BY ti1.tripnum ROWS UNBOUNDED PRECEDING) AS ref_link
			FROM trip_ingredient AS ti1)
		UPDATE ti
			SET ti.trip_link = cte.ref_link
			FROM trip_ingredient AS ti JOIN cte ON ti.tripid = cte.tripid
			WHERE ti.trip_link = 0;	

		-- add the 1st component without deleting it from the trip table.
		INSERT INTO trip_ingredient
			SELECT t.*, t.tripnum AS trip_link FROM trip AS t JOIN trip_ingredient AS ti ON t.personid = ti.personid AND t.tripnum = ti.trip_link AND t.tripnum = ti.tripnum - 1;

		-- denote trips with too many components or other attributes suggesting multiple trips, for later examination.  
		WITH cte AS 
			(SELECT ti1.personid, ti1.trip_link
				FROM trip_ingredient as ti1 GROUP BY ti1.personid, ti1.trip_link 
				HAVING count(*) > 5
			UNION ALL SELECT ti2.personid, ti2.trip_link	
				FROM trip_ingredient as ti2 GROUP BY ti2.personid, ti2.trip_link
				HAVING sum(CASE WHEN LEN(ti2.pool_start) 			<>0 THEN 1 ELSE 0 END) > 1
					OR sum(CASE WHEN LEN(ti2.change_vehicles) 		<>0 THEN 1 ELSE 0 END) > 1
					OR sum(CASE WHEN LEN(ti2.park_ride_area_start) 	<>0 THEN 1 ELSE 0 END) > 1
					OR sum(CASE WHEN LEN(ti2.park_ride_area_end) 	<>0 THEN 1 ELSE 0 END) > 1
					OR sum(CASE WHEN LEN(ti2.park_ride_lot_start) 	<>0 THEN 1 ELSE 0 END) > 1
					OR sum(CASE WHEN LEN(ti2.park_ride_lot_end) 	<>0 THEN 1 ELSE 0 END) > 1
					OR sum(CASE WHEN LEN(ti2.park_type) 			<>0 THEN 1 ELSE 0 END) > 1)
		UPDATE ti
			SET ti.trip_link = -1 * ti.trip_link
			FROM trip_ingredient AS ti JOIN cte ON cte.personid = ti.personid AND cte.trip_link = ti.trip_link;
		GO

		-- return the un-linked components back to the trip table
		DROP TABLE IF EXISTS trip_ingredient_reject;
		SELECT * INTO trip_ingredient_reject FROM  trip_ingredient
			WHERE ti.trip_link = -1 AND ti.tripnum <> ti.trip_link;

		ALTER TABLE trip_ingredient_reject DROP COLUMN trip_link;
		INSERT INTO trip SELECT * FROM trip_ingredient_reject; -- This is quick & dirty; to avoid field mapping problems, this should probably specify each field


		-- meld the trip_ingredients to create the fields that will populate the linked trip, and saves those as a separate table, 'linked_trip'.
		DROP TABLE IF EXISTS linked_trip;
		GO
		WITH cte_agg AS
		(SELECT ti_agg.personid,
				ti_agg.trip_link,
				MAX(ti_agg.arrival_time_timestamp) 	AS arrival_time_timestamp,		MAX(ti_agg.hhmember1) 	AS hhmember1, 
				SUM(ti_agg.trip_path_distance) 		AS trip_path_distance, 			MAX(ti_agg.hhmember2) 	AS hhmember2, 
				SUM(ti_agg.google_duration) 		AS google_duration, 			MAX(ti_agg.hhmember3) 	AS hhmember3, 
				SUM(ti_agg.reported_duration) 		AS reported_duration,			MAX(ti_agg.hhmember4) 	AS hhmember4, 
				MAX(ti_agg.travelers_hh) 			AS travelers_hh, 				MAX(ti_agg.hhmember5) 	AS hhmember5, 
				MAX(ti_agg.travelers_nonhh) 		AS travelers_nonhh, 			MAX(ti_agg.hhmember6) 	AS hhmember6,
				MAX(ti_agg.travelers_total) 		AS travelers_total,				MAX(ti_agg.hhmember7) 	AS hhmember7, 
				MAX(ti_agg.hhmember_none) 			AS hhmember_none, 				MAX(ti_agg.hhmember8) 	AS hhmember8, 
				MAX(ti_agg.pool_start)				AS pool_start, 					MAX(ti_agg.hhmember9) 	AS hhmember9, 
				MAX(ti_agg.change_vehicles)			AS change_vehicles, 			MAX(ti_agg.park) 		AS park, 
				MAX(ti_agg.park_ride_area_start)	AS park_ride_area_start, 		MAX(ti_agg.toll)		AS toll, 
				MAX(ti_agg.park_ride_area_end)		AS park_ride_area_end, 			MAX(ti_agg.park_type)	AS park_type, 
				MAX(ti_agg.park_ride_lot_start)		AS park_ride_lot_start, 		MAX(ti_agg.taxi_type)	AS taxi_type, 
				MAX(ti_agg.park_ride_lot_end)		AS park_ride_lot_end, 			MAX(ti_agg.bus_type)	AS bus_type, 	
				MAX(ti_agg.bus_cost_dk)				AS bus_cost_dk, 				MAX(ti_agg.ferry_type)	AS ferry_type, 
				MAX(ti_agg.ferry_cost_dk)			AS ferry_cost_dk,				MAX(ti_agg.rail_type)	AS rail_type, 
				MAX(ti_agg.rail_cost_dk)			AS rail_cost_dk, 				MAX(ti_agg.air_type)	AS air_type,	
				MAX(ti_agg.airfare_cost_dk)			AS airfare_cost_dk
			/*		(ti_agg.bus_pay)				AS bus_pay, 
					(ti_agg.ferry_pay)				AS ferry_pay, 
					(ti_agg.rail_pay)				AS rail_pay, 
					(ti_agg.air_pay)				AS air_pay, 
					(ti_agg.park_pay)				AS park_pay,
					(ti_agg.toll_pay)				AS toll_pay, 
					(ti_agg.taxi_pay)				AS taxi_pay 					
				CASE WHEN (ti_agg.driver) ...							AS driver,*/
						FROM trip_ingredient as ti_agg WHERE ti_agg.trip_link > 0 GROUP BY ti_agg.personid, ti_agg.trip_link),
		cte_wndw AS	
		(SELECT DISTINCT
				ti_wndw.personid AS personid2,
				ti_wndw.trip_link AS trip_link2,
				FIRST_VALUE(ti_wndw.dest_purpose) 	OVER (PARTITION BY CONCAT(ti_wndw.personid,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_purpose,
				FIRST_VALUE(ti_wndw.dest_name) 		OVER (PARTITION BY CONCAT(ti_wndw.personid,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_name,
				FIRST_VALUE(ti_wndw.dest_address) 	OVER (PARTITION BY CONCAT(ti_wndw.personid,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_address,
				FIRST_VALUE(ti_wndw.dest_county) 	OVER (PARTITION BY CONCAT(ti_wndw.personid,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_county,
				FIRST_VALUE(ti_wndw.dest_city) 		OVER (PARTITION BY CONCAT(ti_wndw.personid,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_city,
				FIRST_VALUE(ti_wndw.dest_zip) 		OVER (PARTITION BY CONCAT(ti_wndw.personid,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_zip,
				FIRST_VALUE(ti_wndw.dest_is_home) 	OVER (PARTITION BY CONCAT(ti_wndw.personid,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_is_home,
				FIRST_VALUE(ti_wndw.dest_is_work) 	OVER (PARTITION BY CONCAT(ti_wndw.personid,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_is_work,
				FIRST_VALUE(ti_wndw.dest_lat) 		OVER (PARTITION BY CONCAT(ti_wndw.personid,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_lat,
				FIRST_VALUE(ti_wndw.dest_lng) 		OVER (PARTITION BY CONCAT(ti_wndw.personid,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_lng,
				FIRST_VALUE(ti_wndw.mode_acc) 		OVER (PARTITION BY CONCAT(ti_wndw.personid,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum ASC)  AS mode_acc,
				FIRST_VALUE(ti_wndw.mode_egr) 		OVER (PARTITION BY CONCAT(ti_wndw.personid,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS mode_egr,
				--STRING_AGG(ti_wnd.modes,',') 		OVER (PARTITION BY ti_wnd.trip_link ORDER BY ti_wndw.tripnum ASC) AS modes,
				STUFF(
					(SELECT ',' + ti1.modes
					FROM trip_ingredient AS ti1 
					WHERE ti1.personid = ti_wndw.personid AND ti1.trip_link = ti_wndw.trip_link
					ORDER BY ti_wndw.personid DESC, ti_wndw.tripnum DESC
					FOR XML PATH('')), 1, 1, NULL) AS modes,	
				--STRING_AGG(ti2.transit_systems,',') OVER (PARTITION BY ti_wnd.trip_link ORDER BY ti_wndw.tripnum ASC) AS transit_systems,
				STUFF(
					(SELECT ',' + ti2.transit_systems
					FROM trip_ingredient AS ti2
					WHERE ti2.personid = ti_wndw.personid AND ti2.trip_link = ti_wndw.trip_link
					ORDER BY ti_wndw.personid DESC, ti_wndw.tripnum DESC
					FOR XML PATH('')), 1, 1, NULL) AS transit_systems,				
				--STRING_AGG(ti_wnd.transit_lines,',') OVER (PARTITION BY trip_link ORDER BY ti_wndw.tripnum ASC) AS transit_lines	
				STUFF(
					(SELECT ',' + ti3.transit_lines
					FROM trip_ingredient AS ti3 JOIN trip AS t ON ti3.personid = t.personid AND ti3.trip_link = t.tripnum
					WHERE ti3.personid = ti_wndw.personid AND ti3.trip_link = ti_wndw.trip_link
					ORDER BY ti_wndw.personid DESC, ti_wndw.tripnum DESC
					FOR XML PATH('')), 1, 1, NULL) AS transit_lines	
			FROM trip_ingredient as ti_wndw WHERE ti_wndw.trip_link > 0 )
		SELECT cte_wndw.*, cte_agg.* INTO linked_trip
			FROM cte_wndw JOIN cte_agg ON cte_wndw.personid2 = cte_agg.personid AND cte_wndw.trip_link2 = cte_agg.trip_link;
		GO	

		-- this update achieves trip linking via revising elements of the 1st component (purposely left in the trip table).		
		UPDATE 	t
			SET t.dest_purpose 		= lt.dest_purpose,	
				t.dest_address		= lt.dest_address,					t.dest_name 	= lt.dest_name,	
				t.transit_systems	= lt.transit_systems,				t.dest_city		= lt.dest_city,
				t.transit_lines		= lt.transit_lines,					t.dest_county	= lt.dest_county,
				t.modes				= lt.modes,							t.dest_zip		= lt.dest_zip,
				t.dest_is_home		= lt.dest_is_home,					t.dest_lat		= lt.dest_lat,
				t.dest_is_work		= lt.dest_is_work,					t.dest_lng		= lt.dest_lng,
											
				t.arrival_time_timestamp = lt.arrival_time_timestamp,	t.hhmember1 	= lt.hhmember1, 
				t.trip_path_distance 	= lt.trip_path_distance, 		t.hhmember2 	= lt.hhmember2, 
				t.google_duration 		= lt.google_duration, 			t.hhmember3 	= lt.hhmember3, 
				t.reported_duration 	= lt.reported_duration,			t.hhmember4 	= lt.hhmember4, 
				t.travelers_hh 			= lt.travelers_hh, 				t.hhmember5 	= lt.hhmember5, 
				t.travelers_nonhh 		= lt.travelers_nonhh, 			t.hhmember6 	= lt.hhmember6,
				t.travelers_total 		= lt.travelers_total,			t.hhmember7 	= lt.hhmember7, 
				t.hhmember_none 		= lt.hhmember_none, 			t.hhmember8 	= lt.hhmember8, 
				t.pool_start			= lt.pool_start, 				t.hhmember9 	= lt.hhmember9, 
				t.change_vehicles		= lt.change_vehicles, 			t.park 			= lt.park, 
				t.park_ride_area_start	= lt.park_ride_area_start, 		t.toll			= lt.toll, 
				t.park_ride_area_end	= lt.park_ride_area_end, 		t.park_type		= lt.park_type, 
				t.park_ride_lot_start	= lt.park_ride_lot_start, 		t.taxi_type		= lt.taxi_type, 
				t.park_ride_lot_end		= lt.park_ride_lot_end, 		t.bus_type		= lt.bus_type, 	
																		t.ferry_type	= lt.ferry_type, 
																		t.rail_type		= lt.rail_type, 
																		t.air_type		= lt.air_type,	
				t.revision_code 		= CONCAT(t.revision_code, '5,')
			FROM trip AS t JOIN linked_trip AS lt ON t.personid = lt.personid AND t.tripnum = lt.trip_link 

/* STEP 5.	Mode number standardization, including access and egress characterization */

		--eliminate repeated values for modes, transit_systems, and transit_lines
		UPDATE t 
			SET t.modes				= dbo.TRIM(dbo.RgxReplace(t.modes,'(-?\b\d+\b),(?=\1)','',1)),
				t.transit_systems 	= dbo.TRIM(dbo.RgxReplace(t.transit_systems,'(\b\d+\b),(?=\1)','',1)), 
				t.transit_lines 	= dbo.TRIM(dbo.RgxReplace(t.transit_lines,'(\b\d+\b),(?=\1)','',1))
			FROM trip AS t;

		EXECUTE tripnum_update; 
				
		UPDATE trip SET mode_acc = NULL, mode_egr = NULL;	-- Clears what was stored as access or egress; those values are still part of the chain captured in the concatenated 'modes' field.

		-- Characterize access and egress trips, separately for 1) transit trips and 2) auto trips.  (Bike/Ped trips have no access/egress)
		-- [Unions must be used here; otherwise the VALUE set from the dbo.Rgx table object gets reused across cte fields.]
		WITH cte_acc_egr  AS 
		(	SELECT t1.personid, t1.tripnum, 'A' AS label, 'transit' AS trip_type,
				(SELECT MAX(CAST(VALUE AS int)) FROM STRING_SPLIT(dbo.RgxExtract(t1.modes,'^(\b(?:1|2|3|4|5|6|7|8|9|10|11|12|16|17|18|21|22|33|34|36|37|47)\b,?)+',1),',')) AS link_value
			FROM trip AS t1 WHERE EXISTS (SELECT 1 FROM STRING_SPLIT(t1.modes,',') WHERE VALUE IN(SELECT mode_id FROM transitmodes))
			UNION ALL 
			SELECT t2.personid, t2.tripnum, 'E' AS label, 'transit' AS trip_type,	
				(SELECT MAX(CAST(VALUE AS int)) FROM STRING_SPLIT(dbo.RgxExtract(t2.modes,'(,\b(?:1|2|3|4|5|6|7|8|9|10|11|12|16|17|18|21|22|33|34|36|37|47)\b)+$',1),',')) AS link_value 
			FROM trip AS t2 WHERE EXISTS (SELECT 1 FROM STRING_SPLIT(t2.modes,',') WHERE VALUE IN(SELECT mode_id FROM transitmodes))
			UNION ALL 
			SELECT t3.personid, t3.tripnum, 'A' AS label, 'auto' AS trip_type,
				(SELECT MAX(CAST(VALUE AS int)) FROM STRING_SPLIT(dbo.RgxReplace(t3.modes,'^(\b(?:1|2)\b,?)+','',1),',')) AS link_value
			FROM trip AS t3 WHERE EXISTS (SELECT 1 FROM STRING_SPLIT(t3.modes,',') WHERE VALUE IN(SELECT mode_id FROM automodes)) 
								  AND NOT EXISTS (SELECT 1 FROM STRING_SPLIT(t3.modes,',') WHERE VALUE IN(SELECT mode_id FROM transitmodes))
			UNION ALL 
			SELECT t4.personid, t4.tripnum, 'E' AS label, 'auto' AS trip_type,
				(SELECT MAX(CAST(VALUE AS int)) FROM STRING_SPLIT(dbo.RgxReplace(t4.modes,'^(\b(?:1|2)\b,?)+','',1),',')) AS link_value
			FROM trip AS t4 WHERE EXISTS (SELECT 1 FROM STRING_SPLIT(t4.modes,',') WHERE VALUE IN(SELECT mode_id FROM automodes)) 
								  AND NOT EXISTS (SELECT 1 FROM STRING_SPLIT(t4.modes,',') WHERE VALUE IN(SELECT mode_id FROM transitmodes)))
		UPDATE t 
			SET t.mode_acc = CASE 	WHEN cte_acc_egr.label = 'A' THEN cte_acc_egr.link_value ELSE NULL END,
				t.mode_egr = CASE 	WHEN cte_acc_egr.label = 'E' THEN cte_acc_egr.link_value ELSE NULL END
			FROM trip AS t JOIN cte_acc_egr ON t.personid = cte_acc_egr.personid AND t.tripnum = cte_acc_egr.tripnum WHERE cte_acc_egr.link_value IS NOT NULL;

		-- Remove access/egress modes from 1) transit and 2) auto trip strings--not only at the ends, but also the middle. [QC this & be careful!]
	 	WITH cte_mode AS		
		(	SELECT t5.personid, t5.tripnum, 'transit' AS trip_type,
			(STUFF((SELECT ',' + CAST((Match) AS VARCHAR(MAX)) AS [text()] FROM dbo.RgxSplit(t5.modes,',',1) WHERE (Match) IN(SELECT mode_id FROM transitmodes)
					FOR XML PATH('')), 1, 1, NULL)) AS mode_reduced
			FROM trip AS t5 WHERE EXISTS (SELECT 1 FROM STRING_SPLIT(t5.modes,',') WHERE VALUE IN(SELECT mode_id FROM transitmodes))
			UNION ALL
			SELECT t6.personid, t6.tripnum, 'auto' AS trip_type,
			(STUFF((SELECT ',' + CAST((Match) AS VARCHAR(MAX)) AS [text()] FROM dbo.RgxSplit(t6.modes,',',1) WHERE (Match) IN(SELECT mode_id FROM automodes)
					FOR XML PATH('')), 1, 1, NULL)) AS mode_reduced
			FROM trip AS t6 WHERE EXISTS (SELECT 1 FROM STRING_SPLIT(t6.modes,',') WHERE VALUE IN(SELECT mode_id FROM automodes)) 
								  AND NOT EXISTS (SELECT 1 FROM STRING_SPLIT(t6.modes,',') WHERE VALUE IN(SELECT mode_id FROM transitmodes)))
		UPDATE t 
			SET t.modes	= cte_mode.mode_reduced
			FROM trip AS t JOIN cte_mode ON t.personid = cte_mode.personid AND t.tripnum = cte_mode.tripnum WHERE cte_mode.mode_reduced IS NOT NULL;
			
		-- Populate the standard fields with the revised concatenated data 		
		UPDATE 	t
			SET t.mode_1			= (SELECT Match FROM dbo.RgxMatches(t.modes,			'-?\b\d+\b',1) ORDER BY MatchIndex OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY),
				t.mode_2			= (SELECT Match FROM dbo.RgxMatches(t.modes,			'-?\b\d+\b',1) ORDER BY MatchIndex OFFSET 1 ROWS FETCH NEXT 1 ROWS ONLY),
				t.mode_3			= (SELECT Match FROM dbo.RgxMatches(t.modes,			'-?\b\d+\b',1) ORDER BY MatchIndex OFFSET 2 ROWS FETCH NEXT 1 ROWS ONLY),
				t.mode_4			= (SELECT Match FROM dbo.RgxMatches(t.modes,			'-?\b\d+\b',1) ORDER BY MatchIndex OFFSET 3 ROWS FETCH NEXT 1 ROWS ONLY),
				t.transit_system_1	= (SELECT Match FROM dbo.RgxMatches(t.transit_systems,	'-?\b\d+\b',1) ORDER BY MatchIndex OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY),
				t.transit_system_2	= (SELECT Match FROM dbo.RgxMatches(t.transit_systems,	'-?\b\d+\b',1) ORDER BY MatchIndex OFFSET 1 ROWS FETCH NEXT 1 ROWS ONLY),
				t.transit_system_3	= (SELECT Match FROM dbo.RgxMatches(t.transit_systems,	'-?\b\d+\b',1) ORDER BY MatchIndex OFFSET 2 ROWS FETCH NEXT 1 ROWS ONLY),
				t.transit_system_4	= (SELECT Match FROM dbo.RgxMatches(t.transit_systems,	'-?\b\d+\b',1) ORDER BY MatchIndex OFFSET 3 ROWS FETCH NEXT 1 ROWS ONLY),
				t.transit_system_5	= (SELECT Match FROM dbo.RgxMatches(t.transit_systems,	'-?\b\d+\b',1) ORDER BY MatchIndex OFFSET 4 ROWS FETCH NEXT 1 ROWS ONLY),
				t.transit_line_1	= (SELECT Match FROM dbo.RgxMatches(t.transit_lines,	'-?\b\d+\b',1) ORDER BY MatchIndex OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY),
				t.transit_line_2	= (SELECT Match FROM dbo.RgxMatches(t.transit_lines,	'-?\b\d+\b',1) ORDER BY MatchIndex OFFSET 1 ROWS FETCH NEXT 1 ROWS ONLY),
				t.transit_line_3	= (SELECT Match FROM dbo.RgxMatches(t.transit_lines,	'-?\b\d+\b',1) ORDER BY MatchIndex OFFSET 2 ROWS FETCH NEXT 1 ROWS ONLY),
				t.transit_line_4	= (SELECT Match FROM dbo.RgxMatches(t.transit_lines,	'-?\b\d+\b',1) ORDER BY MatchIndex OFFSET 3 ROWS FETCH NEXT 1 ROWS ONLY),
				t.transit_line_5	= (SELECT Match FROM dbo.RgxMatches(t.transit_lines,	'-?\b\d+\b',1) ORDER BY MatchIndex OFFSET 4 ROWS FETCH NEXT 1 ROWS ONLY)
			FROM trip AS t;
			 
/* STEP 6. Insert trips for those who were reported as a passenger by another traveler but did not report the trip themselves */
/* Currenty, using a tight constraint for overlap, this generates no trips -- may deserve further scrutiny  */

   DROP TABLE IF EXISTS silent_passenger_trip;
   GO
   WITH cte AS --create CTE set of passenger trips
        (         SELECT tripid, pernum AS respondent, hhmember1 as passengerid FROM trip WHERE hhmember1 IS NOT NULL AND hhmember1 <> personid
        UNION ALL SELECT tripid, pernum AS respondent, hhmember2 as passengerid FROM trip WHERE hhmember2 IS NOT NULL AND hhmember2 <> personid
        UNION ALL SELECT tripid, pernum AS respondent, hhmember3 as passengerid FROM trip WHERE hhmember3 IS NOT NULL AND hhmember3 <> personid
        UNION ALL SELECT tripid, pernum AS respondent, hhmember4 as passengerid FROM trip WHERE hhmember4 IS NOT NULL AND hhmember4 <> personid
        UNION ALL SELECT tripid, pernum AS respondent, hhmember5 as passengerid FROM trip WHERE hhmember5 IS NOT NULL AND hhmember5 <> personid
        UNION ALL SELECT tripid, pernum AS respondent, hhmember6 as passengerid FROM trip WHERE hhmember6 IS NOT NULL AND hhmember6 <> personid
        UNION ALL SELECT tripid, pernum AS respondent, hhmember7 as passengerid FROM trip WHERE hhmember7 IS NOT NULL AND hhmember7 <> personid
        UNION ALL SELECT tripid, pernum AS respondent, hhmember8 as passengerid FROM trip WHERE hhmember8 IS NOT NULL AND hhmember8 <> personid
        UNION ALL SELECT tripid, pernum AS respondent, hhmember9 as passengerid FROM trip WHERE hhmember9 IS NOT NULL AND hhmember9 <> personid)
	SELECT tripid, respondent, passengerid INTO silent_passenger_trip FROM cte GROUP BY tripid, respondent, passengerid;

	DROP PROCEDURE IF EXISTS silent_passenger_trips_inserted;
	GO
	CREATE PROCEDURE silent_passenger_trips_inserted 
	AS BEGIN
	DECLARE @respondent int 
	SET @respondent = 1;
    INSERT INTO trip
		(hhid, personid, pernum,
		depart_time_timestamp, arrival_time_timestamp,
		dest_name, dest_address, dest_lat, dest_lng,
		trip_path_distance, google_duration, reported_duration,
		hhmember1, hhmember2, hhmember3, hhmember4, hhmember5, hhmember6, hhmember7, hhmember8, hhmember9, hhmember_none, travelers_hh, travelers_nonhh, travelers_total,
		mode_acc, mode_egr, mode_1, mode_2, mode_3, mode_4, change_vehicles, transit_system_1, transit_system_2, transit_system_3,
		park_ride_area_start, park_ride_area_end, park_ride_lot_start, park_ride_lot_end, park, park_type, park_pay,
		toll, toll_pay, taxi_type, taxi_pay, bus_type, bus_pay, bus_cost_dk, ferry_type, ferry_pay, ferry_cost_dk, rail_type, rail_pay, rail_cost_dk, air_type, air_pay, airfare_cost_dk,
		origin_geom, origin_lat, origin_lng, dest_geom, dest_county, dest_city, dest_zip, dest_is_home, dest_is_work, psrc_inserted, revision_code)
	SELECT -- select fields necessary for new trip records	
		t.hhid, spt.passengerid AS personid, CAST(RIGHT(spt.passengerid,2) AS int) AS pernum, 
		t.depart_time_timestamp, t.arrival_time_timestamp,
		t.dest_name, t.dest_address, t.dest_lat, t.dest_lng,
		t.trip_path_distance, t.google_duration, t.reported_duration,
		t.hhmember1, t.hhmember2, t.hhmember3, t.hhmember4, t.hhmember5, t.hhmember6, t.hhmember7, t.hhmember8, t.hhmember9, t.hhmember_none, t.travelers_hh, t.travelers_nonhh, t.travelers_total,
		t.mode_acc, t.mode_egr, t.mode_1, t.mode_2, t.mode_3, t.mode_4, t.change_vehicles, t.transit_system_1, t.transit_system_2, t.transit_system_3,
		t.park_ride_area_start, t.park_ride_area_end, t.park_ride_lot_start, t.park_ride_lot_end, t.park, t.park_type, t.park_pay,
		t.toll, t.toll_pay, t.taxi_type, t.taxi_pay, t.bus_type, t.bus_pay, t.bus_cost_dk, t.ferry_type, t.ferry_pay, t.ferry_cost_dk, t.rail_type, t.rail_pay, t.rail_cost_dk, t.air_type, t.air_pay, t.airfare_cost_dk,
		t.origin_geom, t.origin_lat, t.origin_lng, t.dest_geom, t.dest_county, t.dest_city, t.dest_zip, t.dest_is_home, t.dest_is_work, 1 AS psrc_inserted, CONCAT(t.revision_code, '6,') AS revision_code
	FROM silent_passenger_trip AS spt -- insert only when the time midpoint of the CTE trip doesn't intersect any trip by the same person; doesn't matter if an intersecting trip reports the other hhmembers or not.
        JOIN trip as t ON spt.tripid = t.tripid
		LEFT JOIN trip as compare_t ON spt.passengerid = compare_t.personid
		WHERE compare_t.personid IS NULL AND spt.respondent = @respondent
			AND (t.depart_time_timestamp NOT BETWEEN DATEADD(Minute, -5, compare_t.depart_time_timestamp) AND DATEADD(Minute, 5, compare_t.arrival_time_timestamp))
			AND (t.arrival_time_timestamp NOT BETWEEN DATEADD(Minute, -5, compare_t.depart_time_timestamp) AND DATEADD(Minute, 5, compare_t.arrival_time_timestamp));
	SET @respondent = @respondent + 1	
	END
	GO

	/* 	Batching by respondent prevents duplication in the case silent passengers were reported by multiple household members on the same trip.
		While there were copied trips with silent passengers listed in both (as they should), the 2017 data had no silent passenger trips in which pernum 1 was not involved;
		that is not guaranteed, so I've left the 8 procedure calls in, although later ones can be expected not to have an effect
	*/ 
	EXECUTE silent_passenger_trips_inserted;
	EXECUTE silent_passenger_trips_inserted;
	EXECUTE silent_passenger_trips_inserted;
	EXECUTE silent_passenger_trips_inserted;
	EXECUTE silent_passenger_trips_inserted;
	EXECUTE silent_passenger_trips_inserted;
	EXECUTE silent_passenger_trips_inserted;
	EXECUTE silent_passenger_trips_inserted;
	EXECUTE silent_passenger_trips_inserted;
	DROP PROCEDURE silent_passenger_trips_inserted;
	DROP TABLE silent_passenger_trip;

	EXECUTE tripnum_update; --after adding records, we need to renumber them consecutively
	EXECUTE dest_purpose_updates;  --running these again to apply to linked trips, JIC

/* STEP 7. Flag inconsistencies */
/*	as additional error patterns behind these flags are identified, rules to address them can be added to Step 3 or elsewhere in Rulesy as makes sense.*/

		DROP TABLE IF EXISTS trip_error_flags;
		CREATE TABLE trip_error_flags(
			tripid bigint not NULL,
			personid int not NULL,
			tripnum int not null,
			error_flag varchar(100),
			rulesy_fixed varchar(10) default 'no'
			PRIMARY KEY (personid, tripid, error_flag)
		);
		GO

		-- 																									  LOGICAL ERROR LABEL 		
		WITH error_flag_compilation(tripid, personid, tripnum, error_flag) AS
			(SELECT t1.tripid, t1.personid, t1.tripnum, 														'underage driver' AS error_flag
					FROM hhts_agecodes AS age JOIN person AS p ON age.agecode = p.age
						JOIN trip AS t1 ON p.personid = t1.personid
					WHERE t1.driver = 1 AND p.age BETWEEN 1 AND 3

			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum, 										  'unlicensed driver' AS error_flag
				FROM trip JOIN person AS p ON p.personid=trip.personid
				WHERE p.license = 3 AND trip.driver=1

			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum, 							 'non-worker reporting work trip' AS error_flag
				FROM trip JOIN person AS p ON p.personid=trip.personid
				WHERE p.worker = 0 AND trip.dest_purpose in(10,11,14)

			UNION ALL SELECT t.tripid, t.personid, t.tripnum, 											'speed unreasonably high' AS error_flag
				FROM trip AS t									
				WHERE 	(t.mode_1 = 1 AND t.speed_mph > 20)
					OR 	(t.mode_1 = 2 AND t.speed_mph > 40)
					OR 	((t.mode_1 between 3 and 52 AND t.mode_1 <> 31) AND t.speed_mph > 85)
					OR 	(t.speed_mph > 600)	

			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum,				   'no activity time prior to next departure' AS error_flag
				FROM trip JOIN trip AS next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 =next_trip.tripnum
				WHERE DATEDIFF(Second, trip.depart_time_timestamp, next_trip.depart_time_timestamp) < 60

			UNION ALL SELECT next_trip.tripid, next_trip.personid, next_trip.tripnum,	   'no activity time since prior arrival' AS error_flag
				FROM trip JOIN trip AS next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 =next_trip.tripnum
				WHERE DATEDIFF(Second, trip.depart_time_timestamp, next_trip.depart_time_timestamp) < 60

			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum,					        'identical location as next trip' AS error_flag
				FROM trip JOIN trip AS next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 =next_trip.tripnum
					AND trip.dest_lat = next_trip.dest_lat AND trip.dest_lng = next_trip.dest_lng

			UNION ALL SELECT next_trip.tripid, next_trip.personid, next_trip.tripnum,	       'identical location as prior trip' AS error_flag
				FROM trip JOIN trip AS next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 =next_trip.tripnum 
					AND trip.dest_lat = next_trip.dest_lat AND trip.dest_lng = next_trip.dest_lng

			UNION ALL (SELECT trip.tripid, trip.personid, trip.tripnum,					         'time overlap with another trip' AS error_flag
				FROM trip JOIN trip AS compare_t ON trip.personid=compare_t.personid AND trip.tripid <> compare_t.tripid
				WHERE 	(compare_t.depart_time_timestamp  BETWEEN DATEADD(Minute, 2, trip.depart_time_timestamp) AND DATEADD(Minute, -2, trip.arrival_time_timestamp))
					OR	(compare_t.arrival_time_timestamp BETWEEN DATEADD(Minute, 2, trip.depart_time_timestamp) AND DATEADD(Minute, -2, trip.arrival_time_timestamp))
					OR	(trip.depart_time_timestamp  BETWEEN DATEADD(Minute, 2, compare_t.depart_time_timestamp) AND DATEADD(Minute, -2, compare_t.arrival_time_timestamp))
					OR	(trip.arrival_time_timestamp BETWEEN DATEADD(Minute, 2, compare_t.depart_time_timestamp) AND DATEADD(Minute, -2, compare_t.arrival_time_timestamp)))

			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum,					'same transit line listed multiple times' AS error_flag
				FROM trip
    			WHERE EXISTS(SELECT count(*) 
								FROM (VALUES(trip.transit_line_1),(trip.transit_line_2),(trip.transit_line_3),(trip.transit_line_4),(trip.transit_line_5)) AS transitline(member) 
								WHERE member IS NOT NULL GROUP BY member HAVING count(*) > 1)

			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum,					'non-home trip purpose, destination home' AS error_flag
				FROM trip
				WHERE trip.dest_purpose <> 1 AND trip.dest_is_home = 1

			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum,			'home or work trip purpose, destination elsewhere' AS error_flag
				FROM trip
				WHERE (trip.dest_purpose <> 1 and trip.dest_is_home = 1) OR (trip.dest_purpose <> 10 and trip.dest_is_work = 1)

			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum,					                  'missing next trip link' AS error_flag
			FROM trip JOIN trip AS next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 =next_trip.tripnum
				WHERE ABS(trip.dest_lat - next_trip.origin_lat) >.0045  --roughly 500m difference or more, using degrees

			UNION ALL SELECT next_trip.tripid, next_trip.personid, next_trip.tripnum,	              'missing previous trip link' AS error_flag
			FROM trip JOIN trip AS next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 =next_trip.tripnum
				WHERE ABS(trip.dest_lat - next_trip.origin_lat) >.0045	--roughly 500m difference or more, using degrees

			UNION ALL SELECT next_trip.tripid, next_trip.personid, next_trip.tripnum,	           'starts from non-home location' AS error_flag
			FROM trip JOIN trip AS next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 =next_trip.tripnum
				WHERE DATEDIFF(Day, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) = 1 --first trip of the day
					AND dbo.TRIM(next_trip.origin_name)<>'HOME' 
					AND DATEPART(Hour, next_trip.depart_time_timestamp) > 1  -- Night owls typically home before 2am

			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum,					  'unusually long duration at destination' AS error_flag
				FROM trip JOIN trip AS next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 =next_trip.tripnum
					WHERE   (trip.dest_purpose IN(6,10,11,12,14)    			AND DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) > 720)
    					OR  (trip.dest_purpose IN(30,33,34,50)      			AND DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) > 180)
   						OR  (trip.dest_purpose IN(32,51,52,53,54,56,60,61,62) 	AND DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) > 300)

			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum, 		  'suspected drop-off or pick-up coded as school trip' AS error_flag
				FROM trip JOIN trip as next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 = next_trip.tripnum JOIN person ON trip.personid=person.personid 					
				WHERE 	trip.dest_purpose = 6		
					AND ((person.student NOT IN(2,3,4))
						OR (DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 20)))
		INSERT INTO trip_error_flags (tripid, personid, tripnum, error_flag)
			SELECT tripid, personid, tripnum, error_flag FROM error_flag_compilation GROUP BY tripid, personid, tripnum, error_flag;
		GO

/* STEP 8. Impute missing fields [access/egress, etc] */
/* TBD */
	
