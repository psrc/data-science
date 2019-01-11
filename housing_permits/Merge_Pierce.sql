-- Create a new stored procedure called 'MergePierce' in schema 'dbo'
-- Drop the stored procedure if it already exists
IF EXISTS (
SELECT *
    FROM INFORMATION_SCHEMA.ROUTINES
WHERE SPECIFIC_SCHEMA = N'dbo'
    AND SPECIFIC_NAME = N'MergePierce'
)
DROP PROCEDURE dbo.MergePierce
GO

-- Create the stored procedure in the specified schema
CREATE PROCEDURE dbo.MergePierce
    @param1 /*parameter name*/ int /*datatype_for_param1*/ = 0, /*default_value_for_param1*/
    @param2 /*parameter name*/ int /*datatype_for_param1*/ = 0 /*default_value_for_param2*/
-- add more stored procedure parameters here
AS
    -- body of the stored procedure

SELECT * FROM Angela.BUCKLEY17 
UNION ALL
SELECT * FROM Angela.CARBONADO17
UNION ALL
SELECT * FROM ANGELA.DUPONT17
UNION ALL
SELECT * FROM ANGELA.EATONVILLE17
UNION ALL
SELECT * FROM Angela.EDGEWOOD17 
UNION ALL
SELECT * FROM Angela.FIFE17
UNION ALL
SELECT * FROM ANGELA.FIRCREST17
UNION ALL
SELECT * FROM ANGELA.GIGHARBOR17
UNION ALL
SELECT * FROM Angela.ORTING17 
UNION ALL 
SELECT * FROM Angela.PUYALLUP17
UNION ALL
SELECT * FROM ANGELA.STEILACOOM17
UNION ALL
SELECT * FROM ANGELA.SUMNER17
UNION ALL
SELECT * FROM Angela.TACOMA17 
UNION ALL 
SELECT * FROM Angela.UNINCORPORATEDPIERCE17
UNION ALL
SELECT * FROM ANGELA.UNIVERSITYPLACE17
UNION ALL
SELECT * FROM ANGELA.WILKESON17
GO

-- example to execute the stored procedure we just created
EXECUTE dbo.MergePierce 1 /*value_for_param1*/, 2 /*value_for_param2*/
GO