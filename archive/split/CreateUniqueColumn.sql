/*------------------------------------------------------------------------------------------------------------
	--CREATE PROCEDURES
------------------------------------------------------------------------------------------------------------*/
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