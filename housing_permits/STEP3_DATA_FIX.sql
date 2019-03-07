'''
TASK: COMBINE DUPLICATED RECORDS, UPDATE THE LATEST GREATEST INFORMATION, DELETE THE RECORDS

'''


SELECT * INTO Angela.STEP3_17_16 FROM Angela.STEP2_17_16

-- 1. UPDATE GOOD ADDRESS TO 2017
-- add a new column into the data and called it: STRNAME_NEW
-- update this new column to the selected value from street names, this process should be in the next step 


ALTER TABLE Angela.STEP3_17_16
ADD STRENAME_NEW nvarchar(255)




WITH t AS 
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP3_17_16 a 
INNER JOIN Angela.STEP3_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME != b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
UPDATE Angela.STEP3_17_16
SET STRENAME_NEW = 
(SELECT 
     CASE WHEN LEN(STRNAME_a) > LEN(STRNAME_b) THEN STRNAME_a
     WHEN LEN(STRNAME_a) < LEN(STRNAME_b) THEN STRNAME_b
	 ELSE STRNAME_b
     END
FROM t -- THIS PART  has 87 rows 
)
WHERE AY_ID IN -- this part has 85 rows 
(SELECT DISTINCT AY_ID_b
FROM t)


WITH t AS 
(SELECT a.AY_ID AS AY_ID_a, b.AY_ID AS AY_ID_b, a.STRNAME AS STRNAME_a, b.STRNAME AS STRNAME_b
FROM Angela.STEP3_17_16 a 
INNER JOIN Angela.STEP3_17_16 b ON a.JURIS = b.JURIS17 AND a.ISSUED = b.ISSUED AND a.UNITS = b.UNITS AND a.HOUSENO = b.HOUSENO AND a.STRNAME != b.STRNAME
WHERE a.FINALED is null 
        AND b.FINALED is not null 
        AND a.PROJYEAR != 2017
        AND b.PROJYEAR = 2017) 
select *
FROM t
where AY_ID_b in (
SELECT AY_ID_b from t 
group by AY_ID_b
HAVING Count(AY_ID_b) > 1)

















