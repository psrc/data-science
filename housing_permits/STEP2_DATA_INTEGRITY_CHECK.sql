
'''
TASK: 
this script is to modify the duplicated records, where current year is duplicated with previour years record.

BACKGROUND INFORMATION: 
reasons for duplicated records are vaiours. 
One of it could be some pemits issued in preciou years are finalized in current year. so we want to update the previous year to latest year. and delete the previous records.
Another reason could be permit filer want to update some part of permit (unit numbers, value, housing type...); so we want to capture this. 

MY SCRIPTING LOGIC:
1: query to update columns: delete,  oldpermit.check, newpermit.check
2: select "yes" in new record portion, if all columns are updated
3: if select "yes" in old record portion, if the record is duplicated with the new ones; query through -  issue date, unit, sortid(maybe)
4: check the rows, which have two yeses. update the old record to new ones, 
   NOTICE: AT this point, do not simply delete the old records! 
           please modify the record by combining the most accurate info from old to one! some times old record could be more valuable than new ones. 
5: check yes, in the old records (or maybe new records), after combined the information to the other rows. 

'''

-- COPY PASTE THE CONTENT FROM THE VIEW, CREATED FROM STEP1, TO THIS TASK. And the new table will be my working table.
SELECT * INTO Angela.STEP2_17_16 FROM Angela.merged_view


ALTER TABLE Angela.STEP2_17_16
ALTER COLUMN DELETE_ NVARCHAR(500)
ALTER TABLE Angela.STEP2_17_16
ALTER COLUMN CHECK_ NVARCHAR(500)

-- 1：CREATE A UNIQUE ID FOR EVERY RECORD
-- so we can easily call records 

ALTER TABLE Angela.STEP2_17_16
        ADD AY_ID INT IDENTITY 

ALTER TABLE Angela.STEP2_17_16
        ADD CONSTRAINT PK_STEP2_17_16
        PRIMARY KEY(AY_ID)

-- 2. TYPE 1, 
-- THE PREVIOUS YEARS' PERMIT RECORDS GOT FINALIZED IN LATEST YEAR 
-- no change in units
-- same issued date
-- same jurisdiction
-- same location: street number and name are same; 
UPDATE Angela.STEP2_17_16
SET CHECK_ = 'TYPE1_OLD'
WHERE AY_ID IN 
(SELECT a.AY_ID
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME = b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017
)

UPDATE Angela.STEP2_17_16
SET CHECK_ = 'TYPE1_NEW'
WHERE AY_ID IN 
(SELECT b.AY_ID
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME = b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017
)

-- To process difference in street names but they actually mean the same street: 
SELECT a.AY_ID, b.AY_ID, a.STRNAME, b.STRNAME 
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME != b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017

-- lower case + get rid of the space between letters, see if one column value is a substring of the other one, and it should beging with index position 0 or 1? 

WITH t AS
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME != b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
UPDATE Angela.STEP2_17_16
SET CHECK_ = 'TYPE1_NEW'
WHERE AY_ID IN(
	SELECT AY_ID_b from t 
	WHERE LOWER(STRNAME_a) LIKE CONCAT('%', LOWER(STRNAME_b), '%') OR LOWER(STRNAME_b) LIKE CONCAT('%', LOWER(STRNAME_a), '%'))


WITH t AS -- everytime you have to redefine the t for the new clause
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME != b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
UPDATE Angela.STEP2_17_16
SET CHECK_ = 'TYPE1_OLD'
WHERE AY_ID IN(
	SELECT AY_ID_a from t 
	WHERE LOWER(STRNAME_a) LIKE CONCAT('%', LOWER(STRNAME_b), '%') OR LOWER(STRNAME_b) LIKE CONCAT('%', LOWER(STRNAME_a), '%'))

-- fix the addresses if needed 

-- add a new column into the data and called it: STRNAME_NEW
-- update this new column to the selected value from street names, this process should be in the next step (fix bugs in data)

ALTER TABLE Angela.STEP2_17_16
ADD STRENAME_NEW nvarchar(255)

WITH t AS -- everytime you have to redefine the t for the new clause
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME != b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
SELECT *,
CASE WHEN LEN(STRNAME_a) > LEN(STRNAME_b) THEN STRNAME_a
     WHEN LEN(STRNAME_a) < LEN(STRNAME_b) THEN STRNAME_b
	 ELSE STRNAME_b
END AS test
FROM t























