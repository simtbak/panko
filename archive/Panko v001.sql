USE [TemporalDB]
GO
/****** Object:  Schema [delta]    Script Date: 25/04/2020 10:57:42 ******/
CREATE SCHEMA [delta]
GO
/****** Object:  Schema [hold_change]    Script Date: 25/04/2020 10:57:42 ******/
CREATE SCHEMA [hold_change]
GO
/****** Object:  Schema [hold_note]    Script Date: 25/04/2020 10:57:42 ******/
CREATE SCHEMA [hold_note]
GO
/****** Object:  Schema [hold_state]    Script Date: 25/04/2020 10:57:42 ******/
CREATE SCHEMA [hold_state]
GO
/****** Object:  Schema [input]    Script Date: 25/04/2020 10:57:42 ******/
CREATE SCHEMA [input]
GO
/****** Object:  Schema [note]    Script Date: 25/04/2020 10:57:42 ******/
CREATE SCHEMA [note]
GO
/****** Object:  Schema [report]    Script Date: 25/04/2020 10:57:42 ******/
CREATE SCHEMA [report]
GO
/****** Object:  Schema [state]    Script Date: 25/04/2020 10:57:42 ******/
CREATE SCHEMA [state]
GO
/****** Object:  Schema [tsc]    Script Date: 25/04/2020 10:57:42 ******/
CREATE SCHEMA [tsc]
GO
/****** Object:  UserDefinedFunction [tsc].[GetABColumnComparison]    Script Date: 25/04/2020 10:57:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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
GO
/****** Object:  UserDefinedFunction [tsc].[GetColumnCreate]    Script Date: 25/04/2020 10:57:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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
GO
/****** Object:  UserDefinedFunction [tsc].[GetColumnSelect]    Script Date: 25/04/2020 10:57:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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
GO
/****** Object:  UserDefinedFunction [tsc].[GetFirstUniqueColumn]    Script Date: 25/04/2020 10:57:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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
GO
/****** Object:  UserDefinedFunction [tsc].[NumberOfColumns]    Script Date: 25/04/2020 10:57:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [tsc].[NumberOfColumns] (
	 @schemaname as varchar(128)
	,@objectname as varchar(128) --Or View
)
RETURNS smallint
AS BEGIN 
	RETURN ( SELECT count(name) FROM sys.columns WHERE columns.object_id = OBJECT_ID(@schemaname + '.' + @objectname) )
END
GO
/****** Object:  StoredProcedure [tsc].[CreatePankoTriggers]    Script Date: 25/04/2020 10:57:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [tsc].[CreatePankoTriggers]
	 @schemaname as varchar(128)
	,@tablename as varchar(128)
AS 
BEGIN
	declare @trimmedtablename as varchar(128) = LEFT(@tablename,108) --Allow for 20 character prefix
	declare @source as varchar(261) = '[' + @schemaname + '].[' + @tablename + ']'
	declare @state as varchar(150) = '[state].[' + @tablename + ']'
	declare @change as varchar(150) = '[delta].[' + @tablename + ']'
	--declare @note as varchar(150) = '[note].[' + @tablename + ']'
	
	;IF OBJECT_ID(@source,'U') is null 
	BEGIN
		print @source + ' does not exist'
		RETURN 0;
	END 
	declare @UniqueColumn			as varchar(128) = ( SELECT tsc.GetFirstUniqueColumn(@schemaname, @tablename, null) )
	-- 14-Apr-2020 this variable had to be added for where the UniqueColumn is not the first column in the table for state deletion inserts
	declare @ColumnListUniqueFirst	as varchar(max) = ( SELECT tsc.GetColumnSelect(@schemaname, @tablename, null) )
	declare @tmpsql					as nvarchar(max)
	
	
	IF ( CHARINDEX(@UniqueColumn,@ColumnListUniqueFirst) > 2 )
	BEGIN
		set @ColumnListUniqueFirst = '['+@UniqueColumn+'],'+replace(( SELECT tsc.GetColumnSelect(@schemaname, @tablename, null) ),',['+@UniqueColumn+']','')
	END
	/***************************** 
		ATTACH TRIGGER INSERT to @change -- This updates previous ActiveTo results (The state regression issue occurs before this On insert )
	*****************************/
	set @tmpsql = ''
	set @tmpsql = @tmpsql + ';CREATE TRIGGER tscUpdateChange_' + @trimmedtablename + ' ON ' + @change + ' FOR INSERT AS '
	set @tmpsql = @tmpsql + ';BEGIN TRANSACTION '
	set @tmpsql = @tmpsql + ';UPDATE ' + @change + ' SET ActiveTo = NewActiveTo FROM '
	set @tmpsql = @tmpsql + '( SELECT c.ChangeId CID, LEAD(c.ActiveFrom, 1, null) OVER ( PARTITION BY s.' + @UniqueColumn + ' ORDER BY c.ActiveFrom ) NewActiveTo '
	set @tmpsql = @tmpsql + ' FROM '		+ @state +  ' s with(nolock) ' 
	set @tmpsql = @tmpsql + ' INNER JOIN '	+ @change + ' c with(nolock) on c.State = s.StateId ' 
	set @tmpsql = @tmpsql + ') upd WHERE ActiveTo is null and NewActiveTo is not null and CID = ChangeId '
	set @tmpsql = @tmpsql + ';COMMIT TRANSACTION'
	print isnull(@tmpsql,'NULLED!')
	--set @tmpsql = @tmpsql + ';print isnull('''+ replace(@tmpsql,'''','''''') +''',''NULLED!'')'
	EXEC(@tmpsql)

	/***************************** 
		ATTACH TRIGGER INSERT to @state -- Is aggregate the only way to increase the step? The most efficient?
	*****************************/
	set @tmpsql = ''
	set @tmpsql = @tmpsql + ';CREATE TRIGGER tscInsertChange_' + @trimmedtablename + ' ON ' + @state + ' FOR INSERT AS '
	set @tmpsql = @tmpsql + ';BEGIN TRANSACTION '
	set @tmpsql = @tmpsql + ';INSERT INTO ' + @change + ' (State,Step,ActiveFrom,ActiveTo,Author) '
	set @tmpsql = @tmpsql + ' SELECT i.StateId, 1+isnull(max(c.Step),0), GETDATE(), null, Suser_name()'
	set @tmpsql = @tmpsql + ' FROM inserted i ' 
	set @tmpsql = @tmpsql + ' INNER JOIN ' + @state + '  s with(nolock) on i.' + @UniqueColumn + ' = s.' + @UniqueColumn
	set @tmpsql = @tmpsql + ' LEFT JOIN ' + @change + ' c with(nolock) on c.State = s.StateId'
	set @tmpsql = @tmpsql + ' GROUP BY i.StateId, s.[' + @UniqueColumn + ']'
	set @tmpsql = @tmpsql + ';COMMIT TRANSACTION'
	print isnull(@tmpsql,'NULLED!')
	--set @tmpsql = @tmpsql + ';print isnull('''+ replace(@tmpsql,'''','''''') +''',''NULLED!'')'
	EXEC(@tmpsql)

	/***************************** 
		ATTACH TRIGGER INSERT to @source
	*****************************/
	set @tmpsql = ''
	set @tmpsql = @tmpsql + ';CREATE TRIGGER tscInsertState_' + @trimmedtablename + ' ON ' + @source + ' FOR INSERT AS '
	set @tmpsql = @tmpsql + ';BEGIN TRANSACTION '
	set @tmpsql = @tmpsql + ';INSERT INTO ' + @state + ' SELECT * FROM inserted ORDER BY [' + @UniqueColumn + ']'
	set @tmpsql = @tmpsql + ';COMMIT TRANSACTION'
	print isnull(@tmpsql,'NULLED!')
	--set @tmpsql = @tmpsql + ';print isnull('''+ replace(@tmpsql,'''','''''') +''',''NULLED!'')'
	EXEC(@tmpsql)

	/***************************** 
		ATTACH TRIGGER DELETE to @source
	*****************************/

	set @tmpsql = ''
	set @tmpsql = @tmpsql + ';CREATE TRIGGER tscDeleteState_' + @trimmedtablename + ' ON ' + @source + ' FOR DELETE AS '
	set @tmpsql = @tmpsql + ';BEGIN TRANSACTION '
	set @tmpsql = @tmpsql + ';INSERT INTO ' + @state + ' (' + @ColumnListUniqueFirst + ') SELECT ' + @UniqueColumn + REPLICATE(',null',tsc.NumberOfColumns('input',@tablename)-1) + ' FROM deleted'
	set @tmpsql = @tmpsql + ';COMMIT TRANSACTION'
	print isnull(@tmpsql,'NULLED!')
	--set @tmpsql = @tmpsql + ';print isnull('''+ replace(@tmpsql,'''','''''') +''',''NULLED!'')'
	EXEC(@tmpsql)

	/***************************** 
		ATTACH TRIGGER UPDATE to @source
	*****************************/
	set @tmpsql = ''
	set @tmpsql = @tmpsql + ';CREATE TRIGGER tscUpdate_' + @trimmedtablename + ' ON ' + @source + ' FOR UPDATE AS '
	set @tmpsql = @tmpsql + ';IF OBJECT_ID(''tempdb..#upd'',''U'') is not null DROP TABLE #upd'
	set @tmpsql = @tmpsql + ';IF OBJECT_ID(''tempdb..#existingState'',''U'') is not null DROP TABLE #existingState'
	set @tmpsql = @tmpsql + ';IF OBJECT_ID(''tempdb..#newState'',''U'') is not null DROP TABLE #newState'
	set @tmpsql = @tmpsql + ';BEGIN TRANSACTION ' --#upd Is new values where there was an old value (inserted inner join deleted).
	--set @tmpsql = @tmpsql + ';SELECT i.* into #upd FROM inserted i INNER JOIN deleted d on d.' + @UniqueColumn + ' = i.' + @UniqueColumn
													--17-Apr-2020 Only use where values have actually changed
	set @tmpsql = @tmpsql + ';SELECT i.* into #upd FROM inserted i EXCEPT SELECT * FROM deleted d'
	set @tmpsql = @tmpsql + ';SELECT * into #existingState FROM #upd INTERSECT SELECT ' + tsc.GetColumnSelect('input',@tablename,null) + ' FROM ' + @state
		set @tmpsql = @tmpsql + ';IF (SELECT count(*) FROM #existingState) > 0 '
		set @tmpsql = @tmpsql + ' BEGIN '
		--Removing this insert prevents the [change] from reactivating existing [states]
		set @tmpsql = @tmpsql + ' INSERT INTO ' + @change + ' (State,Step,ActiveFrom,ActiveTo,Author) '
		set @tmpsql = @tmpsql + ' SELECT B.StateId, 1+isnull(max(c.Step),0), GETDATE(), null, Suser_name()'
		set @tmpsql = @tmpsql + ' FROM #existingState A ' 
		set @tmpsql = @tmpsql + ' INNER JOIN ' + @state + '  B with(nolock) on A.' + @UniqueColumn + ' = B.' + @UniqueColumn
		set @tmpsql = @tmpsql + ' LEFT JOIN ' + @change + ' c with(nolock) on c.State = B.StateId'
			---16-Apr-20 This equivalent is necessary to find the correct StateId associated with the value and @UniqueColumn
		set @tmpsql = @tmpsql + ' WHERE ' + tsc.GetABColumnComparison('input',@tablename)
		set @tmpsql = @tmpsql + ' GROUP BY B.StateId, B.[' + @UniqueColumn + ']'
		set @tmpsql = @tmpsql + ' END '
	set @tmpsql = @tmpsql + ';IF OBJECT_ID(''tempdb..#existingState'',''U'') is not null DROP TABLE #existingState'
	set @tmpsql = @tmpsql + ';SELECT * into #newState FROM #upd EXCEPT SELECT ' + tsc.GetColumnSelect('input',@tablename,null) + ' FROM ' + @state
		set @tmpsql = @tmpsql + ';IF (SELECT count(*) FROM #newState) > 0 '
		set @tmpsql = @tmpsql + ' BEGIN '
		set @tmpsql = @tmpsql + ' INSERT INTO ' + @state + ' SELECT * FROM #newState'
		set @tmpsql = @tmpsql + ' END '
	set @tmpsql = @tmpsql + ';IF OBJECT_ID(''tempdb..#newState'',''U'') is not null DROP TABLE #newState'
	set @tmpsql = @tmpsql + ';DROP TABLE #upd'
	set @tmpsql = @tmpsql + ';COMMIT TRANSACTION'
	print isnull(@tmpsql,'NULLED!')
	--set @tmpsql = @tmpsql + ';print isnull('''+ replace(@tmpsql,'''','''''') +''',''NULLED!'')'
	EXEC(@tmpsql)
	
	print 'All trigger creation SQL executes before 539 error is thrown on SELECT into'
END 
GO
/****** Object:  StoredProcedure [tsc].[CreateUniqueColumn]    Script Date: 25/04/2020 10:57:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [tsc].[CreateUniqueColumn] 
	 @schemaname as varchar(128)
	,@tablename as varchar(128)
	,@columnname as varchar(128) = null
	,@FirstUniqueColumn as varchar(128) OUTPUT
AS
BEGIN 
	/*** I NEED TO FUNDAMENTALLY CHANGE THE WAY THIS OPERATES ***/
	declare @source as varchar(261)= '[' + @schemaname + '].[' + @tablename + ']'
	declare @ExistingColumn as varchar(128) = (SELECT tsc.GetFirstUniqueColumn(@schemaname,@tablename,null))
	IF @ExistingColumn is null
	BEGIN
		;declare @tmpsql as varchar(max)
		;declare @AutoIdColumn as varchar(50) = isnull(@columnname,'AutoId')

		;IF (SELECT 1 FROM sys.columns WHERE Name = @AutoIdColumn AND Object_ID = Object_ID(@source)) = 1 
		BEGIN
			;declare @OriginalAutoIdColumn as varchar(150) = @source+'.'+@AutoIdColumn
			;declare @RenamedAutoIdColumn as varchar(128) = @AutoIdColumn+'_old'
			;EXEC sp_RENAME @OriginalAutoIdColumn, @RenamedAutoIdColumn, 'COLUMN'
		END
		;set @tmpsql = ';ALTER TABLE ' + @source + ' ADD ' + @AutoIdColumn + ' int IDENTITY(1,1) UNIQUE;'
		;EXEC(@tmpsql)
		;SELECT @FirstUniqueColumn = @AutoIdColumn
	END
	ELSE BEGIN 
		print 'An Identity column [' + @ExistingColumn + '] already exists on ' + @source
		;SELECT @FirstUniqueColumn = @ExistingColumn
	END
	RETURN 1;
END
GO
/****** Object:  StoredProcedure [tsc].[HoldPanko]    Script Date: 25/04/2020 10:57:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [tsc].[HoldPanko] 
	@tablename as varchar(128)
AS 
BEGIN 
/*
	This trigger CAN move dropped tables to a hold schema instead of ~permanently~ deleting the data
	But for the time being it is cascading the drop to state and change tables
*/
	declare @change as varchar(150) = '[delta].' + '[' + @tablename + ']'
	declare @state as varchar(150) = '[state].' + '[' + @tablename + ']'
	declare @note as varchar(150) = '[note].' + '[' + @tablename + ']'

	PRINT 'Processing: ' + @tablename
	declare @tmpsql as varchar(max)
	
	set @tmpsql = ''
	set @tmpsql = @tmpsql + ';IF OBJECT_ID('''+ @note	+ ''',''U'') is not null DROP TABLE ' + @note
	set @tmpsql = @tmpsql + ';IF OBJECT_ID('''+ @change + ''',''U'') is not null DROP TABLE ' + @change
	set @tmpsql = @tmpsql + ';IF OBJECT_ID('''+ @state	+ ''',''U'') is not null DROP TABLE ' + @state
	
	print @tmpsql
	EXEC(@tmpsql)
	
	--PRINT 'Moved to hold: ' + @state + ', ' + @change
	PRINT 'Dropped: ' + @state + ', ' + @change
END
GO
/****** Object:  StoredProcedure [tsc].[CreatePankoTables]    Script Date: 25/04/2020 10:57:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [tsc].[CreatePankoTables] 
	 @schemaname as varchar(128)
	,@tablename as varchar(128)
AS 
BEGIN
	declare @tmpsql as nvarchar(max)

	declare @source as varchar(261) = '[' + @schemaname + '].[' + @tablename + ']'
	declare @state as varchar(150) = '[state].[' + @tablename + ']'
	declare @change as varchar(150) = '[delta].[' + @tablename + ']'
	declare @note as varchar(150) = '[note].[' + @tablename + ']'
	
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
		CREATE @note
	*****************************
			--I WANT TO RETHINK THE WAY NOTES ARE CREATED. I DON'T THINK THEY REQUIRE A NEW TABLE PER TABLE.
	set @tmpsql = ''
	set @tmpsql = @tmpsql + ';IF OBJECT_ID(''hold_note.'+ @tablename + ''',''U'') is not null ALTER SCHEMA change TRANSFER hold_note.[' + @tablename + ']'
	print isnull(@tmpsql,'NULLED!')
	EXEC(@tmpsql)
	

	;IF OBJECT_ID(@note,'U') is null 
	BEGIN 
		set @tmpsql = ''
		set @tmpsql = @tmpsql + ';CREATE TABLE ' + @note + ' ( '
		set @tmpsql = @tmpsql + ' NoteId		int				IDENTITY(1,1) PRIMARY KEY CLUSTERED'
		set @tmpsql = @tmpsql + ',Change		int				NOT NULL'
		set @tmpsql = @tmpsql + ',Author		varchar(128)	NOT NULL'
		set @tmpsql = @tmpsql + ',Content		nvarchar(max)	NOT NULL'
		set @tmpsql = @tmpsql + ', CONSTRAINT FK_' + LEFT(@tablename,128-14) + '_ChangeNote FOREIGN KEY (Change) REFERENCES ' + @change + ' (ChangeId)'
		set @tmpsql = @tmpsql + ')'

		print isnull(@tmpsql,'NULLED!')
		EXEC(@tmpsql)
	END
	*****************************/

	/***************************** 
		ATTACH TRIGGERS
	*****************************/
	--EXEC tsc.CreatePankoTriggers @schemaname, @tablename
END
GO
/****** Object:  StoredProcedure [tsc].[RebuildPankoTriggers]    Script Date: 25/04/2020 10:57:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [tsc].[RebuildPankoTriggers]
AS BEGIN 
	declare @tmpsql as varchar(max)
	;with TriggerAction as ( 
		SELECT	 'DROP TRIGGER [' + s.name + '].[' + o.name + '];' [Remove]
				,'EXEC tsc.CreatePankoTriggers @schemaname = ''input'', @tablename = ''' + t.name + ''';' [ReAdd]
		FROM sys.objects		o
		INNER JOIN sys.schemas	s on s.schema_id = o.schema_id
		INNER JOIN sys.tables	t on t.object_id = o.parent_object_id
		WHERE o.type = 'TR'
		and o.name like 'tsc%'
	) 

	SELECT @tmpsql = (
		SELECT x 
			FROM ( 
						SELECT [Remove] x	FROM TriggerAction GROUP BY [Remove]
			UNION ALL	SELECT ReAdd		FROM TriggerAction GROUP BY ReAdd
			) actions
	FOR XML PATH(''), TYPE).value('.', 'varchar(max)')

	EXEC(@tmpsql)
END
GO
/****** Object:  DdlTrigger [HoldPanko]    Script Date: 25/04/2020 10:57:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [HoldPanko] ON DATABASE
AFTER DROP_TABLE
AS   
	declare @schemaname as varchar(128) = 'input'
	;IF EVENTDATA().value('(/EVENT_INSTANCE/SchemaName)[1]','varchar(128)') <> @schemaname RETURN;
	PRINT '============= HoldPanko ================'
	declare @tablename as varchar(128) = EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]','nvarchar(max)')

	EXEC tsc.HoldPanko @tablename;
GO
DISABLE TRIGGER [HoldPanko] ON DATABASE
GO
/****** Object:  DdlTrigger [ManifestPanko]    Script Date: 25/04/2020 10:57:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [ManifestPanko] ON DATABASE
AFTER CREATE_TABLE
AS   
	declare @schemaname as varchar(128) = 'input'
	;IF EVENTDATA().value('(/EVENT_INSTANCE/SchemaName)[1]','varchar(128)') <> @schemaname RETURN;
	PRINT '============= CreatePankoTables ================'
	declare @tablename as varchar(128) = EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]','nvarchar(max)')

	EXEC tsc.CreatePankoTables @schemaname, @tablename;
	/***************************** 
		ATTACH TRIGGERS
	*****************************/
	EXEC tsc.CreatePankoTriggers @schemaname, @tablename
GO
DISABLE TRIGGER [ManifestPanko] ON DATABASE
GO
ENABLE TRIGGER [HoldPanko] ON DATABASE
GO
ENABLE TRIGGER [ManifestPanko] ON DATABASE
GO
