CREATE PROCEDURE [tsc].[Breadcrumb] 
	 @schemaname as varchar(128)
	,@tablename as varchar(128)
AS 
BEGIN
	EXEC tsc.CreatePankoTables @schemaname, @tablename;
	EXEC tsc.CreatePankoTriggers @schemaname, @tablename;
	
	declare @tmpsql as nvarchar(max)

	declare @source as varchar(261) = '[' + @schemaname + '].[' + @tablename + ']'
	declare @state as varchar(150) = '[state].[' + @tablename + ']'
	/***************************** 
		POPULATE STATE TABLE
	*****************************/
		set @tmpsql = ' INSERT INTO ' + @state + ' SELECT * FROM ' + @source
		print isnull(@tmpsql,'NULLED!')
		EXEC(@tmpsql)
END