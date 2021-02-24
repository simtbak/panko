CREATE FUNCTION [tsc].[NumberOfColumns] (
	 @schemaname as varchar(128)
	,@objectname as varchar(128) --Or View
)
RETURNS smallint
AS BEGIN 
	RETURN ( SELECT count(name) FROM sys.columns WHERE columns.object_id = OBJECT_ID(@schemaname + '.' + @objectname) )
END