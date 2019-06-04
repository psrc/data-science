'''
TASK: COMBINE DUPLICATED RECORDS, UPDATE THE LATEST GREATEST INFORMATION, DELETE THE RECORDS

'''


SELECT * INTO Angela.STEP3_17_16 FROM Angela.STEP2_17_16

SELECT DISTINCT DELETE_, COUNT(*) 
FROM Angela.STEP3_17_16
GROUP BY DELETE_

SELECT DISTINCT CHECK_, COUNT(*) 
FROM Angela.STEP3_17_16
GROUP BY CHECK_

-- STEP 1: mark the old record which duplicated with new record
-- FOR THE ADDRESS AND SORT ARE ALL SAME 
-- TYPE 2 ADDRESS GOT UPDATED
UPDATE Angela.STEP3_17_16
SET DELETE_ = 1
FROM Angela.STEP3_17_16
WHERE CHECK_ = 'TYPE2_NEW_ADDRESS_NEGATIVE'  -- WE GET 3 RECORD HERE 


SELECT DISTINCT CHECK_, COUNT(*) as count_permit, SUM(UNITS) as sum_unit
FROM Angela.STEP3_17_16
GROUP BY CHECK_

-- TYPE3 THREE ISSUED PERMIT GOT FINALIZED 
UPDATE Angela.STEP3_17_16
SET CHECK_ = 'TYPE3_NEW' -- GET 1687 RECORDS
WHERE AY_ID IN 
(SELECT b.AY_ID
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME = b.STRNAME and a.SORT = b.SORT
WHERE a.FINALED is null 
        AND b.FINALED is not null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017
)


UPDATE Angela.STEP3_17_16
SET CHECK_ = 'TYPE3_OLD' -- GET 1695 RECORDS
WHERE AY_ID IN 
(SELECT a.AY_ID
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME = b.STRNAME and a.SORT = b.SORT
WHERE a.FINALED is null 
        AND b.FINALED is not null -- FINALIZED 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017
)

-- TYPE 4: ISSUED PERMIT GOT UPDATED 
UPDATE Angela.STEP3_17_16
SET CHECK_ = 'TYPE4_OLD' -- GET 1695 RECORDS
WHERE AY_ID IN 
(SELECT a.AY_ID
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME = b.STRNAME and a.SORT = b.SORT
WHERE a.FINALED is null 
        AND b.FINALED is null --NOT FINALIZED YET
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017
)


UPDATE Angela.STEP3_17_16
SET CHECK_ = 'TYPE4_NEW' -- GET 1695 RECORDS
WHERE AY_ID IN 
(SELECT b.AY_ID
FROM Angela.STEP2_17_16 a 
INNER JOIN Angela.STEP2_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME = b.STRNAME and a.SORT = b.SORT
WHERE a.FINALED is null 
        AND b.FINALED is null --FINALIZED
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017
)


-- COUNT CHECK 
SELECT DISTINCT CHECK_, COUNT(*) 
FROM Angela.STEP3_17_16
GROUP BY CHECK_



-- mark the delete column 
UPDATE Angela.STEP3_17_16
SET DELETE_ = 1 
WHERE CHECK_ = 'TYPE3_OLD' OR CHECK_ = 'TYPE4_OLD' OR CHECK_ = 'TYPE2_NEW_ADDRESS_NEGATIVE'


-- COUNT CHECK 
SELECT CHECK_, DELETE_
FROM Angela.STEP3_17_16
WHERE CHECK_ = 'TYPE2_NEW_ADDRESS_NEGATIVE'



-- code TYPE2,3,4 PS2
 '''
 step 15.	
 Update the TYPE2, TYPE3, TYPE4, and PS2 fields via joins to the aTYPE and aPS tables on the TYPE and PS fields, respectively. 
 Manually enter correct values where an automatic update cannot be run.
 '''

UPDATE Angela.STEP3_17_16
SET TYPE2 = 
CASE 
        WHEN PROJYEAR = 2017 AND TYPE = 111 THEN 'SF'
        WHEN PROJYEAR = 2017 AND TYPE >= 121 AND TYPE <= 144 THEN 'MF'
        WHEN PROJYEAR = 2017 AND TYPE >= 151 AND TYPE <= 159 THEN 'GQ'
        WHEN PROJYEAR = 2017 AND TYPE = 160 THEN 'MF'
        WHEN PROJYEAR = 2017 AND TYPE = 170 THEN 'MH'
        WHEN PROJYEAR = 2017 AND TYPE >= 181 AND TYPE <= 189 THEN 'TL'
        WHEN PROJYEAR = 2017 AND TYPE = 191 THEN 'MH'
        WHEN PROJYEAR = 2017 AND TYPE = 192 THEN 'OTH'
        WHEN PROJYEAR = 2017 AND TYPE = 194 THEN 'MH'
        WHEN PROJYEAR = 2017 AND TYPE = 199 THEN 'OTH'
        ELSE '999'
END


UPDATE Angela.STEP3_17_16
SET TYPE3 = 
CASE 
        WHEN PROJYEAR = 2017 AND TYPE = 111 THEN 'SF'
        WHEN PROJYEAR = 2017 AND TYPE >= 121 AND TYPE <= 123 THEN 'MF1-4'
        WHEN PROJYEAR = 2017 AND TYPE >= 131 AND TYPE <= 144 THEN 'MF5+'
        WHEN PROJYEAR = 2017 AND TYPE >= 151 AND TYPE <= 159 THEN 'GQ'
        WHEN PROJYEAR = 2017 AND TYPE = 170 THEN 'MH'
        WHEN PROJYEAR = 2017 AND TYPE >= 181 AND TYPE <= 189 THEN 'TL'
        WHEN PROJYEAR = 2017 AND TYPE = 191 THEN 'MH'
        WHEN PROJYEAR = 2017 AND TYPE = 192 THEN 'OTH'
        WHEN PROJYEAR = 2017 AND TYPE = 194 THEN 'MH'
        WHEN PROJYEAR = 2017 AND TYPE = 199 THEN 'OTH'
        ELSE '999'
END



UPDATE Angela.STEP3_17_16
SET TYPE4 = 
CASE 
        WHEN PROJYEAR = 2017 AND TYPE = 111 THEN 'SF'
        WHEN PROJYEAR = 2017 AND TYPE = 121 THEN 'MF1-2'
        WHEN PROJYEAR = 2017 AND TYPE >= 131 AND TYPE <= 144 THEN 'MF5+'
        WHEN PROJYEAR = 2017 AND TYPE >= 151 AND TYPE <= 159 THEN 'GQ'
        WHEN PROJYEAR = 2017 AND TYPE = 170 THEN 'MH'
        WHEN PROJYEAR = 2017 AND TYPE >= 181 AND TYPE <= 189 THEN 'TL'
        WHEN PROJYEAR = 2017 AND TYPE = 191 THEN 'MH'
        WHEN PROJYEAR = 2017 AND TYPE = 192 THEN 'OTH'
        WHEN PROJYEAR = 2017 AND TYPE = 194 THEN 'MH'
        WHEN PROJYEAR = 2017 AND TYPE = 199 THEN 'OTH'
        ELSE '999'
END





SELECT *
FROM ANGELA.STEP3_17_16
WHERE PROJYEAR = 2017 






SELECT COUNT(*), TYPE
FROM ANGELA.STEP3_17_16
WHERE PROJYEAR = 2017
GROUP BY TYPE










--############# STEP 2: UPDATE THE ADDRESS BASED ON OLD AND NEW INFO
-- FOR THE STREET ADDRESS ARE DIFFERENT, BUT SORT ARE SAME 
ALTER TABLE Angela.STEP3_17_16
ADD STRENAME_NEW nvarchar(255)



-- UPDATE GOOD ADDRESS TO final dataset (it could be 2017's or previous years' record )
-- add a new column into the data and called it: STRNAME_NEW
-- update this new column to the selected value from street names, this process should be in the next step 



WITH t AS 
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP3_17_16 a 
INNER JOIN Angela.STEP3_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME != b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
UPDATE Angela.STEP3_17_16
SET STRENAME_NEW = -- update the new street name to the longer name
(
     CASE WHEN LEN(STRNAME_a) > LEN(STRNAME_b) THEN STRNAME_a
          WHEN LEN(STRNAME_a) < LEN(STRNAME_b) THEN STRNAME_b
	  ELSE STRNAME_b
     END
)
FROM t -- THIS PART  has 87 rows 
WHERE AY_ID IN -- this part has 85 rows 
(SELECT DISTINCT AY_ID_b
FROM t)


-- 2. MARK THE RECORDS THAT ARE UPLICATED 
-- use different column combinations to check if the records are same 

ALTER TABLE Angela.STEP3_17_16
ADD DUPLICATED_YEAR nvarchar(255)


-- TYPE1: the permit got finalized in 2017
-- update 2017 record
WITH t AS 
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP3_17_16 a 
INNER JOIN Angela.STEP3_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME == b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
UPDATE Angela.STEP3_17_16
SET DUPLICATED_YEAR = PROJYEAR -- update the duplicated year info to be projected year
FROM t -- THIS PART  has 87 rows 
WHERE AY_ID IN -- this part has 85 rows 
(SELECT DISTINCT AY_ID_b
FROM t)

-- check : there are 85 records here 
select DISTINCT duplicated_year, count(*) 
from Angela.STEP3_17_16
group by duplicated_year


-- update previous years record
WITH t AS 
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP3_17_16 a 
INNER JOIN Angela.STEP3_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME == b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
UPDATE Angela.STEP3_17_16
SET DUPLICATED_YEAR = PROJYEAR -- update the duplicated year info to be projected year
FROM t -- THIS PART  has 87 rows 
WHERE AY_ID IN -- this part has 85 rows 
(SELECT DISTINCT AY_ID_a
FROM t)

-- check : there are 85 records here 
select DISTINCT duplicated_year, count(*) 
from Angela.STEP3_17_16
group by duplicated_year




--##### TYPE 2: the permit got updated in 2017, but NOT finalzied yet 
-- update 2017 record
WITH t AS 
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP3_17_16 a 
INNER JOIN Angela.STEP3_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.SORT = b.SORT
WHERE a.FINALED is null 
        AND b.FINALED is null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
UPDATE Angela.STEP3_17_16
SET DUPLICATED_YEAR = PROJYEAR -- update the duplicated year info to be projected year
FROM t -- THIS PART  has 87 rows 
WHERE AY_ID IN -- this part has 85 rows 
(SELECT DISTINCT AY_ID_b -- current year is in b table 
FROM t)

-- check : there are 2 records here 
select DISTINCT duplicated_year, count(*) 
from Angela.STEP3_17_16
group by duplicated_year


-- update previous years
WITH t AS 
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP3_17_16 a 
INNER JOIN Angela.STEP3_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.SORT = b.SORT
WHERE a.FINALED is null 
        AND b.FINALED is null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
UPDATE Angela.STEP3_17_16
SET DUPLICATED_YEAR = PROJYEAR -- update the duplicated year info to be projected year
FROM t -- THIS PART  has 87 rows 
WHERE AY_ID IN -- this part has 85 rows 
(SELECT DISTINCT AY_ID_a -- previous year is in a table
FROM t)

-- check : there are 2 records here 
select DISTINCT duplicated_year, count(*) 
from Angela.STEP3_17_16
group by duplicated_year


-- TYPE 3: 
WITH t AS 
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP3_17_16 a 
INNER JOIN Angela.STEP3_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS == b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME != b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
UPDATE Angela.STEP3_17_16
SET DUPLICATED_YEAR = PROJYEAR -- update the duplicated year info to be projected year
FROM t -- THIS PART  has 87 rows 
WHERE AY_ID IN -- this part has 85 rows 
(SELECT DISTINCT AY_ID_b
FROM t)













