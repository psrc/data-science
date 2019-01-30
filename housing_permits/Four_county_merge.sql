
-- goal: compare previous data and delete the DUPLICATED permits (duplicated is based on specific crateries)

-- Step 0: combine all four county permit

-- Create a new stored procedure called 'merge_four_counties' in schema 'Angela'
-- Drop the stored procedure if it already exists
IF EXISTS (
SELECT *
    FROM INFORMATION_SCHEMA.ROUTINES
WHERE SPECIFIC_SCHEMA = N'Angela'
    AND SPECIFIC_NAME = N'merge_four_counties'
)
DROP PROCEDURE Angela.merge_four_counties
GO
-- Create the stored procedure in the specified schema
CREATE PROCEDURE Angela.merge_four_counties
    @param1 /*parameter name*/ int /*datatype_for_param1*/ = 0, /*default_value_for_param1*/
    @param2 /*parameter name*/ int /*datatype_for_param1*/ = 0 /*default_value_for_param2*/
-- add more stored procedure parameters here
AS
    -- body of the stored procedure
    SELECT PSRCIDN, PERMITNO, SORT, MULTIREC, PIN, ADDRESS, HOUSENO, PREFIX, STRNAME, STRTYPE, SUFFIX, UNIT_BLD, ZIP, 
ISSUED, FINALED, STATUS, TYPE, PS, UNITS, BLDGS, LANDUSE, CONDO, VALUE, ZONING, NOTES, NOTES2, NOTES3, NOTES4, NOTES5, NOTES6, NOTES7, 
LOTSIZE, JURIS, JURIS15, PLC, PLC15, PROJYEAR, CNTY, MULTCNTY, PSRCID, PSRCIDXY, X_COORD, Y_COORD, RUNTYPE, CHECK_DUPLICATED, PIN_PARENT, COUNTY, 
TRACTID, BLKGRPID, BLKID, UGA, TAZ10, TAZ4K, FAZ10
    INTO Angela.FOUR_COUNTIES_17
FROM 
(
    SELECT * FROM Angela.KING_33_17 
    UNION ALL 
    SELECT * FROM Angela.KITSAP_35_17
    UNION ALL
    SELECT * FROM ANGELA.PIERCE_53_17
    UNION ALL
    SELECT * FROM ANGELA.SNOHOMISH_61_17
) as FOUR_COUNTIES_17
-- example to execute the stored procedure we just created
EXECUTE Angela.merge_four_counties 1 /*value_for_param1*/, 2 /*value_for_param2*/
GO





