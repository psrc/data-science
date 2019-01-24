-- Create a new stored procedure called 'MergeKitsap' in schema 'dbo'
-- Drop the stored procedure if it already exists
IF EXISTS (
SELECT *
    FROM INFORMATION_SCHEMA.ROUTINES
WHERE SPECIFIC_SCHEMA = N'dbo'
    AND SPECIFIC_NAME = N'mergeKitsap'
)
DROP PROCEDURE dbo.mergeKitsap
GO

-- Create the stored procedure in the specified schema
CREATE PROCEDURE dbo.mergeKitsap
    @param1 /*parameter name*/ int /*datatype_for_param1*/ = 0, /*default_value_for_param1*/
    @param2 /*parameter name*/ int /*datatype_for_param1*/ = 0 /*default_value_for_param2*/
-- add more stored procedure parameters here
AS
    -- body of the stored procedure
SELECT * FROM Angela.UNINCORPORATEDKITSAP17 
UNION ALL 
SELECT * FROM Angela.BREMERTON17
UNION ALL
SELECT * FROM ANGELA.PORTORCHARD17
UNION ALL
SELECT * FROM ANGELA.POULSBO17
GO

-- example to execute the stored procedure we just created
EXECUTE dbo.mergeKitsap 1 /*value_for_param1*/, 2 /*value_for_param2*/
GO


