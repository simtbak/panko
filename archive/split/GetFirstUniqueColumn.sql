CREATE FUNCTION [tsc].[GetFirstUniqueColumn] (
	 @schemaname as varchar(128)
	,@tablename as varchar(128)
	,@columnname as varchar(128) = null
)
RETURNS varchar(128)
AS BEGIN 
	declare @FirstUniqueColumn as varchar(128) 

	;with ColumnSelect as (
		SELECT TOP 1 [COLNAME], row_number() OVER ( ORDER BY PKC desc, column_id ) rn 
		FROM 
		(
			SELECT
				 CCU.COLUMN_NAME												[COLNAME]
				,CASE WHEN LEFT(TC.CONSTRAINT_TYPE,1) = 'P' THEN 1 ELSE 0 END	PKC
				,C.column_id

			FROM		INFORMATION_SCHEMA.TABLE_CONSTRAINTS		TC
			INNER JOIN	INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE CCU	on TC.CONSTRAINT_NAME = CCU.CONSTRAINT_NAME
			INNER JOIN	sys.columns									C	on C.name = CCU.column_name
			
			WHERE TC.CONSTRAINT_SCHEMA	= @schemaname
			and CCU.CONSTRAINT_SCHEMA	= @schemaname
			and TC.TABLE_NAME			= @tablename
			and TC.CONSTRAINT_TYPE in ('UNIQUE','PRIMARY KEY')
			and TC.CONSTRAINT_CATALOG = CCU.CONSTRAINT_CATALOG
			and C.object_id = OBJECT_ID(TC.CONSTRAINT_SCHEMA+'.'+@tablename)
			and c.is_nullable = 0

		UNION ALL

			SELECT   
				 ic.name														[COLNAME]
				,0																PKC
				,column_id

			FROM SYS.IDENTITY_COLUMNS ic
			INNER JOIN sys.tables d on d.object_id = ic.object_id
			INNER JOIN sys.schemas s on s.schema_id = d.schema_id

			WHERE s.name = @schemaname
			and ic.is_nullable = 0
			and d.name = @tablename
		) cols
	)
	SELECT @FirstUniqueColumn = COLNAME FROM ColumnSelect WHERE rn = 1 

	RETURN(@FirstUniqueColumn)
END