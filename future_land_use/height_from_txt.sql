-- Queries to change FLU coverage and height from text to numeric fields

ALTER TABLE ADD max_coverage decimal(4,3),
            ADD max_height_ft tinyint,
            add height_imputed bit NOT NULL DEFAULT 0;

UPDATE dbo.flu_for_dc SET maxcoverag = NULL WHERE maxcoverag IN('0','NA');

UPDATE dbo.flu_for_dc SET max_coverage = (CAST(maxcoverag AS FLOAT))
    WHERE maxcoverag LIKE '%0.%' AND (CAST(maxcoverag AS FLOAT)) < 1; 

UPDATE dbo.flu_for_dc SET max_coverage = CASE
        WHEN maxcoverag IN('0','NA') THEN NULL
        WHEN maxcoverag LIKE '%0.%' AND (CAST(maxcoverag AS FLOAT)) < 1 THEN (CAST(maxcoverag AS FLOAT))  --i.e. reported as decimal
        WHEN max_coverage IS NULL AND (dbo.RgxFind(maxcoverag,'^\d+$',1)=1 OR dbo.RgxFind(maxcoverag,'%',1) = 1) THEN Round((CAST(dbo.RgxExtract(maxcoverag,'^\d+$',1) AS FLOAT))/100,3) --i.e. reported as percentage
        ELSE NULL
        END;

UPDATE dbo.flu_for_dc SET max_height_ft = CASE
        WHEN (dbo.RgxExtract(max_height,'(ft|feet)',1)=1 OR dbo.RgxExtract(max_height,'^\d+$',1)=1) THEN dbo.RgxExtract(max_height,'^\d+',1)    --reported in feet
        WHEN dbo.RgxExtract(max_height,'^\d+ ?stor',1)=1 THEN dbo.RgxExtract(max_height,'^\d+',1) * 11                                          --reported in stories
        WHEN max_coverage IS NOT NULL and max_far > 0 THEN max_coverage * max_far * 11                                                          --calculated from coverage and floor area ratio
        ELSE NULL
        END;

UPDATE dbo.flu_for_dc SET max_height_ft = ROUND((SELECT MAX(value_set) FROM (VALUES (20 * max_FAR),(15 * sqrt(max_du_ac)),(35)) AS x(value_set)),0), height_imputed = 1
    WHERE max_height_ft IS NULL;

--summarize by plan_type_id when plan_type_ids aren't specific to height (i.e., as happened prior to UrbanSim2 implementation)
SELECT  plan_type_id, 
        CASE 
            WHEN MIN(height_imputed)=0 THEN MAX((height_imputed-1) * max_height_ft * -1)
            WHEN MIN(height_imputed)=1 THEN MAX(max_height_ft)
            END 
        AS max_height_ft,
        CASE 
            WHEN MIN(height_imputed)=0 THEN 0 ELSE 1 END 
        AS imputed 
FROM dbo.flu_for_dc GROUP BY plan_type_id ORDER BY plan_type_id;