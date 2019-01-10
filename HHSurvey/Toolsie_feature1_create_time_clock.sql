SELECT 
hhid, personid, pernum, tripid, tripnum, 
traveldate, dayofweek, depart_time_mam, arrival_time_mam, reported_duration
origin_name, dest_name, origin_purpose, dest_purpose, mode_1,
origin_lat, origin_lng, dest_lat, dest_lng, trip_path_distance
from MIKE.trip
-- use three household as a testing sample
where hhid  = 17100005 or hhid = 17100024 or hhid = 17100059


SELECT
hhid, personid, pernum, traveldate, relationship,
age, gender, employment, student, license
FROM MIKE.person
where hhid  = 17100005 or hhid = 17100024 or hhid = 17100059


SELECT
hhid, hhsize, vehicle_count, numadults, numchildren, hhincome_detailed
from Mike.household
where hhid  = 17100005 or hhid = 17100024 or hhid = 17100059


-- to make a perfect clock circle for every person in the household we have to create a time_mam_clock
-- the clock is fillbed by minutes 0 to 1440
-- I found it is a bit challenging to auto fill the values within SQL, so I will do it in the excel table outside of the SQL 

-- Create a new table called '[time_mam_clock]' in schema '[dbo]'
-- Drop the table if it already exists
IF OBJECT_ID('[dbo].[time_mam_clock]', 'U') IS NOT NULL
DROP TABLE [dbo].[time_mam_clock]
GO
-- Create the table in the specified schema
CREATE TABLE [dbo].[time_mam_clock]
(
    [Id] INT NOT NULL PRIMARY KEY, -- Primary Key column
    [pernum] INT NOT NULL,
    [time_mam] INT NOT NULL,
    -- Specify more columns here
);
GO

select * from dbo.time_mam_clock;

INSERT INTO 
 dbo.time_mam_clock(Id, pernum, time_mam)
VALUES
 (1,1,1),
 (2,1,2);
