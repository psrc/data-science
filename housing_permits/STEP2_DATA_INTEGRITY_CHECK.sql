
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

-- mark old record which has exactly same information as new ones
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

-- mark new record which has exactly same information as old ones
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


-- 3. TYPE 2
-- THE PREVIOUS YEARS' PERMIT RECORDS GOT FINALIZED IN LATEST YEAR 
-- everything is similar to type 1, but street name are different. Most likely, difference in street names is because of typo. Detect the same street, and update the street name info. 
SELECT a.AY_ID, b.AY_ID, a.STRNAME, b.STRNAME, a.TYPE, b.TYPE 
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME != b.STRNAME
AND a.FINALED is null -- could use where at here too
        AND b.FINALED is not null -- FINALIED 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017

-- lower case + get rid of the space between letters, see if one column value is a substring of the other one, and it should beging with index position 0 or 1? 

-- mark new record with better address infor
WITH t AS
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME != b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null -- FINALIED 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
UPDATE Angela.STEP2_17_16
SET CHECK_ = 'TYPE2_NEW_ADDRESS_POSITIVE'
WHERE AY_ID IN(
	SELECT DISTINCT AY_ID_b from t 
	WHERE LOWER(STRNAME_a) LIKE CONCAT('%', LOWER(STRNAME_b), '%')) 
	
-- mark new record with no better address info
WITH t AS
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME != b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null -- FINALIED 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
UPDATE Angela.STEP2_17_16
SET CHECK_ = 'TYPE2_NEW_ADDRESS_NEGATIVE'
WHERE AY_ID IN(
	SELECT DISTINCT AY_ID_b from t 
	WHERE LOWER(STRNAME_b) LIKE CONCAT('%', LOWER(STRNAME_a), '%'))
	

-- mark old record with better address data
WITH t AS -- everytime you have to redefine the t for the new clause
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME != b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null -- FINALIZED
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
UPDATE Angela.STEP2_17_16
SET CHECK_ = 'TYPE2_OLD_POSITIVE'
WHERE AY_ID IN(
	SELECT DISTINCT AY_ID_a from t 
	WHERE LOWER(STRNAME_b) LIKE CONCAT('%', LOWER(STRNAME_a), '%'))

-- mark old record no better address
WITH t AS -- everytime you have to redefine the t for the new clause
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME != b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null -- FINALIED 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
UPDATE Angela.STEP2_17_16
SET CHECK_ = 'TYPE2_OLD_NEGATIVE'
WHERE AY_ID IN(
	SELECT DISTINCT AY_ID_a from t 
	WHERE LOWER(STRNAME_a) LIKE CONCAT('%', LOWER(STRNAME_b), '%'))


-- TYPE 4: 
SELECT a.NOTES, b.NOTES
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.PERMITNO != b.PERMITNO AND a.TYPE = b.TYPE AND a.JURIS = b.JURIS17  AND a.UNITS = b.UNITS 
WHERE a.FINALED is null 
        AND b.FINALED is not null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017




















