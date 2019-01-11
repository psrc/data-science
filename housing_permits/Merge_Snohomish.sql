-- Create a new stored procedure called 'MergeSnohomish' in schema 'dbo'
-- Drop the stored procedure if it already exists
IF EXISTS (
SELECT *
    FROM INFORMATION_SCHEMA.ROUTINES
WHERE SPECIFIC_SCHEMA = N'dbo'
    AND SPECIFIC_NAME = N'MergeSnohomish'
)
DROP PROCEDURE dbo.MergeSnohomish
GO

-- Create the stored procedure in the specified schema
CREATE PROCEDURE dbo.MergeSnohomish
    @param1 /*parameter name*/ int /*datatype_for_param1*/ = 0, /*default_value_for_param1*/
    @param2 /*parameter name*/ int /*datatype_for_param1*/ = 0 /*default_value_for_param2*/
-- add more stored procedure parameters here
AS
    -- body of the stored procedure
SELECT * FROM Angela.ARLINGTON17 
UNION ALL 
SELECT * FROM Angela.BOTHELL117
UNION ALL
SELECT * FROM ANGELA.BOTHELL217
UNION ALL
SELECT * FROM ANGELA.BRIER17
UNION ALL 
SELECT * FROM Angela.DARRINGTON17
UNION ALL
SELECT * FROM ANGELA.EDMONDs17
UNION ALL
SELECT * FROM ANGELA.EVERETT17
UNION ALL
SELECT * FROM ANGELA.GOLDBAR17
UNION ALL 
SELECT * FROM Angela.GRANITEFALLS17
UNION ALL
SELECT * FROM ANGELA.LAKESTEVENS17
UNION ALL
SELECT * FROM ANGELA.LYNNWOOD17
UNION ALL
SELECT * FROM ANGELA.MARYSVILLE17
UNION ALL
SELECT * FROM ANGELA.MILLCREEK17
UNION ALL 
SELECT * FROM Angela.MONROE17
UNION ALL
SELECT * FROM ANGELA.SNOHOMISH17
UNION ALL
SELECT * FROM ANGELA.STANWOOD17
UNION ALL
SELECT * FROM ANGELA.UNINCORPORATEDSNOHOMISH17
UNION ALL 
SELECT * FROM Angela.WOODWAY17
GO

-- example to execute the stored procedure we just created
EXECUTE dbo.MergeSnohomish 1 /*value_for_param1*/, 2 /*value_for_param2*/
GO