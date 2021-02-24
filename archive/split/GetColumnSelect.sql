CREATE FUNCTION [tsc].[GetColumnSelect] ( 
	 @schemaname as varchar(128)
	,@tablename as varchar(128)
	,@tablealias as varchar(128) = null
) 
RETURNS varchar(max)
AS BEGIN 
	declare @ColumnSelectList varchar(max)

	SELECT @ColumnSelectList = 
	STUFF((
		SELECT ',' + isnull(@tablealias+'.','') + '[' + c.name + ']'
		FROM		sys.tables		d
		INNER JOIN	sys.schemas		s on d.schema_id = s.schema_id
		INNER JOIN	sys.columns		c on d.object_id = c.object_id
		WHERE s.[name] = @schemaname
		and d.[name] = @tablename
		ORDER BY column_id
		FOR XML PATH(''),type).value('.','varchar(max)')
	,1,1,'')
			
	RETURN(@ColumnSelectList)
END 