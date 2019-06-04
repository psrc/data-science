-- error
select * from mike.trip_error_flags

select rulesy_fixed, count(*)
from mike.trip_error_flags
group by rulesy_fixed -- everything is a no 


create view SUM1_error as
select error_flag, count(*) as C, count(distinct tripid) as C_distinct_trip, count(distinct personid) as C_distinct_person
from mike.trip_error_flags
group by error_flag


-- trip

select *
from mike.trip

select * 
from mike.person

create view SUM2_error_trip as
select a.tripid, a.personid, a.tripnum, a.error_flag,  b.hhid, b.pernum, b.traveldate, b.daynum, b.dayofweek, b.hhgroup, b.depart_time_mam, b.arrival_time_mam, 
b.origin_lat, b.origin_lng, b.dest_lat, b.dest_lng, b.trip_path_distance, b.google_duration, b.reported_duration, b.travelers_hh, b.travelers_nonhh, b.travelers_total, 
b.origin_purpose, b.dest_purpose, b.mode_1, b.mode_2, b.mode_3, b.mode_4, b.driver, b.dest_is_home, b.dest_is_work, b.modes, b.transit_lines
from mike.trip_error_flags a
left join mike.trip b on a.tripid = b.tripid


select distinct reference
from Mike.data2toolsie_prev_next



select * 
from Mike.data2toolsie_prev_next


select * 
from Mike.data2toolsie_t

select * 
from Mike.data2toolsie_hh


select *
from Mike.trip






