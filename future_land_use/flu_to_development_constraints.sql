/* Convert FLU GIS file to UrbanSim development_constraints table 
	Key steps: 	1. group geographies into plan_types
			2. geographically assign each parcel a plan_type
			3. unroll plan_types to create development_constraints
*/

--0. Prep steps

	USE SANDBOX; --substitute with whatever db the flu_for_dc table is in
    GO

--1a. Group geographies into plan_type equivalents with a new auto-generated plan_type_id
	CREATE TABLE plan_types as
	SELECT row_number() OVER (ORDER BY round(flu_for_dc.max_du_ac,3) + round(flu_for_dc.max_far,2) DESC) AS plan_type_id,
			round(flu_for_dc.min_du_ac,3) as du_ac_min,
			round(flu_for_dc.max_du_ac,3)as du_ac_max,
			round(flu_for_dc.min_far,2) as far_min,
			round(flu_for_dc.max_far,2) as far_max,
			round(val(max_height_ft),0) as max_height_ft,
			flu_for_dc.res_use,
			flu_for_dc.comm_use,
			flu_for_dc.retail_use,
			flu_for_dc.indust_use,
			flu_for_dc.mixed_use
	FROM flu_for_dc
	WHERE (flu_for_dc.max_du_ac + flu_for_dc.max_far) > 0
	GROUP BY round(flu_for_dc.min_du_ac,3), round(flu_for_dc.max_du_ac,3), round(flu_for_dc.min_far,2), round(flu_for_dc.max_far,2), flu_for_dc.res_use, flu_for_dc.comm_use, flu_for_dc.retail_use, flu_for_dc.indust_use, flu_for_dc.mixed_use;

--1b. Assigns a default value for lockouts. Currently 1000, but ideally should be outside the natural sequence range
	ALTER TABLE flu_for_dc drop column if exists plan_type_id; 
	ALTER TABLE flu_for_dc ADD COLUMN plan_type_id SMALLINT;
	UPDATE flu_for_dc as t1
			SET plan_type_id = 1000 WHERE t1.max_du_ac = 0 and t1.max_far = 0;
	UPDATE flu_for_dc as t1
			SET plan_type_id = 1000 WHERE t1.res_use='N' and t1.comm_use='N' and t1.retail_use='N' and t1.indust_use='N' and t1.mixed_use='N';
			
--1c. Carry new plan_type_ids back to the FLU geography file
	UPDATE flu_for_dc as t1
			SET plan_type_id = t2.plan_type_id from plan_types as t2
	WHERE t2.plan_type_id <> 1000
			and round(t1.min_du_ac,3)=t2.du_ac_min 
			and round(t1.max_du_ac,3)=t2.du_ac_max
			and round(t1.min_far,2)=t2.far_min
			and round(t1.max_far,2)=t2.far_max
			and t1.res_use=t2.res_use
			and t1.comm_use=t2.comm_use
			and t1.retail_use=t2.retail_use
			and t1.indust_use=t2.indust_use
			and t1.mixed_use=t2.mixed_use;
		
	CREATE INDEX plan_type_id_index ON flu_for_dc(plan_type_id);

/* THIS IS FASTER WHEN DONE IN ArcGIS--export the flu_for_dc file with the new plan_type_ids and match to prcl15_4kpt.
--2. Create an updated parcel-plan_type correspondence [SPATIAL JOIN] with which to update the parcels table.  Can be done on polygon using ST_Centroid(), but is slower. Check GiST indexing & allow sufficient memory/time.
	CREATE TABLE prcl_plan_type AS
	   SELECT t1.parcel_id, t2.plan_type_id
	   FROM prcl15_4kpt AS t1 LEFT JOIN flu_for_dc AS t2 ON t1.county_id=t2.county_id AND ST_CoveredBy(t1.geom,t2.geom);
*/

--3a. Unroll constraints from plan_type; SFR & MFR boundaries use a density assumption.
	CREATE TABLE development_constraints AS
	SELECT t1.plan_type_id, t1.du_ac_min as minimum, t1.du_ac_max as maximum, 1 AS generic_land_use_type_id, 'units_per_acre' AS constraint_type
	FROM plan_types AS t1 WHERE t1.res_use='Y' AND t1.du_ac_max < 35.1
   UNION ALL 
	SELECT t1.plan_type_id, t1.du_ac_min as minimum, t1.du_ac_max as maximum, 2 AS generic_land_use_type_id, 'units_per_acre' AS constraint_type
	FROM plan_types AS t1 WHERE t1.res_use='Y' AND t1.du_ac_max > 11.9
   UNION ALL
	SELECT t1.plan_type_id, t1.far_min as minimum, t1.far_max as maximum, 3 AS generic_land_use_type_id, 'far' AS constraint_type
	FROM plan_types AS t1 WHERE t1.comm_use='Y'
   UNION ALL
	SELECT t1.plan_type_id, t1.far_min as minimum, t1.far_max as maximum, 4 AS generic_land_use_type_id, 'far' AS constraint_type
	FROM plan_types AS t1 WHERE t1.comm_use='Y' OR t1.retail_use='Y'
   UNION ALL
	SELECT t1.plan_type_id, t1.far_min as minimum, t1.far_max as maximum, 5 AS generic_land_use_type_id, 'far' AS constraint_type
	FROM plan_types AS t1 WHERE t1.indust_use='Y' 
   UNION ALL
	SELECT t1.plan_type_id, t1.far_min as minimum, t1.far_max as maximum, 6 AS generic_land_use_type_id, 'far' AS constraint_type
	FROM plan_types AS t1 WHERE t1.mixed_use='Y'
   UNION ALL SELECT 1000, 0, 0, 1, 'units_per_acre'	
   UNION ALL SELECT 1000, 0, 0, 2, 'units_per_acre'
   UNION ALL SELECT 1000, 0, 0, 3, 'far';
	ALTER TABLE development_constraints ADD constraint_id int NOT NULL IDENTITY PRIMARY KEY;

/* This block only necessary when there are holes in the FLU; it carries over constraints for the missing geographies (renumbering the rump set 1000+x so as not to conflict with the new ones). Best to avoid this with a comprehensive FLU, so information doesn't remain hidden in the development_constraints table.

   CREATE TABLE carryover_plan_type_lookup as
	SELECT row_number() OVER (ORDER BY t1.plan_type_id DESC) +1000 as new_plan_type, t1.plan_type_id as old_plan_type
	from parcels_20160504 as t1 JOIN prcl_plan_type as t2 ON t1.parcel_id=t2.parcel_id WHERE t2.plan_type_id IS NULL;
	group by t1.plan_type_id;
   CREATE INDEX carryover_plan_type_lookup_new_plan_type_idx ON sandbox_mjj.carryover_plan_type_lookup (new_plan_type,old_plan_type);
	
   UPDATE prcl15_4kpt
			SET plan_type_id=t1.new_plan_type
	FROM carryover_plan_type_lookup AS t1 JOIN parcels_20160504 AS t2 ON t1.old_plan_type=t2.plan_type_id
	WHERE prcl15_4kpt.parcel_id=t2.parcel_id AND prcl15_4kpt.plan_type_id IS NULL;

   INSERT INTO development_constraints (plan_type_id, minimum, maximum, generic_land_use_type_id, constraint_type)
	SELECT t2.new_plan_type, t1.minimum, t1.maximum, t1.generic_land_use_type_id, t1.constraint_type 
	FROM development_constraints_20160413 AS t1 JOIN carryover_plan_type_lookup AS t2 ON t1.plan_type_id=t2.old_plan_type;


 --3b. Keep only constraints that are geographically assigned to at least one parcel.
	CREATE TABLE plan_types_in_use AS SELECT plan_type_id FROM parcels GROUP BY plan_type_id;
	DELETE FROM development_constraints
		USING development_constraints AS dc
		LEFT OUTER JOIN plan_types_in_use AS t1 ON dc.plan_type_id = t1.plan_type_id
	  WHERE
   		development_constraints.plan_type_id = dc.plan_type_id AND
		t1.plan_type_id is null;
*/