/*------------------------------------------------------------------------------------------------------------
	--CREATE FUNCTIONS
------------------------------------------------------------------------------------------------------------*/
CREATE FUNCTION [tsc].[GetABColumnComparison] ( 
	 @schemaname as varchar(128)
	,@tablename as varchar(128)
) 
RETURNS varchar(max)
AS BEGIN 
	declare @ColumnCompareList varchar(max)

	SELECT @ColumnCompareList = '('
	+ STUFF(( 
		SELECT ' and ( A.['+ c.name +'] = B.['+ c.name +'] or ( A.['+ c.name +'] is null and B.['+ c.name +'] is null ) )'
		FROM sys.tables			t
		INNER JOIN sys.columns  c on c.object_id = t.object_id 
		WHERE schema_id = ( SELECT schema_id FROM sys.schemas WHERE name = @schemaname)
		and t.name = @tablename
		FOR XML PATH(''),type).value('.','varchar(max)')
	,1,5,'') + ')'

	RETURN(@ColumnCompareList)
END