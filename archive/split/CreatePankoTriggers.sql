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
	set @tmpsql = @tmpsql + ';INSERT INTO ' + @state + ' (' + @ColumnListUniqueFirst + ') SELECT ' + @UniqueColumn + REPLICATE(',null',tsc.NumberOfColumns(@schemaname,@tablename)-1) + ' FROM deleted'
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
	set @tmpsql = @tmpsql + ';SELECT * into #existingState FROM #upd INTERSECT SELECT ' + tsc.GetColumnSelect(@schemaname,@tablename,null) + ' FROM ' + @state
		set @tmpsql = @tmpsql + ';IF (SELECT count(*) FROM #existingState) > 0 '
		set @tmpsql = @tmpsql + ' BEGIN '
		--Removing this insert prevents the [change] from reactivating existing [states]
		set @tmpsql = @tmpsql + ' INSERT INTO ' + @change + ' (State,Step,ActiveFrom,ActiveTo,Author) '
		set @tmpsql = @tmpsql + ' SELECT B.StateId, 1+isnull(max(c.Step),0), GETDATE(), null, Suser_name()'
		set @tmpsql = @tmpsql + ' FROM #existingState A ' 
		set @tmpsql = @tmpsql + ' INNER JOIN ' + @state + '  B with(nolock) on A.' + @UniqueColumn + ' = B.' + @UniqueColumn
		set @tmpsql = @tmpsql + ' LEFT JOIN ' + @change + ' c with(nolock) on c.State = B.StateId'
			---16-Apr-20 This equivalent is necessary to find the correct StateId associated with the value and @UniqueColumn
		set @tmpsql = @tmpsql + ' WHERE ' + tsc.GetABColumnComparison(@schemaname,@tablename)
		set @tmpsql = @tmpsql + ' GROUP BY B.StateId, B.[' + @UniqueColumn + ']'
		set @tmpsql = @tmpsql + ' END '
	set @tmpsql = @tmpsql + ';IF OBJECT_ID(''tempdb..#existingState'',''U'') is not null DROP TABLE #existingState'
	set @tmpsql = @tmpsql + ';SELECT * into #newState FROM #upd EXCEPT SELECT ' + tsc.GetColumnSelect(@schemaname,@tablename,null) + ' FROM ' + @state
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
	
	--print 'All trigger creation SQL executes before 539 error is thrown on SELECT into'
END 