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

DROP SEQUENCE IF EXISTS tripid_increment, workhorse_sequence;
DROP TABLE IF EXISTS household, person, tripx_raw, trip, transitmodes, automodes, pedmodes, walkmodes, nontransitmodes, eliminated_trips;

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
			ADD geom GEOMETRY NULL,
				dest_county	varchar(3) NULL,
				dest_city	varchar(25) NULL,
				dest_zip	varchar(5) NULL,
				dest_is_home bit NULL, 
				dest_is_work bit NULL,
				psrc_inserted bit NULL;
		GO
		
		UPDATE trip	SET geom = geometry::STPointFromText('POINT(' + CAST(dest_lng AS VARCHAR(20)) + ' ' + CAST(dest_lat AS VARCHAR(20)) + ')', 4326);
		ALTER TABLE trip ADD CONSTRAINT PK_trip PRIMARY KEY CLUSTERED (tripid) WITH FILLFACTOR=80;
		DROP SEQUENCE IF EXISTS tripid_increment;
		CREATE SEQUENCE tripid_increment AS int START WITH 1 INCREMENT BY 1 NO CYCLE;  -- Create sequence object to generate tripid for new records & add indices
		DROP SEQUENCE IF EXISTS workhorse_sequence;
		CREATE SEQUENCE workhorse_sequence AS int START WITH -2147483648 INCREMENT BY 1 NO CYCLE; -- Create second sequence object for linking purposes
		ALTER TABLE trip ADD CONSTRAINT tripid_autonumber DEFAULT NEXT VALUE FOR tripid_increment FOR tripid;
		CREATE INDEX person_idx ON trip (personid ASC);
		CREATE INDEX tripnum_idx ON trip (tripnum ASC);
		CREATE INDEX dest_purpose_idx ON trip (dest_purpose);
		CREATE INDEX travelers_total_idx ON trip(travelers_total);
		GO
	 
		CREATE SPATIAL INDEX geom_idx ON trip(geom)
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
			FROM trip AS t JOIN tripnum_rev ON t.tripid=tripnum_rev.tripid AND t.personid = tripnum_rev.personid
			WHERE EXISTS 
				(SELECT 1 FROM trip AS t_null WHERE t_null.personid = t.personid AND t_null.tripnum IS NULL)
				OR EXISTS 
					(SELECT 1 from trip AS t1 JOIN trip AS t2 ON t1.personid=t2.personid 
						WHERE (t1.personid=t.personid AND ((t2.tripnum - t1.tripnum) / 
						(CASE WHEN datediff(second, t1.arrival_time_timestamp, t2.depart_time_timestamp) = 0 THEN 1 
						ELSE datediff(second, t1.arrival_time_timestamp, t2.depart_time_timestamp) END) < 0)))
				OR EXISTS (SELECT 1 FROM trip AS t_skip WHERE t.personid = t_skip.personid GROUP BY personid HAVING count(tripnum)<>max(tripnum));
		END
		GO
		EXEC tripnum_update;

/* STEP 2.  Parse/Fill missing address fields */

	--address parsing
		UPDATE trip	SET dest_zip 	= SUBSTRING(dbo.RgxExtract(dest_address, 'WA (\d{5}), USA', 0),4,5);
		UPDATE trip	SET dest_city 	= LTRIM(RTRIM(SUBSTRING(dbo.RgxExtract(dest_address, '[A-Za-z ]+, WA ', 0),0,PATINDEX('%,%',dbo.RgxExtract(dest_address, '[A-Za-z ]+, WA ', 0)))));
		UPDATE trip SET dest_county = zipwgs.county FROM trip JOIN dbo.zipcode_wgs AS zipwgs ON trip.dest_zip=zipwgs.zipcode;
		GO

		UPDATE trip --fill missing zipcode
			SET trip.dest_zip = zipwgs.zipcode
			FROM trip join dbo.zipcode_wgs as zipwgs ON trip.geom.STIntersects(zipwgs.geom)=1
			WHERE trip.dest_zip IS NULL;

	/*	UPDATE trip --fill missing city --NOT YET AVAILABLE
			SET trip.dest_city = [ENTER CITY GEOGRAPHY HERE].City
			FROM trip join [ENTER CITY GEOGRAPHY HERE] ON trip.geom.STIntersects([ENTER CITY GEOGRAPHY HERE].geom)=1
			WHERE trip.dest_city IS NULL;
	*/
		UPDATE trip --fill missing county
			SET trip.dest_county = zipwgs.county
			FROM trip join dbo.zipcode_wgs as zipwgs ON trip.geom.STIntersects(zipwgs.geom)=1
			WHERE trip.dest_county IS NULL;


	-- -- [Create geographic check where assigned zip/county doesn't match the x,y.]		

	
		UPDATE trip --Create standard field for home trip
			SET dest_is_home = 1
			WHERE dest_name = 'HOME' 
				OR(
					(dbo.RgxFind([dest_name],' home',1) = 1 
					OR dbo.RgxFind([dest_name],'^h[om]?$',1) = 1) 
					and dbo.RgxFind([dest_name],'(their|her|s|from|near|nursing|friend) home',1) = 0
				)
				OR(dest_purpose = 1 AND dest_name IS NULL);

		UPDATE trip --Create standard field for work trip
			SET dest_is_work = 1
			WHERE dest_name = 'WORK' 
				OR((dbo.RgxFind([dest_name],' work',1) = 1 
					OR dbo.RgxFind([dest_name],'^w[or ]?$',1) = 1))
				OR(dest_purpose = 10 AND dest_name IS NULL);

	--Reclassify purpose (used in later steps)

		--Change code to pickup/dropoff when passenger number changes, duration is under 30 minutes, and pickup/dropoff mentioned in dest_name
			UPDATE trip 
				SET trip.dest_purpose = 9
				FROM trip 
					JOIN person ON trip.personid=person.personid 
					JOIN trip as next_trip ON trip.personid=next_trip.personid	AND trip.tripnum + 1 = next_trip.tripnum						
				WHERE dbo.RgxFind([trip].[dest_name],'(drop|pick)',1) = 1
					AND trip.dest_purpose <> 9
					AND trip.travelers_total <> next_trip.travelers_total
					AND DATEDIFF(minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 30;

		--Change 'Other' trip purpose when purpose is given in destination
			UPDATE trip 	SET dest_purpose = 1	WHERE dest_purpose = 97 AND dest_is_home = 1;
			UPDATE trip 	SET dest_purpose = 10	WHERE dest_purpose = 97 AND dest_is_work = 1;
			UPDATE trip		SET dest_purpose = 33	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'(bank|gas|post ?office)',1) = 1;		
			UPDATE trip		SET dest_purpose = 34	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'(doctor|dentist|hospital)',1) = 1;	
			UPDATE trip		SET dest_purpose = 50	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'(coffee|cafe|starbucks|lunch)',1) = 1;		
			UPDATE trip		SET dest_purpose = 51	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'dog',1) = 1 AND dbo.RgxFind(dest_name,'(walk|park)',1) = 1;
			UPDATE trip		SET dest_purpose = 51	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'park',1) = 1 AND dbo.RgxFind(dest_name,'(parking|ride)',1) = 0;
			UPDATE trip		SET dest_purpose = 54	WHERE dest_purpose = 97 AND dbo.RgxFind(dest_name,'church',1) = 1; 
		GO

/* STEP 3.	Trip linking */

	-- Revise access and/or egress when reported as a mode within a trip; iterates over pairs to catch multiple instances

		DROP PROCEDURE IF EXISTS within_trip_access_egress;
		GO
		CREATE PROCEDURE within_trip_access_egress AS
		BEGIN
			UPDATE t -- transit trip access
				SET t.mode_acc = CASE WHEN t.mode_acc > t.mode_1 THEN t.mode_acc ELSE t.mode_1 END, 
							t.mode_1 = t.mode_2,
							t.mode_2 = t.mode_3,
							t.mode_3 = t.mode_4,
							t.mode_4 = NULL			
				FROM trip AS t
				WHERE (t.mode_1 NOT IN(SELECT mode_id FROM transitmodes)) 	-- for transitmodes, other modes are considered access/egress
					AND EXISTS(SELECT 1 									-- at least one mode in transitmodes
								FROM (VALUES(t.mode_2),(t.mode_3),(t.mode_4)) AS modeset(member)
								WHERE member IN(SELECT mode_id FROM transitmodes));

			UPDATE t -- transit trip egress from mode_4
				SET t.mode_egr = CASE WHEN t.mode_egr > t.mode_4 THEN t.mode_egr ELSE t.mode_4 END, 
					t.mode_4 = NULL
				FROM trip AS t
				WHERE t.mode_4 IS NOT NULL AND t.mode_4 NOT IN(SELECT mode_id FROM transitmodes)
					AND EXISTS(SELECT 1 									-- at least one mode in transitmodes
								FROM (VALUES(t.mode_1),(t.mode_2),(t.mode_3)) AS modeset(member)
								WHERE member IN(SELECT mode_id FROM transitmodes));

			UPDATE trip SET mode_egr = CASE WHEN mode_egr > mode_3 THEN mode_egr ELSE mode_3 END, mode_3 = NULL -- transit trip egress B
				WHERE mode_3 IS NOT NULL AND mode_4 IS NULL AND mode_3 NOT IN(SELECT mode_id FROM transitmodes) 
					AND (mode_1 IN(SELECT mode_id FROM transitmodes) OR mode_2 IN(SELECT mode_id FROM transitmodes));

			UPDATE trip SET mode_egr = CASE WHEN mode_egr > mode_2 THEN mode_egr ELSE mode_2 END, mode_2 = NULL -- transit trip egress C
				WHERE mode_2 IS NOT NULL AND mode_3 IS NULL AND mode_2 NOT IN(SELECT mode_id FROM transitmodes) 
					AND mode_1 IN(SELECT mode_id FROM transitmodes);

			UPDATE trip SET mode_acc = CASE WHEN mode_acc > mode_1 THEN mode_acc ELSE mode_1 END, -- non-transit trip access
							mode_1 = mode_2,
							mode_2 = mode_3,
							mode_3 = mode_4,
							mode_4 = NULL				
				WHERE mode_1 IN(1,2) AND (mode_2 > 2 OR mode_3 > 2 OR mode_4 > 2);

			UPDATE trip SET mode_egr = CASE WHEN mode_egr > mode_4 THEN mode_egr ELSE mode_4 END, mode_4 = NULL -- non-transit trip egress A
				WHERE mode_4 IN(1,2) AND (mode_1 IN(SELECT mode_id FROM automodes) OR mode_2 IN(SELECT mode_id FROM automodes) OR mode_3 IN(SELECT mode_id FROM automodes));

			UPDATE trip SET mode_egr = CASE WHEN mode_egr > mode_3 THEN mode_egr ELSE mode_3 END, mode_3 = NULL -- non-transit trip egress B
				WHERE mode_3 IN(1,2) AND (mode_1 IN(SELECT mode_id FROM automodes) OR mode_2 IN(SELECT mode_id FROM automodes)) AND mode_4 IS NULL;

			UPDATE trip SET mode_egr = CASE WHEN mode_egr > mode_2 THEN mode_egr ELSE mode_2 END, mode_2 = NULL -- non-transit trip egress C
				WHERE mode_2 IN(1,2) AND mode_1 IN(SELECT mode_id FROM automodes) AND mode_3 IS NULL;
			END
			GO

		EXEC within_trip_access_egress;
		EXEC within_trip_access_egress;

	-- Revise access when reported as a separate trip; store the eliminated (access) trips

		SELECT TOP 1 * into eliminated_trips FROM trip;  
		DELETE FROM eliminated_trips; --creates empty table with structure identical to trips

		UPDATE trip
			SET trip.mode_acc 				= (SELECT MAX(member) FROM (VALUES(trip.mode_acc),(prev_trip.mode_acc)(prev_trip.mode_1),(prev_trip.mode_2),(prev_trip.mode_3),(prev_trip.mode_4)) AS modeset(member)),
				trip.depart_time_timestamp 	= prev_trip.depart_time_timestamp,
				trip.origin_name 			= prev_trip.origin_name,
				trip.origin_address 		= prev_trip.origin_address,
				trip.origin_lat 			= prev_trip.origin_lat,
				trip.origin_lng				= prev_trip.origin_lng,
				trip.trip_path_distance		= prev_trip.trip_path_distance + trip.trip_path_distance,
				trip.google_duration		= prev_trip.google_duration + trip.google_duration,
				trip.reported_duration		= prev_trip.reported_duration + trip.reported_duration
			FROM trip JOIN trip AS prev_trip ON trip.personid = prev_trip.personid AND trip.tripnum - 1 = prev_trip.tripnum
			WHERE (SELECT MAX(member) FROM (VALUES(prev_trip.mode_1),(prev_trip.mode_2),(prev_trip.mode_3),(prev_trip.mode_4)) AS modeset(member)) IN(@main) 
				AND trip.mode_1 NOT IN(@acc_egr)
				AND prev_trip.dest_purpose <> 9 AND trip.travelers_hh = prev_trip.travelers_hh
				AND datediff(minute, prev_trip.arrival_time_timestamp, trip.depart_time_timestamp) < 20
				AND (prev_trip.dest_purpose = trip.dest_purpose OR prev_trip.dest_purpose = 60);

		DELETE prev_trip 
			OUTPUT DELETED.* INTO eliminated_trips
			FROM trip JOIN trip AS prev_trip ON trip.personid = prev_trip.personid AND trip.tripnum - 1 = prev_trip.tripnum
			WHERE (SELECT MAX(member) FROM (VALUES(prev_trip.mode_1),(prev_trip.mode_2),(prev_trip.mode_3),(prev_trip.mode_4)) AS modeset(member)) IN(@acc_egr) 
				AND trip.mode_1 NOT IN(@acc_egr)
				AND prev_trip.dest_purpose <> 9 AND trip.travelers_hh = prev_trip.travelers_hh
				AND datediff(minute, prev_trip.arrival_time_timestamp, trip.depart_time_timestamp) < 20
				AND (prev_trip.dest_purpose = trip.dest_purpose OR prev_trip.dest_purpose = 60);							
		GO
		EXEC tripnum_update;
		GO

	-- Revise egress when reported as a separate trip; store the eliminated (egress) trips
		
		UPDATE trip
			SET trip.mode_egr 				= (SELECT MAX(member) FROM (VALUES(trip.mode_egr),(next_trip.mode_1),(next_trip.mode_2),(next_trip.mode_3),(next_trip.mode_4)) AS modeset(member)),
				trip.arrival_time_timestamp = next_trip.arrival_time_timestamp,
				trip.dest_name 				= next_trip.dest_name,
				trip.dest_address 			= next_trip.dest_address,
				trip.dest_lat 				= next_trip.dest_lat,
				trip.dest_lng				= next_trip.dest_lng,
				trip.trip_path_distance		= next_trip.trip_path_distance + trip.trip_path_distance,
				trip.google_duration		= next_trip.google_duration + trip.google_duration,
				trip.reported_duration		= next_trip.reported_duration + trip.reported_duration
			FROM trip JOIN trip AS next_trip ON trip.personid = next_trip.personid AND trip.tripnum + 1 = next_trip.tripnum 
			WHERE (SELECT MAX(member) FROM (VALUES(next_trip.mode_1),(next_trip.mode_2),(next_trip.mode_3),(next_trip.mode_4)) AS modeset(member)) IN(@acc_egr)
				AND trip.mode_1 NOT IN(1,2) AND trip.mode_egr IS NULL
				AND next_trip.dest_purpose <> 9 AND trip.travelers_hh = next_trip.travelers_hh
				AND datediff(minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 10
				AND (trip.dest_purpose = next_trip.dest_purpose OR trip.dest_purpose = 60);		

		DELETE next_trip
			OUTPUT DELETED.* INTO eliminated_trips
			FROM trip JOIN trip AS next_trip ON trip.personid = next_trip.personid AND trip.tripnum + 1 = next_trip.tripnum 
			WHERE (SELECT MAX(member) FROM (VALUES(next_trip.mode_1),(next_trip.mode_2),(next_trip.mode_3),(next_trip.mode_4)) AS modeset(member)) IN(1,2)
				AND trip.mode_1 NOT IN(1,2) AND trip.mode_egr IS NULL
				AND next_trip.dest_purpose <> 9 AND trip.travelers_hh = next_trip.travelers_hh
				AND datediff(minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 10
				AND (trip.dest_purpose = next_trip.dest_purpose OR trip.dest_purpose = 60);
		GO
		EXEC tripnum_update;
		GO
	-- Link remaining transit trip components reported as separate trips; store the eliminated trips
	-- Link remaining auto trip components reported as separate trips; store the eliminated trips
	-- Link any other trip components reported as separate trips; store the eliminated trips



/* STEP 4. Insert missing passenger trips */

    WITH list_passenger_trips AS --create CTE set of all passenger trips
        (SELECT             hhmember1 as passengerid, * FROM trip WHERE hhmember1 IS NOT NULL AND hhmember1 <> personid
        UNION ALL SELECT    hhmember2 as passengerid, * FROM trip WHERE hhmember2 IS NOT NULL AND hhmember2 <> personid
        UNION ALL SELECT    hhmember3 as passengerid, * FROM trip WHERE hhmember3 IS NOT NULL AND hhmember3 <> personid
        UNION ALL SELECT    hhmember4 as passengerid, * FROM trip WHERE hhmember4 IS NOT NULL AND hhmember4 <> personid
        UNION ALL SELECT    hhmember5 as passengerid, * FROM trip WHERE hhmember5 IS NOT NULL AND hhmember5 <> personid
        UNION ALL SELECT    hhmember6 as passengerid, * FROM trip WHERE hhmember6 IS NOT NULL AND hhmember6 <> personid
        UNION ALL SELECT    hhmember7 as passengerid, * FROM trip WHERE hhmember7 IS NOT NULL AND hhmember7 <> personid
        UNION ALL SELECT    hhmember8 as passengerid, * FROM trip WHERE hhmember8 IS NOT NULL AND hhmember8 <> personid
        UNION ALL SELECT    hhmember9 as passengerid, * FROM trip WHERE hhmember9 IS NOT NULL AND hhmember9 <> personid)
    INSERT INTO trip(hhid, personid, 
		depart_time_timestamp, arrival_time_timestamp,
		dest_name, dest_address, dest_lat, dest_lng,
		trip_path_distance, google_duration, reported_duration,
		hhmember1, hhmember2, hhmember3, hhmember4, hhmember5, hhmember6, hhmember7, hhmember8, hhmember9, hhmember_none, travelers_hh, travelers_nonhh, travelers_total,
		mode_1, mode_2, mode_3, mode_4, change_vehicles, transit_system_1, transit_system_2, transit_system_3,
		park_ride_area_start, park_ride_area_end, park_ride_lot_start, park_ride_lot_end, park, park_type, park_pay,
		toll, toll_pay, taxi_type, taxi_pay, bus_type, bus_pay, bus_cost_dk, ferry_type, ferry_pay, ferry_cost_dk, rail_type, rail_pay, rail_cost_dk, air_type, air_pay, airfare_cost_dk,
		mode_acc, mode_egr, psrc_inserted)
	SELECT -- select fields necessary for new trip records
		t.hhid, t.passengerid AS personid, 
		t.depart_time_timestamp, t.arrival_time_timestamp,
		t.dest_name, t.dest_address, t.dest_lat, t.dest_lng,
		t.trip_path_distance, t.google_duration, t.reported_duration,
		t.hhmember1, t.hhmember2, t.hhmember3, t.hhmember4, t.hhmember5, t.hhmember6, t.hhmember7, t.hhmember8, t.hhmember9, t.hhmember_none, t.travelers_hh, t.travelers_nonhh, t.travelers_total,
		t.mode_1, t.mode_2, t.mode_3, t.mode_4, t.change_vehicles, t.transit_system_1, t.transit_system_2, t.transit_system_3,
		t.park_ride_area_start, t.park_ride_area_end, t.park_ride_lot_start, t.park_ride_lot_end, t.park, t.park_type, t.park_pay,
		t.toll, t.toll_pay, t.taxi_type, t.taxi_pay, t.bus_type, t.bus_pay, t.bus_cost_dk, t.ferry_type, t.ferry_pay, t.ferry_cost_dk, t.rail_type, t.rail_pay, t.rail_cost_dk, t.air_type, t.air_pay, t.airfare_cost_dk,
		t.mode_acc, t.mode_egr, 1 AS psrc_inserted 
	FROM list_passenger_trips as t --keep only those when the time midpoint of the CTE trip doesn't intersect any trip by the same person (whether they reported the other hhmembers or not)
        LEFT JOIN trip as compare_t ON t.passengerid = compare_t.personid AND 
			DATEADD(Second, (DATEDIFF(Second, compare_t.depart_time_timestamp, compare_t.arrival_time_timestamp)/2), compare_t.depart_time_timestamp) 
            BETWEEN t.depart_time_timestamp AND t.arrival_time_timestamp
        WHERE compare_t.personid IS NULL;

		GO
		EXEC tripnum_update; --after adding records, we need to renumber them consecutively
		GO

/* STEP 5a. Flag inconsistencies */

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

	-- Logic Checks

		WITH error_flag_compilation(tripid, personid, tripnum, error_flag) AS
			(SELECT t1.tripid, t1.personid, t1.tripnum, 								'underage driver' AS error_flag
					FROM hhts_agecodes AS age JOIN person AS p ON age.agecode = p.age
						JOIN trip AS t1 ON p.personid = t1.personid
					WHERE t1.driver = 1 AND p.age BETWEEN 1 AND 3
			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum, 					'unlicensed driver' as error_flag
				FROM trip JOIN person AS p ON p.personid=trip.personid
				WHERE p.license = 3 AND trip.driver=1
			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum, 					'non-worker reporting work trip' as error_flag
				FROM trip JOIN person AS p ON p.personid=trip.personid
				WHERE p.worker = 0 AND trip.dest_purpose in(10,11,14)
			UNION ALL SELECT tripid, personid, tripnum, 								'speed unreasonably high' as error_flag
				FROM trip 									
				WHERE 	(mode_1 = 1 AND speed_mph > 20)
					OR 	(mode_1 = 2 AND speed_mph > 40)
					OR 	((mode_1 between 3 and 52 AND mode_1 <> 31) AND speed_mph > 85)
					OR 	(speed_mph > 600)	
			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum,					'no activity time prior to next departure' as error_flag
				FROM trip JOIN trip AS next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 =next_trip.tripnum
				WHERE DATEDIFF(Second, trip.depart_time_timestamp, next_trip.depart_time_timestamp) < 60
			UNION ALL SELECT next_trip.tripid, next_trip.personid, next_trip.tripnum,	'no activity time since prior arrival' as error_flag
				FROM trip JOIN trip AS next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 =next_trip.tripnum
				WHERE DATEDIFF(Second, trip.depart_time_timestamp, next_trip.depart_time_timestamp) < 60
			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum,					'identical location as next trip' as error_flag
				FROM trip JOIN trip AS next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 =next_trip.tripnum
				WHERE trip.geom.STDistance(next_trip.geom) =0
			UNION ALL SELECT next_trip.tripid, next_trip.personid, next_trip.tripnum,	'identical location as prior trip' as error_flag
				FROM trip JOIN trip AS next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 =next_trip.tripnum
				WHERE trip.geom.STDistance(next_trip.geom) =0
			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum,					'time overlap with another trip' as error_flag
				FROM trip JOIN trip AS compare_t ON trip.personid=compare_t.personid AND trip.tripnum + 1 =compare_t.tripnum
				WHERE DATEADD(Second, (DATEDIFF(Second, compare_t.depart_time_timestamp, compare_t.arrival_time_timestamp)/2), compare_t.depart_time_timestamp) 
					BETWEEN trip.depart_time_timestamp AND trip.arrival_time_timestamp AND trip.tripnum < compare_t.tripnum
			UNION ALL SELECT compare_t.tripid, compare_t.personid, compare_t.tripnum,	'time overlap with another trip' as error_flag
				FROM trip JOIN trip AS compare_t ON trip.personid=compare_t.personid AND trip.tripnum + 1 =compare_t.tripnum
				WHERE DATEADD(Second, (DATEDIFF(Second, compare_t.depart_time_timestamp, compare_t.arrival_time_timestamp)/2), compare_t.depart_time_timestamp) 
					BETWEEN trip.depart_time_timestamp AND trip.arrival_time_timestamp AND trip.tripnum < compare_t.tripnum
			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum,					'same transit line listed multiple times' as error_flag
				FROM trip
    			WHERE EXISTS(SELECT count(*) 
								FROM (VALUES(trip.transit_line_1),(trip.transit_line_2),(trip.transit_line_3),(trip.transit_line_4),(trip.transit_line_5)) AS transitline(member) 
								WHERE member IS NOT NULL GROUP BY member HAVING count(*) > 1)
			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum,					'non-home trip purpose, destination home' as error_flag
				FROM trip
				WHERE dest_purpose <> 1 AND dest_is_home = 1
			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum,					'home trip purpose, destination elsewhere' as error_flag
				FROM trip
				WHERE dest_purpose = 1 AND dest_is_home <> 1
			UNION ALL SELECT trip.tripid, trip.personid, trip.tripnum, 					'suspected drop-off or pick-up coded as school trip' as error_flag
				FROM trip 
					JOIN person ON trip.personid=person.personid 
					JOIN trip as next_trip ON trip.personid=next_trip.personid
				WHERE trip.dest_purpose = 6 
					AND trip.tripnum + 1 = next_trip.tripnum
					AND ((person.student NOT IN(2,3,4))
						OR (DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 20)))
		INSERT INTO trip_error_flags (tripid, personid, tripnum, error_flag)
			SELECT tripid, personid, tripnum, error_flag FROM error_flag_compilation;
		GO

/* STEP 5b. Correct for known error patterns */

		DROP TABLE IF EXISTS fixed;
		CREATE TABLE fixed(tripid bigint, personid int, error_flag varchar(100));
		GO

		UPDATE trip --revises purpose field for return portion of a single stop loop trip 
			SET trip.dest_purpose = 1
			OUTPUT INSERTED.tripid, INSERTED.personid, 'non-home trip purpose, destination home' AS error_flag INTO fixed 
			FROM trip 
				JOIN trip AS prev_trip on trip.personid=prev_trip.personid AND trip.tripnum - 1 = prev_trip.tripnum
			WHERE trip.dest_purpose <> 1 and trip.dest_is_home = 1
				AND trip.dest_purpose=prev_trip.dest_purpose;

		UPDATE trip --changes purpose code from school to pickup/dropoff when passenger number changes and duration is under 30 minutes
			SET trip.dest_purpose = 9
			OUTPUT INSERTED.tripid, INSERTED.personid, 'suspected drop-off or pick-up coded as school trip' AS error_flag INTO fixed
			FROM trip 
				JOIN person ON trip.personid=person.personid 
				JOIN trip as next_trip ON trip.hhid=next_trip.hhid AND trip.personid=next_trip.personid AND trip.tripnum + 1 = next_trip.tripnum
			WHERE trip.dest_purpose = 6
				AND trip.travelers_total <> next_trip.travelers_total
				AND DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 40;
		
		UPDATE trip --changes code to 'family activity' when passenger number changes and duration is from 30mins to 4hrs
			SET trip.dest_purpose = 56
			OUTPUT INSERTED.tripid, INSERTED.personid, 'suspected drop-off or pick-up coded as school trip' AS error_flag INTO fixed
			FROM trip 
				JOIN person ON trip.personid=person.personid 
				JOIN trip as next_trip ON trip.personid=next_trip.personid AND trip.tripnum + 1 = next_trip.tripnum
			WHERE trip.dest_purpose = 6
				AND trip.travelers_total <> next_trip.travelers_total
				AND dbo.RgxFind(trip.dest_name,'(school|care)',1) = 1
				AND DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) Between 30 and 240;

		UPDATE tef	SET rulesy_fixed='yes'
			FROM trip_error_flags AS tef JOIN fixed AS f ON tef.tripid=f.tripid AND tef.personid=f.personid AND tef.error_flag=f.error_flag;
		DROP TABLE fixed;	 
		GO

/* STEP 6. Impute missing fields [access/egress, etc] */
	
