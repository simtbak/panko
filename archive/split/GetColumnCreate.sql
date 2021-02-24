CREATE FUNCTION [tsc].[GetColumnCreate] ( 
	 @schemaname as varchar(128)
	,@tablename as varchar(128)
) 
RETURNS varchar(max)
AS BEGIN 
	declare @ColumnCreateList varchar(max)

	SELECT @ColumnCreateList = 
	STUFF((
		SELECT ',[' + c.name + '] ' + t.[name] + CASE WHEN c.[precision] = 0 THEN '('+isnull(nullif(cast(c.max_length as varchar),'-1'),'max')+')' ELSE '' END + ' NULL'
		FROM		sys.tables		d
		INNER JOIN	sys.schemas		s on d.schema_id = s.schema_id
		INNER JOIN	sys.columns		c on d.object_id = c.object_id
		INNER JOIN	sys.types		t on c.system_type_id = t.system_type_id
		
		WHERE s.[name] = @schemaname
		and d.[name] = @tablename
		and LEFT(t.name,3) <> 'sys'
		ORDER BY column_id

		FOR XML PATH(''),type).value('.','varchar(max)')
	,1,1,'')
			
	RETURN(@ColumnCreateList)
END 