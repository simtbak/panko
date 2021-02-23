USE ebs
GO
/*------------------------------------------------------------------------------------------------------------
	+--------------------+
	| Execute Panko      |
	| Stored procedure   |
	| on @target table   |
	+---------+----------+
			  |
	+---------v----------+
	| Create all of the  |
	| components if they |
	| don't exist        |
	+---------+----------+
			  |
	+---------v----------+
	| Execute on @target |
	| table              |
	+--------------------+

THOUGHTS:
	Package minified SQL in with panko_collection.

------------------------------------------------------------------------------------------------------------*/
with panko_collection as (
			SELECT '_SCHEMA'	[collection_type]	,'SCHEMA'	[collection_type_name]	,'tsc' [element_name]		,'000' [version]	,''	[definition]
UNION ALL	SELECT '_SCHEMA'						,'SCHEMA'							,'state'					,'000'				,''	[definition]
UNION ALL	SELECT '_SCHEMA'						,'SCHEMA'							,'delta'					,'000'				,''	[definition]
UNION ALL	SELECT '_SCHEMA'						,'SCHEMA'							,'report'					,'000'				,''	[definition]
UNION ALL	SELECT 'FN'								,'FUNCTION'							,'GetABColumnComparison'	,'000'				,''	[definition]
UNION ALL	SELECT 'FN'								,'FUNCTION'							,'GetColumnCreate'			,'000'				,''	[definition]
UNION ALL	SELECT 'FN'								,'FUNCTION'							,'GetColumnSelect'			,'000'				,''	[definition]
UNION ALL	SELECT 'FN'								,'FUNCTION'							,'NumberOfColumns'			,'000'				,''	[definition]
UNION ALL	SELECT 'FN'								,'FUNCTION'							,'GetFirstUniqueColumn'		,'000'				,''	[definition]
UNION ALL	SELECT 'P'								,'STORED PROCEDURE'					,'CreateUniqueColumn'		,'000'				,''	[definition]
UNION ALL	SELECT 'P'								,'STORED PROCEDURE'					,'CreatePankoTables'		,'000'				,''	[definition]
UNION ALL	SELECT 'P'								,'STORED PROCEDURE'					,'CreatePankoTriggers'		,'000'				,''	[definition]
UNION ALL	SELECT 'P'								,'STORED PROCEDURE'					,'HoldPanko'				,'000'				,''	[definition]
UNION ALL	SELECT 'P'								,'STORED PROCEDURE'					,'RebuildPankoTriggers'		,'000'				,''	[definition]
)

, existing_collection as ( 
			SELECT '_SCHEMA' type	,name FROM sys.schemas
UNION ALL	SELECT type				,name FROM sys.objects WHERE type in ('FN','P')
)

SELECT 
	 [collection_type]
	,[collection_type_name]
	,[element_name]
	,[version]

FROM panko_collection	p

WHERE NOT EXISTS ( 
	SELECT null FROM existing_collection	o
	WHERE	o.type	=	p.collection_type
	and		o.name	=	p.element_name
)

ORDER BY collection_type

/*----------------------------------------------------------------------------------------------------------
-------------------------------------GENERIC CODE: 

	-------------------------------------CREATE SCHEMA WHERE IT DOESN'T EXIST 
	GO
	declare @tmpsql as varchar(max) = ''
	declare @name as varchar(256) = ''

	IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = @name)
	BEGIN
		set @tmpsql = 'CREATE SCHEMA ' + @name
		EXEC(@tmpsql)
	END
	
	-------------------------------------CREATE OBJECT WHERE IT DOESN'T EXIST 
	GO
	declare @tmpsql as varchar(max) = '--defintion'
	declare @schema as varchar(256) = ''
	declare @name as varchar(256) = ''
	declare @object as @schema+'.'+@name

	IF OBJECT_ID(@object) is null 
	BEGIN
		EXEC(@tmpsql)
	END
----------------------------------------------------------------------------------------------------------*/