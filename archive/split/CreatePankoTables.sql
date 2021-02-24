CREATE PROCEDURE [tsc].[CreatePankoTables] 
	 @schemaname as varchar(128)
	,@tablename as varchar(128)
AS 
BEGIN
	declare @tmpsql as nvarchar(max)

	declare @source as varchar(261) = '[' + @schemaname + '].[' + @tablename + ']'
	declare @state as varchar(150) = '[state].[' + @tablename + ']'
	declare @change as varchar(150) = '[delta].[' + @tablename + ']'
	declare @report as varchar(150) = '[report].[' + @tablename + ']'
	
	/***************************** 
	 Has Unique Column?
		NO => Create AutoId
		YES => Store @FirstUniqueColumn
	*****************************/
	declare @FirstUniqueColumn as varchar(128)
	declare @HasUniqueColumn int 
	EXEC @HasUniqueColumn = tsc.CreateUniqueColumn @schemaname,@tablename,null, @FirstUniqueColumn OUTPUT 
	
	/***************************** 
		CREATE @state
	*****************************/
	--Check if the table has been dropped before and shift it back from the hold.
	----POTENTIAL BUG!	--The hold will fail where tables are dropped and recreated with different columns!
	set @tmpsql = ''
	set @tmpsql = @tmpsql + ';IF OBJECT_ID(''hold_state.'+ @tablename + ''',''U'') is not null ALTER SCHEMA state TRANSFER hold_state.[' + @tablename + ']'
	print isnull(@tmpsql,'NULLED!')
	EXEC(@tmpsql)

	;IF OBJECT_ID(@state,'U') is null 
	BEGIN 
		set @tmpsql = ''
		--Use same columns and types as @source but without constraints
		set @tmpsql = @tmpsql + ';CREATE TABLE ' + @state + '(' + tsc.GetColumnCreate( @schemaname ,@tablename ) 
		--Add primary key StateId to @state --Review the clustering of this: I believe the table should be clustered on the @source PK/UK first 
		set @tmpsql = @tmpsql + ', StateId int IDENTITY(1,1) PRIMARY KEY NONCLUSTERED' 
		set @tmpsql = @tmpsql + ')'

		print isnull(@tmpsql,'NULLED!')
		EXEC(@tmpsql)
	END

	/***************************** 
		CREATE @change
	*****************************/
	set @tmpsql = ''
	set @tmpsql = @tmpsql + ';IF OBJECT_ID(''hold_change.'+ @tablename + ''',''U'') is not null ALTER SCHEMA change TRANSFER hold_change.[' + @tablename + ']'
	print isnull(@tmpsql,'NULLED!')
	EXEC(@tmpsql)

	;IF OBJECT_ID(@change,'U') is null 
	BEGIN 
		set @tmpsql = ''
		set @tmpsql = @tmpsql + ';CREATE TABLE ' + @change + ' ( '
		set @tmpsql = @tmpsql + ' ChangeId		int				IDENTITY(1,1) PRIMARY KEY CLUSTERED'
		set @tmpsql = @tmpsql + ',State			int				NOT NULL'
		set @tmpsql = @tmpsql + ',Step			int				NOT NULL'
		set @tmpsql = @tmpsql + ',ActiveFrom	datetime		NOT NULL'
		set @tmpsql = @tmpsql + ',ActiveTo		datetime		NULL'
		set @tmpsql = @tmpsql + ',Author		varchar(128)	NOT NULL'
		set @tmpsql = @tmpsql + ', CONSTRAINT FK_' + LEFT(@tablename,128-9) + '_Panko FOREIGN KEY (State) REFERENCES ' + @state + ' (StateId)'
		set @tmpsql = @tmpsql + ')'

		print isnull(@tmpsql,'NULLED!')
		EXEC(@tmpsql)
	END
	
	/***************************** 
		CREATE @report
	*****************************/
	;IF OBJECT_ID(@report,'V') is null 
	BEGIN 
		set @tmpsql = ''
		--Use same columns and types as @source but without constraints
		set @tmpsql = @tmpsql + ';CREATE VIEW ' + @report + ' AS ' 
		set @tmpsql = @tmpsql +	'SELECT ' + tsc.GetColumnSelect('delta', @tablename, 'c' ) 
		set @tmpsql = @tmpsql + ',' + tsc.GetColumnSelect(@schemaname, @tablename, 's') 
		set @tmpsql = @tmpsql + ' FROM ' + @change + ' c'
		set @tmpsql = @tmpsql + ' INNER JOIN ' + @state + ' s ON s.StateId = c.State'

		print isnull(@tmpsql,'NULLED!')
		EXEC(@tmpsql)
		
	END

END